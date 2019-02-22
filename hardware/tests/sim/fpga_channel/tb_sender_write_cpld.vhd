-- Sender write cpld testbench
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.host_types.all;

use work.pcie;
use work.transceiver_128bit_types.all;

use work.sender_cfg_ctrl_types.all;


entity tb_sender_fpga_tx_write_cpld is
generic(runner_cfg: string);
end entity;

architecture tb of tb_sender_fpga_tx_write_cpld is
	constant clk_period: natural := 2;
	signal clk: std_logic := '0';

	constant chn_id: natural := 2;

	signal config: fpga_tx_config_t := init_config;
	signal o_pkt: pcie.fragment := pcie.default_fragment;
	signal o_vld, o_req: std_logic := '0';

	signal trans: u32 := (others => '0');
begin

clk <= not clk after clk_period/2 * 1 ns;

main: process
	variable cpl: cpld := init_cpld;
begin
	test_runner_setup(runner, runner_cfg);
	while test_suite loop
		if run("test_normal") then
			o_req <= '1';
			wait until rising_edge(clk);

			config.cpld_tag <= to_unsigned(32, 8);
			config.trigger_cpld <= true;
			trans <= to_unsigned(256, 32);
			wait until rising_edge(clk);
			wait until rising_edge(clk);

			wait until rising_edge(clk) and o_vld = '1' for 10 ns;
			check_equal(o_vld, '1', "completion didn't happen in time");

			check_equal(o_pkt.sof, '1');
			check_equal(o_pkt.eof, '1');
			check_relation(o_pkt.keep = std_logic_vector'(b"1111"));
			cpl := get_cpld(o_pkt.data);

			check(get_type(o_pkt) = CplD_desc);
			check_equal(cpl.dw0.length, 1);
			check_equal(cpl.dw0.tag, 32);
			check_equal(cpl.dw0.chn_id, chn_id);

			check_equal(cpl.dw1.byte_count, 4);

			wait until rising_edge(clk);
			check_equal(o_vld, '0');

		end if;
	end loop;
	test_runner_cleanup(runner);
end process main;
test_runner_watchdog(runner, 1 ms);

uut: entity work.fpga_tx_write_cpld
generic map(id => chn_id)
port map(
	clk => clk,
	cfg => config,
	data => trans,
	o => o_pkt,
	o_vld => o_vld,
	o_req => o_req
);

end architecture;
