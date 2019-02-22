-- Sender Cfg Ctrl Testbench
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.host_types.all;

use work.fpga_filter_pkg.all;
use work.sender_cfg_ctrl_types.all;

entity tb_sender_cfg_ctrl is
generic(runner_cfg: string);
end entity;

architecture tb of tb_sender_cfg_ctrl is
	constant clk_period: integer := 2;
	signal clk: std_logic := '0';

	constant test_addr: u64 := x"0123456789abcdef";

	signal i_pkt: filter_packet := ((others => '0'), (others => '0'));
	signal i_vld, i_req: std_logic := '0';
	signal config: fpga_tx_config_t := init_config;
begin

clk <= not clk after (clk_period/2) * 1 ns;

main: process
begin
	test_runner_setup(runner, runner_cfg);
	while test_suite loop
		if run("test_addr_modes") then
			wait until rising_edge(clk);
			check_equal(i_req, '1');
			i_vld <= '1';
			i_pkt.address <= x"0";
			i_pkt.payload <= test_addr(31 downto 0);
			wait until rising_edge(clk);

			i_pkt.address <= x"1";
			i_pkt.payload <= test_addr(63 downto 32);
			wait until rising_edge(clk);

			check(config.addr_mode = ADDR_32BIT);
			check_equal(config.addr, x"00000000" & test_addr(31 downto 0));
			wait until rising_edge(clk);

			i_vld <= '0';
			check(config.addr_mode = ADDR_64BIT);
			check_equal(config.addr, test_addr);

		elsif run("test_target_modes") then
			wait until rising_edge(clk);
			i_vld <= '1';
			i_pkt.address <= x"3";
			i_pkt.payload <= x"0000_0001";
			wait until rising_edge(clk);

			i_pkt.address <= x"3";
			i_pkt.payload <= x"0000_0000";
			wait until rising_edge(clk);

			check_relation(config.target = TARGET_FPGA,
				"target_mode wrong, is " & target_mode_t'image(config.target) &
				"should: " & target_mode_t'image(TARGET_FPGA));
			check_relation(config.addr_mode = ADDR_32BIT, "addr_mode wrong");
			wait until rising_edge(clk);

			check_relation(config.target = TARGET_HOST,
				"target_mode wrong, is: " & target_mode_t'image(config.target) &
				"; should: " & target_mode_t'image(TARGET_HOST));

		elsif run("test_resets") then
			wait until rising_edge(clk);
			i_vld <= '1';
			i_pkt.address <= x"2";
			i_pkt.payload <= to_unsigned(32,32);
			wait until rising_edge(clk);

			i_vld <= '0';
			wait until rising_edge(clk);

			check_equal(config.size_bytes, 32);
			wait until rising_edge(clk);

			wait until rising_edge(clk);
			wait until rising_edge(clk);

			wait until rising_edge(clk);

			i_vld <= '1';
			i_pkt.address <= x"4";
			i_pkt.payload <= to_unsigned(32, 32);
			wait until rising_edge(clk);

			i_vld <= '0';
			wait until rising_edge(clk);

			check_equal(config.cpld_tag, 32);
			wait until rising_edge(clk);

			wait until rising_edge(clk);
			wait until rising_edge(clk);


		end if;
	end loop;
	test_runner_cleanup(runner);
	wait;
end process main;
test_runner_watchdog(runner, 10 ms);

uut: entity work.sender_cfg_ctrl
port map(
	clk => clk,
	i => i_pkt,
	i_vld => i_vld,
	i_req => i_req,
	cfg => config
);



end architecture;
