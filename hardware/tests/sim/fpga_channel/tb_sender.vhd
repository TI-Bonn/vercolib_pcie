-- Sender Channel Testbench
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.transceiver_128bit_types.all;
use work.host_types.all;
use work.pcie;
use work.utils.all;

entity tb_sender  is
generic(runner_cfg: string);
end entity;


architecture arch of tb_sender is
	signal clk: std_logic := '0';
	constant clk_per: natural := 2;

	signal start, done, fed_enough: boolean := false;

	signal data_length: natural := 0;

	signal i: pcie.tx_stream;
	signal cfg, o: pcie.fragment := pcie.default_fragment;
	signal i_vld, cfg_vld, o_vld: std_logic := '0';
	signal i_req, cfg_req, o_req: std_logic := '1';
begin

clk <= not clk after clk_per/2*1 ns;


main: process
begin
	test_runner_setup(runner, runner_cfg);
	while test_suite loop
	if run("test packet w req=1") then
		o_req <= '1';
		data_length <= 128;
		start <= true;

		wait until rising_edge(clk) and fed_enough for 200 ns;
		check_equal(fed_enough, true);
		check_equal(i_req, '1');
		set_rqst32_header(cfg, make_wr_rqst32(
			length => 1,
			chn_id => 2,
			address => 32x"f7301080"
		));
		set_dw(cfg, 3, 32x"f720107c");
		cfg_vld <= '1';

		wait until rising_edge(clk);
		set_rqst32_header(cfg, make_wr_rqst32(
			length => 1,
			chn_id => 2,
			address => 32x"f730108c"
		));
		set_dw(cfg, 3, 32x"1");

		wait until rising_edge(clk);
		set_rqst32_header(cfg, make_wr_rqst32(
			length => 1,
			chn_id => 2,
			address => 32x"f7301088"
		));
		set_dw(cfg, 3, 32d"512");

		wait until rising_edge(clk);
		cfg_vld <= '0';

		wait until done;

	end if;
	end loop;
	test_runner_cleanup(runner);
end process;
test_runner_watchdog(runner, 1 ms);

validate: process
	type parser_state is (HEADER, PAYLOAD);
	variable state: parser_state := HEADER;

	variable cnt, glob_cnt: natural := 0;
begin
	wait until start;
	loop
		wait until rising_edge(clk) and (??o_vld) for 500 ns;
		check_equal(o_vld, '1');
		if o_vld then
		case state is
		when HEADER =>
			check_equal(o.sof, '1');
			check_equal(o.eof, '0');
			check_relation(to_integer(unsigned(get_rqst32(o.data).dw0.length)) = 32);
			check_relation(get_rqst32(o.data).dw2.address = std_logic_vector'(32x"f720107c"));
			check_relation(o.keep = std_logic_vector'("1111"));

			cnt   := 1;
			state := PAYLOAD;

		when PAYLOAD =>
			check_equal(o.sof, '0');

			cnt := cnt + ones(o.keep);
			glob_cnt := glob_cnt + cnt;
			if o.eof then
				check_relation(o.keep = std_logic_vector'("0111"));
				check_relation(cnt = 32);
				state := HEADER;
			else
				check_relation(o.keep = std_logic_vector'("1111"));
			end if;
		end case;
		end if;
		exit when glob_cnt >= data_length;
	end loop;

	done <= true;
end process;

/*
check_req: process
begin
	wait until start;
	loop
		check_equal(cfg_req, '1');
		exit when done;
	end loop;
end process;
*/
uut: entity work.fpga_tx_channel
generic map(config => pcie.new_config(host_rx => 0, host_tx => 0), id => 2)
port map(
	clk => clk,
	rst => '0',
	from_ep => cfg,
	from_ep_vld => cfg_vld,
	from_ep_req => cfg_req,
	to_ep => o,
	to_ep_vld => o_vld,
	to_ep_req => o_req,
	i => i,
	i_vld => i_vld,
	i_req => i_req
);


feeder: process
	variable val_gen: natural := 0;
begin
	wait until start;
	loop
		wait until rising_edge(clk);
		if i_req then
			i_vld <= '1';
			i.cnt <= 3x"4";
			i.end_of_stream <= '0';
			i.payload( 31 downto  0) <= std_logic_vector(to_unsigned(val_gen  ,32));
			i.payload( 63 downto 32) <= std_logic_vector(to_unsigned(val_gen+1,32));
			i.payload( 95 downto 64) <= std_logic_vector(to_unsigned(val_gen+2,32));
			i.payload(127 downto 96) <= std_logic_vector(to_unsigned(val_gen+3,32));
			val_gen := val_gen+4;
		end if;
		fed_enough <= true when val_gen >= 64;
		exit when done;
	end loop;
end process;



end architecture;
