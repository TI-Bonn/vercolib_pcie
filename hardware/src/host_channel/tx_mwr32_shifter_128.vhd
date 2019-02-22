---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;

entity tx_mwr32_shifter_128 is
	port(
		clk    : in std_logic;

		-- Input Port
		i      : in  fragment;
		i_vld  : in  std_logic;
		i_req  : out std_logic := '1';

		-- Output Port
		o      : out fragment := default_fragment;
		o_vld  : out std_logic := '0';
		o_req  : in  std_logic        
	);
end tx_mwr32_shifter_128;


architecture arch of tx_mwr32_shifter_128 is

	type state_t is (SIMPLE_FORWARD, MWR32_SHIFT);
	signal state : state_t := SIMPLE_FORWARD;
	signal buf : fragment := default_fragment;
	signal buf_vld : std_logic := '0';

begin

i_req <= o_req or not buf_vld;

process
begin
	wait until rising_edge(clk);
	
	case state is 
	when SIMPLE_FORWARD =>
		
		if o_req = '1' then
			o     <= buf;
			o_vld <= buf_vld;
		end if;
			
		if (i_vld = '1' and i.sof = '1' and get_type(i) = MWr32_desc) and (o_req = '1' or buf_vld = '0') then
			state <= MWR32_SHIFT;
		end if;
		
		if o_req = '1' or buf_vld = '0' then
			buf     <= i;
			buf_vld <= i_vld;
		end if;
		
	when MWR32_SHIFT =>

		if o_req = '1' then
			o_vld  <= i_vld and buf_vld;
			
			o.data <= i.data(31 downto 0) & buf.data(95 downto 0);
			o.keep <= i.keep(          0) & buf.keep( 2 downto 0);
			o.sof  <= buf.sof;
			o.eof  <= (not (i.keep(3) or i.keep(2) or i.keep(1)) and i.eof) or buf.eof;
			
			if i_vld = '1' then
				buf.data(95 downto 0) <= i.data(127 downto 32);
				
				buf.keep <= '0' & i.keep( 3 downto 1);
				buf.eof  <= (i.keep(3) or i.keep(2) or i.keep(1)) and i_vld and i.eof;
				buf.sof  <= i.sof;
			    buf_vld  <= (i.keep(3) or i.keep(2) or i.keep(1)) and i_vld;
			
				if i.eof = '1' then
					state   <= SIMPLE_FORWARD;
				end if;
			end if;
		end if;
	end case;

end process;

end architecture;
