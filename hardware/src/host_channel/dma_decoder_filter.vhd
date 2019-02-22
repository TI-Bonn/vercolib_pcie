---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description:	1. filters CplD, MWr and MRd which belongs to the channel_id
--				2. parses MWr and MRd for the dma-transfer-controller
-- Version: 	0.1
---------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.transceiver_128bit_types.all;
use work.pcie.all;
use work.host_channel_types.all;

entity dma_decoder_filter is
	generic(
		CHANNEL_ID : natural := 1
	);
	port(
		-- control signals
		rst_in  : in  std_logic;
		rst_out : out std_logic;  -- pipelined syncronous reset signal
		clk     : in std_logic;
		
		-- input port
		i_vld : in  std_logic := '0';
		i_req : out std_logic;
		i     : in  fragment;
		
		-- output ports for memory completions
		cpl_vld : out std_logic := '0';
		cpl     : out fragment;
		
		-- output ports for parsed memory requests
		rq_vld     : out std_logic := '0';
		rq_type    : out request_t;                      -- memory request type, MRd or MWr are supported
		rq_tag     : out unsigned(7 downto 0);   -- request tag field
		rq_payload : out std_logic_vector(31 downto 0);  -- memory request payload
		rq_addr    : out unsigned(3 downto 0)            -- bar register target address
	);
end entity dma_decoder_filter;

architecture RTL of dma_decoder_filter is
	
	type state_t is (WAIT_FOR_SOF, WAIT_FOR_EOF);
	signal state : state_t := WAIT_FOR_SOF;
	
	signal dword0 : common_dw0 := init_common_dw0;
	signal is_correct_channel : std_logic := '0';
	
	signal o_packet : fragment := default_fragment;
	
begin
	i_req <= '1'; -- never stop input stream from endpoint module

	dword0             <= to_common_dw0(get_dword(i, 0));
	is_correct_channel <= '1' when unsigned(dword0.chn_id) = to_unsigned(CHANNEL_ID, 8) else '0';
	
	filter : process is
	begin
		wait until rising_edge(clk);
		rst_out <= rst_in;

		-- defaults
		rq_vld  <= '0'; -- requests are valid only for one clock cycle

		case state is
		when WAIT_FOR_SOF =>
			cpl_vld <= '0';
			
			if i_vld = '1' and i.sof = '1' then

				if is_correct_channel = '1' then
					case get_type(i) is
					when MWr32_desc | MRd32_desc =>
						rq_vld  <= '1';
					when CplD_desc =>
						cpl_vld <= '1';
					when others => null;
					end case;
				end if;

				-- if eof is not set to 1, packet length is greater than one 128 bit word
				if i.eof = '0' then
					state <= WAIT_FOR_EOF;
				end if;
			end if;

		when WAIT_FOR_EOF =>
			if i_vld = '1' and i.eof = '1' then
				state <= WAIT_FOR_SOF;
			end if;
		end case;

		o_packet <= i;
		
		if rst_in = '1' then
			rq_vld  <= '0';
			cpl_vld <= '0';
			state   <= WAIT_FOR_SOF;
		end if;
	end process;

	cpl <= o_packet;
	
	-- parse o_packet to get relevant information about memory requests from host
	rq_type    <= MWr when get_type(o_packet) = MWr32_desc else MRd;
	rq_tag     <= unsigned(get_rqst32(o_packet.data(95 downto 0)).dw0.tag);
	rq_payload <= get_dword(o_packet, 3);
	-- bar register target address is encoded in the lower 4 bits 
	rq_addr    <= unsigned(get_rqst32(o_packet.data(95 downto 0)).dw2.address(5 downto 2));

end architecture RTL;
