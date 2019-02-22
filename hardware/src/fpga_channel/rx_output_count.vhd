-- Simple counter for fifo_output
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils.all;

entity receiver_output_count is
generic(max_count: natural);
port(
	clk: in std_logic;
	rst: in std_logic;

	i_vld: in std_logic;
	o_req: in std_logic;

	overflow: out std_logic := '0');
end entity;

architecture arch of receiver_output_count is
	signal cnt: unsigned(repr(max_count) downto 0) := (others => '0');
begin

process
	variable next_cnt: unsigned(repr(max_count) downto 0);
begin
	wait until rising_edge(clk);

	next_cnt := cnt + 1 when i_vld and o_req else cnt;
	cnt <= (others => '0') when next_cnt = max_count else next_cnt;

	overflow <= '1' when next_cnt = max_count else '0';

	if rst then
		overflow <= '0';
		cnt <= (others => '0');
	end if;
end process;

end architecture;
