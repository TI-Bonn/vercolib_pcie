---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description: saves 
-- Version: 	0.1
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity virtual_tag_memory is
	port(
		clk       : in std_logic;
		rst       : in std_logic;

		wr_en     : in std_logic;
		wr_addr   : in std_logic_vector(7 downto 0);
		wr_chn_id : in std_logic_vector(7 downto 0);
		wr_tag    : in std_logic_vector(7 downto 0);

		rd_addr   : in std_logic_vector(7 downto 0);
		rd_chn_id : out std_logic_vector(7 downto 0);
		rd_tag    : out std_logic_vector(7 downto 0)
	);
end virtual_tag_memory;

architecture arch of virtual_tag_memory is

	type ram_t is array (0 to 255) of std_logic_vector(15 downto 0);
	signal mem : ram_t := (others => (others => '0'));

	signal mem_out : std_logic_vector(15 downto 0);
begin
	
rd_chn_id <= mem_out(15 downto 8);
rd_tag    <= mem_out( 7 downto 0);
	
main: process
begin
	wait until rising_edge(clk);
	if wr_en = '1' then
		mem(to_integer(unsigned(wr_addr))) <= wr_chn_id & wr_tag;
	end if;
	mem_out <= mem(to_integer(unsigned(rd_addr)));
	
	if rst = '1' then -- TODO Does this work?
		mem <= (others => (others => '0'));
	end if;
end process;

end architecture;