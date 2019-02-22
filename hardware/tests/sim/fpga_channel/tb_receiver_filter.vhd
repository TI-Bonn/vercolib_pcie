-- Receiver filter Testbench
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.pcie;
use work.transceiver_128bit_types.all;
use work.host_types.all;
use work.fpga_filter_pkg.all;

entity tb_fpga_rx_filter is
generic(runner_cfg: string);
end entity;


architecture arch of tb_fpga_rx_filter is
	signal clk: std_logic := '0';
	constant clk_per: natural := 2;

	type test_mode_t is (NONE, CFG, DAT);
	signal test_mode: test_mode_t := NONE;
	signal done: boolean := false;

	signal i, data: pcie.fragment := pcie.default_fragment;
	signal i_vld, data_vld: std_logic := '0';
	signal i_req, data_req: std_logic := '1';

	signal config: filter_packet := ((others => '0'),(others => '0'));
	signal cfg_vld: std_logic := '0';

	signal cfg_addr: unsigned(3 downto 0) := (others => '0');
	signal cfg_payload: unsigned(31 downto 0) := (others => '0');
begin

clk <= not clk after clk_per/2*1 ns;

main: process
begin
	test_runner_setup(runner, runner_cfg);
	while test_suite loop
	if run("test cfg packet") then
		wait until rising_edge(clk);

		reset(i);
		test_mode <= CFG;
		cfg_addr    <= "0000";
		cfg_payload <= 32b"1";
		set_rqst32_header(i, make_wr_rqst32(
			length => 1,
			chn_id => 1,
			address => 32x"f7201040"
		));
		set_dw(i,3,32b"1");
		i_vld  <= '1';

		wait until rising_edge(clk);
		i_vld <= '0';

		wait until done;

	elsif run("test data packet") then
		wait until rising_edge(clk);

		reset(i);
		test_mode <= DAT;
		set_rqst32_header(i, make_wr_rqst32(
			length => 8,
			chn_id => 1,
			address => 32x"f720107c"
		));
		set_dw(i, 3, 32b"0");
		i_vld <= '1';

		wait until rising_edge(clk);

		reset(i);
		set_dw(i,0,32d"1");
		set_dw(i,1,32d"2");
		set_dw(i,2,32d"3");
		set_dw(i,2,32d"4");


		wait until rising_edge(clk);

		reset(i);
		set_dw(i,0,32d"4");
		set_dw(i,1,32d"5");
		set_dw(i,2,32d"6");
		i.eof <= '1';

		wait until rising_edge(clk);

		i_vld <= '0';

		wait until done;

	end if;
	end loop;
	test_runner_cleanup(runner);
end process;
test_runner_watchdog(runner, 30 ns);

check_req: process
begin
	loop
		wait until rising_edge(clk);
		check_equal(i_req, '1');
		exit when done;
	end loop;
end process;

data_req <= '1';

validate: process
begin
	wait until test_mode /= NONE;

	case test_mode is
	when CFG =>
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		check_equal(cfg_vld, '1');
		check_relation(config.address = cfg_addr);
		check_relation(config.payload = cfg_payload);

		wait until rising_edge(clk);
		check_equal(cfg_vld, '0');
		done <= true;

	when DAT =>
		wait until rising_edge(clk);
		wait until rising_edge(clk);

		check_equal(data_vld, '1');
		check_equal(data.sof, '1');
		check_equal(data.eof, '0');
		while not data.eof loop
			wait until rising_edge(clk);
			check_equal(data_vld, '1');
		end loop;
		check_equal(data_vld, '1');
		wait until rising_edge(clk);
		check_equal(data_vld, '0');

		done <= true;

	when others => null;
	end case;
end process;

uut: entity work.fpga_rx_filter
generic map(id => 1)
port map(
	clk      => clk,
	i        => i,
	i_vld    => i_vld,
	i_req    => i_req,
	cfg      => config,
	cfg_vld  => cfg_vld,
	data     => data,
	data_vld => data_vld,
	data_req => data_req
);


end architecture arch;
