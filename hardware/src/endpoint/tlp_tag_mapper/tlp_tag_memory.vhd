---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description: stores mapping of in-flight MRd tags
-- Version: 	0.1
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity tlp_tag_memory is
	port(
		clk  : in  std_logic;
		rst  : in  std_logic;

		i     : in  std_logic_vector(7 downto 0);
		wr_en : in  std_logic;
		
		o     : out std_logic_vector(7 downto 0);
		rd_en : in  std_logic;
		avail : out std_logic
	);
end tlp_tag_memory;

architecture arch of tlp_tag_memory is
	
	type ram_t is array (0 to 255) of std_logic_vector(7 downto 0);

	function init_ram return ram_t is
		variable ret : ram_t; 
	begin
		for idx in 0 to 255 loop
			ret(idx) := std_logic_vector(to_unsigned(idx, 8));
		end loop;
		return ret;
	end;
	
	signal fifo    : ram_t := init_ram;
	
	signal rd_ptr  : unsigned(7 downto 0) := (others => '0');
	signal wr_ptr  : unsigned(7 downto 0) := (others => '0');
	
	type state_t is (EMPTY, NOT_EMPTY, RESET);
	signal state : state_t := NOT_EMPTY;
	
begin
	
o     <= fifo(to_integer(rd_ptr));
avail <= '1' when state = NOT_EMPTY else '0';
	
main: process
begin
	wait until rising_edge(clk);
	
	if wr_en = '1' then
		fifo(to_integer(unsigned(wr_ptr))) <= i;
		wr_ptr <= wr_ptr + 1;
	end if;
	
	case state is
	when NOT_EMPTY =>
		if rd_en = '1' then
			rd_ptr <= rd_ptr + 1;
			
			if wr_en = '0' and rd_ptr = wr_ptr - 1 then
				state <= EMPTY;
			end if;
		end if;
		
	when EMPTY =>
		if wr_en = '1' then
			state <= NOT_EMPTY;
		end if;

	when RESET =>
		wr_ptr <= wr_ptr + 1;
		fifo(to_integer(unsigned(wr_ptr))) <= std_logic_vector(wr_ptr);
		
		if wr_ptr = 255 then
			state <= NOT_EMPTY;
		end if;
	end case;
	
	if rst = '1' then
		state <= RESET;
		rd_ptr <= (others => '0');
		wr_ptr <= (others => '0');
	end if;

end process;

end architecture;