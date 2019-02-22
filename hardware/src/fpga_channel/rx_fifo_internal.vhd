-- Simple 128bit FIFO
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fpga_rx_fifo_internal is
generic(depth_bits: positive);
port(
	clk: in std_logic;
	rst: in std_logic;

	i:      in  std_logic_vector(127 downto 0);
	i_keep: in  std_logic_vector(  3 downto 0);
	i_vld:  in  std_logic;
	i_req:  out std_logic := '1';

	o:      out std_logic_vector(127 downto 0) := (others => '0');
	o_keep: out std_logic_vector(  3 downto 0) := (others => '0');
	o_vld:  out std_logic := '0';
	o_req:  in  std_logic);
end entity;

architecture arch of fpga_rx_fifo_internal is
	type mem_t is array (0 to 2**depth_bits) of std_logic_vector(128+4-1 downto 0);
	signal mem: mem_t := (others => (others => '0'));

	signal i_packed, o_packed: std_logic_vector(128+4-1 downto 0) := (others => '0');

	type state_t is (EMPTY, WORKING, FULL);
	signal state: state_t := EMPTY;

	subtype ptr_t is unsigned(depth_bits - 1 downto 0);
	signal wr, rd: ptr_t := (others => '0');

	signal status: unsigned(depth_bits downto 0) := (others => '0');
begin

i_req <= '1' when state /= FULL else '0';

i_packed <= i & i_keep;
o_keep   <= o_packed(  3 downto 0);
o        <= o_packed(131 downto 4);

io: process
	variable written, read: unsigned(0 downto 0) := (others => '0');
begin
	wait until rising_edge(clk);

	written := 1b"0";
	read    := 1b"0";

	if (??i_vld) and state /= FULL then
		written := d"1";
		mem(to_integer(wr)) <= i_packed;
		wr <= wr + 1;
	end if;

	if o_req then
		o_vld <= '0';
		if  state /= EMPTY then
			read := d"1";
			o_packed <= mem(to_integer(rd));
			rd <= rd + 1;
			o_vld <= '1';
		end if;
	end if;

	status <= status + written - read;

	if rst then
		o_vld <= '0';
		wr <= (others => '0');
		rd <= (others => '0');
		status <= (others => '0');
	end if;
end process;

fsm: process
begin
	wait until rising_edge(clk);

	case state is
	when EMPTY =>
		state <= WORKING when i_vld else
		         EMPTY;
	when WORKING =>
		state <= EMPTY when (??o_req) and not (??i_vld) and status = 1 else
		         FULL  when (??i_vld) and not (??o_req) and status = (2**depth_bits-1) else
		         WORKING;
	when FULL =>
		state <= WORKING when o_req else
		         FULL;
	end case;
end process;


end architecture arch;

