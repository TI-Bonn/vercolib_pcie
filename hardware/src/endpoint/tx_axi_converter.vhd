---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tlp_types.all;
use work.utils.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;

entity tx_axi_converter is
	port(
		clk    : in std_logic;
		rst    : in std_logic;

		Core_ID : in  std_logic_vector(15 downto 0);

		i      : in  fragment;
		i_vld  : in  std_logic;
		i_req  : out std_logic := '1';

		axis_tx_user  : out std_logic_vector(3 downto 0) := (others => '0');
		axis_tx_last  : out std_logic := '0';
		axis_tx_keep  : out std_logic_vector(15 downto 0) := (others => '0');
		axis_tx_data  : out std_logic_vector(127 downto 0) := (others => '0');
		axis_tx_valid : out std_logic := '0';
		axis_tx_ready : in  std_logic
	);
end tx_axi_converter;

architecture arch of tx_axi_converter is

	function desc_to_fmtType(desc : descriptor_t) return std_logic_vector is
	begin
		case desc is
		when MRd32_desc => return fmtType_MRd;
		when MWr32_desc => return fmtType_MWr;
		when MRd64_desc => return fmtType_MRd64;
		when MWr64_desc => return fmtType_MWr64;
		when CplD_desc  => return fmtType_CplD;
		when others     => return "0000000";
		end case;
	end desc_to_fmtType;

	function rqst_header_to_tlp_request_header(	data : rqst32;
												Core_ID: std_logic_vector(15 downto 0)
												) return tlp_request_header is
		variable ret: tlp_request_header;    -- TODO init?
	begin
		ret.dw0.fmt_type          := desc_to_fmtType(data.dw0.desc);
		ret.dw0.length            := data.dw0.length;
		ret.dw1.first_byte_enable := data.dw1.first_be;
		ret.dw1.last_byte_enable  := data.dw1.last_be;
		ret.dw1.requester_id      := Core_ID;
		ret.dw1.tag	              := data.dw0.tag;
		ret.dw2.address           := data.dw2.address;
		return ret;
	end rqst_header_to_tlp_request_header;

	function cpld_header_to_tlp_completion_header(	data: cpld;
													Core_ID: std_logic_vector(15 downto 0)
													) return tlp_completion_header is
		variable ret: tlp_completion_header; -- TODO init?
	begin
		ret.dw0.fmt_type      := desc_to_fmtType(data.dw0.desc);
		ret.dw0.length        := data.dw0.length;
		ret.dw1.byte_count    := data.dw1.byte_count;
		ret.dw1.completer_id  := Core_ID;
		ret.dw2.lower_address := data.dw2.lower_addr;
		ret.dw2.tag           := data.dw0.tag;
		return ret;
	end cpld_header_to_tlp_completion_header;

signal buf_vld : std_logic := '0';
signal axi_request : std_logic := '0';
signal req_state : std_logic := '0';

begin

	i_req <= axi_request or (req_state and not i_vld);

	axi_request  <= axis_tx_ready or not buf_vld;
	axis_tx_user <= "0000";

	process(clk)
	begin
		if rising_edge(clk) then

			req_state <= axi_request or (req_state and not i_vld);

			if axi_request = '1' then
				axis_tx_last <= i.eof;

				for j in 0 to 15 loop
					axis_tx_keep(j) <= i.keep(j/4);
				end loop;

				if i.sof = '1' then
					case i.data(3 downto 0) is
					when MRd32_desc | MWr32_desc =>
						axis_tx_data(95 downto 0) <= tlp_request_header_to_slv(rqst_header_to_tlp_request_header(get_rqst32(i.data(95 downto 0)), Core_ID));
						axis_tx_data(127 downto 96) <= change_endianess_DW(i.data(127 downto 96));

					when CplD_desc =>
						axis_tx_data(95 downto 0) <= tlp_completion_header_to_slv(cpld_header_to_tlp_completion_header(get_cpld(i.data(95 downto 0)), Core_ID));
						axis_tx_data(127 downto 96) <= change_endianess_DW(i.data(127 downto 96));

					when MRd64_desc | MWr64_desc =>  -- TODO 64 bit?
						axis_tx_data(95 downto 0) <= tlp_request_header_to_slv(rqst_header_to_tlp_request_header(get_rqst32(i.data(95 downto 0)), Core_ID));
						axis_tx_data(127 downto 96) <= i.data(127 downto 96);

					when others => null;
					end case;
				else
					axis_tx_data(127 downto 96) <= change_endianess_DW(i.data(127 downto 96));
					axis_tx_data(95 downto 0)   <= change_endianess_DW(i.data(95 downto 0));
				end if;

				buf_vld <= i_vld;
			end if;

			if rst = '1' then
				buf_vld <= '0';
				axis_tx_data <= (others => '0');
				axis_tx_keep <= (others => '0');
				axis_tx_last <= '0';
				req_state <= '0';
			end if;

		end if;
	end process;

	axis_tx_valid <= buf_vld;

end architecture;
