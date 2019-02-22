-- Actual FIFO element for fpga_tx_fifo
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie.all;
use work.pcie_fifo_packet.all;

entity fifo_internal is
port(
	clk: in std_logic;

	i: in tx_stream;
	i_vld: in  std_logic;
	i_req: out std_logic := '1';

	status: out fifo_status := ((others => '0'), '0');

	o: out fifo_vec := (others => (others => '0'));
	o_vld: out std_logic := '0';
	o_req: in  std_logic);
end entity;


architecture arch of fifo_internal is
	pure function ones(v: std_logic_vector) return natural is
		variable ret: natural := 0;
	begin
		for i in 0 to v'length - 1 loop
			if ?? v(i) then
				ret := ret + 1;
			end if;
		end loop;
		return ret;
	end ones;

	pure function umin(a,b: unsigned) return unsigned is
		variable ret: unsigned(maximum(a'high,b'high) downto 0);
	begin
		if a <= b then
			ret := resize(a, ret'length);
		else
			ret := resize(b, ret'length);
		end if;
		return ret;
	end function;

	type state_t is (EMPTY, WORKING, FULL, EOT);
	signal state: state_t := EMPTY;

	type mem_t is array(0 to 512) of std_logic_vector(127 downto 0);
	signal mem: mem_t := (others => (others => '0'));
	--attribute ram_style: string;
	--attribute ram_style of mem: signal is "block";

	subtype ptr_t is unsigned(8 downto 0);
	signal wr, rd: ptr_t := (others => '0');
	signal read_word: std_logic_vector(127 downto 0) := (others => '0');

	signal almost_full, almost_empty: boolean := false;
begin

almost_full  <= status.dwords >= (511*4);
almost_empty <= status.dwords <= 4;

with state select i_req <=
	'0' when FULL,
	'0' when EOT,
	'1' when others;

with state select status.got_eob <=
	'1' when EOT,
	'0' when others;

o  <= as_arr(read_word);
io: process
	variable written, read: unsigned(2 downto 0) := (others => '0');
begin
	wait until rising_edge(clk);
	written := (others => '0');
	read    := (others => '0');

	if i_vld = '1' and state /= FULL and state /= EOT then
		mem(to_integer(wr)) <= i.payload;
		wr <= wr + 1;
		written := i.cnt;
	end if;

	if o_req = '1' then
		o_vld <= '0';
		if state /= EMPTY then
			read_word <= mem(to_integer(rd));
			rd <= rd + 1;
			o_vld <= '1';
		end if;
		if o_vld then
			read := resize(umin(to_unsigned(4,4), status.dwords), 3);
		end if;
	end if;
	status.dwords <= status.dwords + written - read;
end process io;

fsm: process
begin
	wait until rising_edge(clk);

	case state is
	when EMPTY =>
		state <= WORKING when i_vld = '1' and i.end_of_stream = '0' else
		         EOT     when i_vld = '1' and i.end_of_stream = '1' else
		         EMPTY;
	when WORKING =>
		state <= EOT     when i_vld = '1' and i.end_of_stream = '1' else
		         FULL    when i_vld = '1' and o_req = '0' and almost_full else
		         EMPTY   when i_vld = '0' and o_req = '1' and almost_empty else
		         WORKING;
	when FULL =>
		state <= WORKING when o_req = '1' else
		         FULL;
	when EOT =>
		state <= EMPTY when o_req = '1' and almost_empty else
		         EOT;
	end case;
end process fsm;


end architecture;
