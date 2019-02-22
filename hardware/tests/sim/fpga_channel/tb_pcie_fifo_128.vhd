-- PCIe FIFO TB
-- Author: Sebastian Schüller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.pcie;
use work.pcie_fifo_packet.all;

entity tb_fpga_tx_fifo is
generic(runner_cfg: string);
end entity;


architecture tb of tb_fpga_tx_fifo is
	constant clk_period: integer := 2;
	signal   clk: std_logic := '0';

	signal i: pcie.tx_stream := pcie.default_tx_stream;
	signal i_vld, i_req, o_req: std_logic := '0';
	signal status: fifo_status := ((others => '0'), '0');
	signal o: fifo_packet := init_fifo_packet;

begin

clk <= not clk after (clk_period/2) * 1 ns;

main: process
begin
	test_runner_setup(runner, runner_cfg);
	while test_suite loop
		if run("test_single_word") then
			check_equal(i_req, '1');
			check_equal(o_req, '0');
			wait until rising_edge(clk);

			i_vld <= '1';
			i.cnt <= 3x"4";
			i.payload <= 128Ux"0fff";
			wait until rising_edge(clk);

			i_vld <= '0';
			wait until rising_edge(clk) and status.dwords /= 0;

			check_equal(status.dwords, 4);
			check_equal(status.got_eob, '0');
			check_equal(o.data_vld, '0');
			check_equal(o.prev_vld, '0', "Prev should not be valid");
			o_req <= '1';
			wait until rising_edge(clk);

			check_equal(status.dwords, 4);
			check_equal(o.data_vld, '0');
			check_equal(o.prev_vld, '0', "Prev should not be valid");
			wait until rising_edge(clk);
			wait until rising_edge(clk);

			check_equal(status.dwords, 4);
			check_equal(o.data_vld, '0');
			check_equal(o.prev_vld, '1', "No valid preview");
			wait until rising_edge(clk);

			check_equal(status.dwords, 4);
			check_equal(o.data_vld, '1', "No valid FIFO output!");
			check_equal(o.prev_vld, '0', "Prev should not be valid");
			wait until rising_edge(clk);

			check_equal(status.dwords, 0);
			check_equal(o.data_vld, '0', "FIFO should not be valid!");
			check_equal(o.prev_vld, '0', "Prev should not be valid");


		elsif run("test_single_word_eob") then
			check_equal(i_req, '1');
			check_equal(o_req, '0');
			wait until rising_edge(clk);

			i_vld <= '1';
			i.cnt <= 3x"2";
			i.payload <= 128Ux"abcdef";
			i.end_of_stream <= '1';
			wait until rising_edge(clk);

			i_vld <= '0';
			wait until rising_edge(clk);

			check_equal(status.dwords, 2);
			check_equal(status.got_eob, '1');
			o_req <= '1';
			wait until rising_edge(clk);

			check_equal(o.data_vld, '0');
			check_equal(o.prev_vld, '0');
			check_equal(status.dwords, 2);
			check_equal(status.got_eob, '1', "No eob present.");
			wait until rising_edge(clk);

			check_equal(o.data_vld, '0');
			check_equal(o.prev_vld, '0');
			check_equal(status.dwords, 2);
			check_equal(status.got_eob, '1', "No eob present.");
			wait until rising_edge(clk);

			check_equal(o.data_vld, '0');
			check_equal(o.prev_vld, '1', "Preview not valid.");
			check_equal(status.dwords, 2);
			check_equal(status.got_eob, '1', "Got no eob.");
			wait until rising_edge(clk);

			check_equal(o.data_vld, '1', "No valid output.");
			check_equal(o.prev_vld, '0');
			check_equal(status.dwords, 2);
			check_equal(status.got_eob, '0', "Still no eob.");
			wait until rising_edge(clk);

			check_equal(o.data_vld, '0');
			check_equal(o.prev_vld, '0');
			check_equal(status.dwords, 0);
			check_equal(status.got_eob, '0');
			wait until rising_edge(clk);

		elsif run("test_fill_fifo") then
			check_equal(i_req, '1');
			check_equal(o_req, '0');
			wait until rising_edge(clk);

			for n in 0 to 512 loop
				check_equal(i_req, '1', "FIFO blocks to soon");
				i_vld <= '1';
				i.payload(127 downto 96) <= std_logic_vector(to_unsigned(n+0, 32));
				i.payload( 95 downto 64) <= std_logic_vector(to_unsigned(n+1, 32));
				i.payload( 63 downto 32) <= std_logic_vector(to_unsigned(n+2, 32));
				i.payload( 31 downto  0) <= std_logic_vector(to_unsigned(n+3, 32));
				i.cnt <= 3x"4";
				i.end_of_stream  <= '0';
				wait until rising_edge(clk);
			end loop;

			i_vld <= '0';
			check_equal(i_req, '0');
			check_equal(status.dwords, 512*4);
			wait until rising_edge(clk);

			check_equal(status.dwords, 512*4);
			o_req <= '1';
			wait until rising_edge(clk);

			check_equal(i_req, '0');
			check_equal(status.dwords, 512*4);
			wait until rising_edge(clk);

			check_equal(i_req, '1');
			check_equal(status.dwords, 512*4);
			wait until rising_edge(clk);

			check_equal(i_req, '1');
			check_equal(status.dwords, 512*4);
			check_equal(o.prev_vld, '1');
			check_equal(o.data_vld, '0');
			wait until rising_edge(clk);

			check_equal(o.data_vld, '1');
			check_equal(status.dwords, 512*4);
			wait until rising_edge(clk);

			check_equal(status.dwords, 511*4);
			wait until rising_edge(clk);

			check_equal(i_req, '1');
		end if;
	end loop;
	test_runner_cleanup(runner);
	wait;
end process main;
test_runner_watchdog(runner, 1 ms);

uut: entity work.fpga_tx_fifo
port map(
	clk => clk,
	i => i,
	i_vld => i_vld,
	i_req => i_req,
	o => o,
	o_req => o_req,
	status => status
);

end architecture;
