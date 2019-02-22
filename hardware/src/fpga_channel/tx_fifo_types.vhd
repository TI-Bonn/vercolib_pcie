-- Special fifo types
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.host_types.all;

package pcie_fifo_packet is

	type fifo_vec is array(3 downto 0) of dword;
	constant init_fifo_vec: fifo_vec := (others => (others => '0'));

	pure function as_arr(inp: std_logic_vector(127 downto 0)) return fifo_vec;
	pure function as_vec(inp: fifo_vec) return std_logic_vector;

	type fifo_packet is record
		data: fifo_vec;
		data_vld: std_logic;
		prev: fifo_vec;
		prev_vld: std_logic;
	end record;

	constant init_fifo_packet: fifo_packet := (
		data     => (others => (others => '0')),
		data_vld => '0',
		prev     => (others => (others => '0')),
		prev_vld => '0'
	);

	type fifo_status is record
		dwords: unsigned(12 downto 0);
		got_eob: std_logic;
	end record;

	type fifo_input is record
		data: std_logic_vector(127 downto 0);
		keep: std_logic_vector(  3 downto 0);
		eob:  std_logic;
	end record;

	constant init_fifo_input: fifo_input := (
		data => (others => '0'),
		keep => (others => '0'),
		eob  => '0'
	);

end package;

package body pcie_fifo_packet is
	pure function as_arr(inp: std_logic_vector(127 downto 0))
		return fifo_vec is
	begin
		return (dword(inp(127 downto 96)), dword(inp(95 downto 64)),
		        dword(inp( 63 downto 32)), dword(inp(31 downto  0)));
	end as_arr;

	pure function as_vec(inp: fifo_vec)
		return std_logic_vector is
	begin
		return inp(3) & inp(2) & inp(1) & inp(0);
	end as_vec;

end pcie_fifo_packet;
