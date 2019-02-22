-- Receiver Channel Testbench
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.transceiver_128bit_types.all;
use work.pcie;
use work.host_types.all;

entity tb_receiver  is
generic(runner_cfg: string);
end entity;

architecture arch of tb_receiver is
	signal clk: std_logic := '0';
	constant clk_per: natural := 2;

	signal start, start_cfg, done, cfg_done: boolean := false;

	signal length: natural := 0;

	signal i,rqst: pcie.fragment := pcie.default_fragment;
	signal o: pcie.rx_stream := pcie.default_rx_stream;
	signal i_vld, o_vld, rqst_vld: std_logic := '0';
	signal i_req, o_req, rqst_req: std_logic := '1';

	function cnt2keep(i: unsigned(2 downto 0)) return std_logic_vector is
		variable ret: std_logic_vector(3 downto 0) := (others => '0');
	begin
		ret :=
			4b"1111" when i = 4 else
			4b"0111" when i = 3 else
			4b"0011" when i = 2 else
			4b"0001" when i = 1 else
			4b"0000" when i = 0 else
			4b"XXXX";
		assert ret /= 4b"XXXX"
			report "Invalid cnt, cnt has to be 4 or lower!"
			severity failure;
		return ret;
	end function;
begin
clk <= not clk after clk_per / 2 * 1 ns;

o_req <= '1';
rqst_req <= '1';

main: process
	variable test_length: natural := 0;
begin
	test_runner_setup(runner, runner_cfg);
	while test_suite loop
	if run("test receive 12 dwords") then
		wait until rising_edge(clk);
		reset(i);
		start_cfg <= true;
		set_rqst32_header(i, make_wr_rqst32(
			length => 1,
			chn_id => 1,
			address => 32x"f720104c"
		));
		set_dw(i, 3, 32x"1");
		i_vld <= '1';

		wait until rising_edge(clk);
		i_vld <= '0';

		wait until cfg_done for 100 ns;
		check(cfg_done);

		wait until rising_edge(clk);
		test_length := 12;
		length <= test_length;
		start <= true;
		i_vld <= '1';

		reset(i);
		set_rqst32_header(i, make_wr_rqst32(
			length => test_length,
			chn_id => 1,
			address => 32x"f720107c"
		));
		set_dw(i, 3, 32x"0");

		wait until rising_edge(clk);
		reset(i);
		set_dw(i, 0, 32d"1");
		set_dw(i, 1, 32d"2");
		set_dw(i, 2, 32d"3");
		set_dw(i, 3, 32d"4");

		wait until rising_edge(clk);
		reset(i);
		set_dw(i, 0, 32d"5");
		set_dw(i, 1, 32d"6");
		set_dw(i, 2, 32d"7");
		set_dw(i, 3, 32d"8");

		wait until rising_edge(clk);
		reset(i);
		set_dw(i, 0, 32d"9");
		set_dw(i, 1, 32d"10");
		set_dw(i, 2, 32d"11");
		i.eof <= '1';

		wait until rising_edge(clk);
		i_vld <= '0';

		wait until done;
	end if;
	end loop;
	test_runner_cleanup(runner);
end process;
test_runner_watchdog(runner, 1 ms);

validate: process
	variable cnt: natural := 0;
	variable val: u32;
begin
	wait until start;
	outer: loop
		wait until rising_edge(clk);
		if o_vld then
		for idx in 0 to 3 loop
			if cnt2keep(o.cnt)(idx) then
				val := unsigned(o.payload((idx+1)*32-1 downto idx*32));
				check_relation(val = cnt);
				cnt := cnt + 1;
				exit outer when cnt >= length - 1;
			end if;
		end loop;
		end if;
	end loop;
	done <= true;
end process;

validate_cfg: process
	variable val : u32 := (others => '0');
begin
	wait until start_cfg;
	loop
		wait until rising_edge(clk);
		if rqst_vld then
			val := unsigned(rqst.data(127 downto 96));
			-- The first request size is relativ to the addr bits
			-- of the receiver fifo
			check_relation(to_integer(val) = (2**9*16-16));
			exit;
		end if;
	end loop;
	cfg_done <= true;
end process;

uut: entity work.fpga_rx_channel
generic map(config => pcie.new_config(host_rx => 0, host_tx => 0), id => 1)
port map(
	clk => clk,
	rst => '0',
	from_ep => i,
	from_ep_vld => i_vld,
	from_ep_req => i_req,
	to_ep => rqst,
	to_ep_vld => rqst_vld,
	to_ep_req => rqst_req,
	o => o,
	o_vld => o_vld,
	o_req => o_req
);


end architecture;
