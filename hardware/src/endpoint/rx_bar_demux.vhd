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

entity rx_bar_demux is
	port(
		clk    : in std_logic;
		rst    : in std_logic;

		i     : in  tlp_packet;
		i_vld : in  std_logic;
		i_req : out std_logic := '1';

		-- Output Port
		bar0     : out fragment := default_fragment;
		bar0_vld : out std_logic := '0';
		bar0_req : in  std_logic;

		bar1     : out fragment := default_fragment;
		bar1_vld : out std_logic := '0';
		bar1_req : in  std_logic
	);
end rx_bar_demux;

architecture arch of rx_bar_demux is

	function fmtType_to_desc(fmt_type: std_logic_vector(6 downto 0)) return descriptor_t is
	begin
		case fmt_type is
		when fmtType_MRd =>	  return MRd32_desc;
		when fmtType_MWr =>	  return MWr32_desc;
		when fmtType_MRd64 => return MRd64_desc;
		when fmtType_MWr64 => return MWr64_desc;
		when fmtType_CplD =>  return CplD_desc;
		when others =>        return "0000";
		end case;
	end fmtType_to_desc;

	function tlp_request_header_to_rqst_header(data: tlp_request_header) return rqst32 is
		variable ret: rqst32 := init_rqst32;
	begin
		ret.dw0.desc              := fmtType_to_desc(data.dw0.fmt_type);
		ret.dw0.length            := data.dw0.length;
		ret.dw0.chn_id            := data.dw2.address(13 downto 6); -- "00000" & data.dw2.address(8 downto 6);  -- TODO problems? check here
		ret.dw1.first_be          := data.dw1.first_byte_enable;
		ret.dw1.last_be           := data.dw1.last_byte_enable;
		ret.dw1.requester_id      := data.dw1.requester_id;
		ret.dw0.tag               := data.dw1.tag;
		ret.dw2.address           := data.dw2.address;
		return ret;
	end tlp_request_header_to_rqst_header;

	function tlp_completion_header_to_cpld_header(data: tlp_completion_header) return cpld is
        variable ret: cpld := init_cpld;
    begin
        ret.dw0.desc          := fmtType_to_desc(data.dw0.fmt_type);
        ret.dw0.length        := data.dw0.length;
        ret.dw0.chn_id        := (others => '0'); -- will be replaced by another module -- "00000" & data.dw2.tag(7 downto 5);  -- TODO
        ret.dw1.byte_count    := data.dw1.byte_count;
        ret.dw1.completer_id  := data.dw1.completer_id;
        ret.dw2.lower_addr    := data.dw2.lower_address;
        ret.dw0.tag           := data.dw2.tag;
        return ret;
    end tlp_completion_header_to_cpld_header;

    signal out_data : fragment := default_fragment;

begin

	i_req <= bar0_req and bar1_req;

	process(clk)
	begin
		if rising_edge(clk) then

			-- we only deal with CplD or MWr or MRd and assume that Requests are always of length 1
			if bar0_req = '1' and bar1_req = '1' then

				out_data.keep <= i.keep;
				out_data.eof  <= i.eof;
				out_data.sof  <= i.sof;

				if i.sof = '1' then
					case i.data(30 downto 24) is     -- use types if possible!
					when fmtType_CplD =>
						set_cpld_header(out_data.data(95 downto 0), tlp_completion_header_to_cpld_header(slv_to_tlp_completion_header(i.data(95 downto 0))));

						out_data.data(127 downto 96) <= change_endianess_DW(i.data(127 downto 96));

					when fmtType_MWr | fmtType_MRd =>
						set_rqst32_header(out_data.data(95 downto 0), tlp_request_header_to_rqst_header(slv_to_tlp_request_header(i.data(95 downto 0))));
						out_data.data(127 downto 96) <= change_endianess_DW(i.data(127 downto 96));

					when fmtType_MWr64 | fmtType_MRd64 =>
						set_rqst32_header(out_data.data(95 downto 0), tlp_request_header_to_rqst_header(slv_to_tlp_request_header(i.data(95 downto 0))));
						out_data.data(127 downto 96) <= i.data(127 downto 96);

					when others =>
						assert false
							report "Incorrect fmt: " &
							       to_string(i.data(30 downto 24))
							severity failure;
					end case;

				else
					out_data.data(127 downto 96) <= change_endianess_DW(i.data(127 downto 96));
					out_data.data(95 downto 0)   <= change_endianess_DW(i.data(95 downto 0));
				end if;

				if i.bar(1) = '1' then
					bar0_vld <= '0';
					bar1_vld <= i_vld;
				else
					bar0_vld <= i_vld;
					bar1_vld <= '0';
				end if;
			end if;

			if rst = '1' then
				bar0_vld <= '0';
				out_data <= default_fragment;
				bar1_vld <= '0';
			end if;
		end if;
	end process;

	bar0 <= out_data;
	bar1 <= out_data;

end architecture;
