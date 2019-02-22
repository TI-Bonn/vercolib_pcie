-- Special FIFO for sending PCIe packages
-- Author: Sebastian Schüller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie.all;
use work.pcie_fifo_packet.all;

entity fpga_tx_fifo is
port(
	clk: in std_logic;

	i: in  tx_stream;
	i_vld: in  std_logic;
	i_req: out std_logic := '1';

	o: out fifo_packet := init_fifo_packet;
	o_req: in std_logic;

	status: out fifo_status := (dwords => (others => '0'), got_eob => '0')
);
end entity;

architecture arch of fpga_tx_fifo is

	signal fifo: fifo_vec := (others => (others => '0'));
	signal fifo_stat: fifo_status := ((others => '0'), '0');
	signal fifo_vld: std_logic := '0';
	signal fifo_req: std_logic := '1';
	signal prev_dwords: unsigned(2 downto 0) := (others => '0');
	signal data_dwords: unsigned(2 downto 0) := (others => '0');
	signal prev_eob, data_eob: std_logic := '0';
begin

internal_fifo: entity  work.fifo_internal
port map(
	clk => clk,
	i => i,
	i_vld => i_vld,
	i_req => i_req,
	status => fifo_stat,
	o => fifo,
	o_vld => fifo_vld,
	o_req => fifo_req
);

status.dwords <= resize(fifo_stat.dwords + prev_dwords + data_dwords, status.dwords'length);
status.got_eob <= fifo_stat.got_eob or prev_eob or data_eob;

fifo_req <= o_req;

main: process
begin
	wait until rising_edge(clk);

	if ?? o_req then
		if fifo_vld or o.prev_vld then
			prev_dwords <= resize(minimum(4, fifo_stat.dwords),3);
		end if;

		if o.prev_vld or o.data_vld then
			data_dwords <= prev_dwords;
		end if;

		prev_eob <= fifo_stat.got_eob;
		data_eob <= prev_eob;
		o.data <= o.prev;
		o.data_vld <= o.prev_vld;
		o.prev <= fifo;
		o.prev_vld <= fifo_vld;
	end if;
end process main;


end architecture;
