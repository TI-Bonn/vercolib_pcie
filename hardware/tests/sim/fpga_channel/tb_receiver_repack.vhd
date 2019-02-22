-- Receiver repack Testbench
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.pcie;
use work.transceiver_128bit_types.all;
use work.host_types.all;


entity tb_receive_repack is
generic(runner_cfg: string);
end entity;

architecture arch of tb_receive_repack is
	signal clk: std_logic := '0';
	constant clk_per: natural := 2;

	signal start, done: boolean := false;
	signal length: integer := -1;

	signal i: pcie.fragment := pcie.default_fragment;
	signal i_vld, o_vld: std_logic := '0';
	signal i_req, o_req: std_logic := '1';
	signal o: qdword := (others => '0');
	signal o_keep: nibble := (others => '0');
begin

clk <= not clk after clk_per / 2 * 1 ns;
o_req <= '1';


main: process
begin
	test_runner_setup(runner, runner_cfg);
	while test_suite loop
	if run("test 'full' packet") then
		wait until rising_edge(clk);

		reset(i);
		length <= 8;
		set_rqst32_header(i, make_wr_rqst32(
			length => 8,
			chn_id => 3,
			address => (31 downto 0 => '-')
		));
		set_dw(i, 3, std_logic_vector(to_unsigned(0,32)));
		i_vld <= '1';
		start <= true;

		wait until rising_edge(clk);

		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(1,32)));
		set_dw(i, 1, std_logic_vector(to_unsigned(2,32)));
		set_dw(i, 2, std_logic_vector(to_unsigned(3,32)));
		set_dw(i, 3, std_logic_vector(to_unsigned(4,32)));

		wait until rising_edge(clk);

		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(5,32)));
		set_dw(i, 1, std_logic_vector(to_unsigned(6,32)));
		set_dw(i, 2, std_logic_vector(to_unsigned(7,32)));

		wait until rising_edge(clk);
		i_vld <= '0';

		wait until done;
	elsif run("test 'one dw over'") then
		wait until rising_edge(clk);

		reset(i);
		length <= 9;
		set_rqst32_header(i, make_wr_rqst32(
			length => 9,
			chn_id => 3,
			address => (31 downto 0 => '-')
		));
		set_dw(i, 3, std_logic_vector(to_unsigned(0,32)));
		i_vld <= '1';
		start <= true;

		wait until rising_edge(clk);

		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(1,32)));
		set_dw(i, 1, std_logic_vector(to_unsigned(2,32)));
		set_dw(i, 2, std_logic_vector(to_unsigned(3,32)));
		set_dw(i, 3, std_logic_vector(to_unsigned(4,32)));

		wait until rising_edge(clk);
		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(5,32)));
		set_dw(i, 1, std_logic_vector(to_unsigned(6,32)));
		set_dw(i, 2, std_logic_vector(to_unsigned(7,32)));
		set_dw(i, 3, std_logic_vector(to_unsigned(8,32)));

		wait until rising_edge(clk);
		i_vld <= '0';

		wait until done;

	elsif run("test 'two dw over'") then
		wait until rising_edge(clk);

		reset(i);
		length <= 10;
		set_rqst32_header(i, make_wr_rqst32(
			length => 10,
			chn_id => 3,
			address => (31 downto 0 => '-')
		));
		set_dw(i, 3, std_logic_vector(to_unsigned(0,32)));
		i_vld <= '1';
		start <= true;

		wait until rising_edge(clk);

		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(1,32)));
		set_dw(i, 1, std_logic_vector(to_unsigned(2,32)));
		set_dw(i, 2, std_logic_vector(to_unsigned(3,32)));
		set_dw(i, 3, std_logic_vector(to_unsigned(4,32)));

		wait until rising_edge(clk);
		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(5,32)));
		set_dw(i, 1, std_logic_vector(to_unsigned(6,32)));
		set_dw(i, 2, std_logic_vector(to_unsigned(7,32)));
		set_dw(i, 3, std_logic_vector(to_unsigned(8,32)));

		wait until rising_edge(clk);
		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(9,32)));

		wait until rising_edge(clk);
		i_vld <= '0';

		wait until done;

	elsif run("test 'three dw over'") then
		wait until rising_edge(clk);

		reset(i);
		length <= 11;
		set_rqst32_header(i, make_wr_rqst32(
			length => 10,
			chn_id => 3,
			address => (31 downto 0 => '-')
		));
		set_dw(i, 3, std_logic_vector(to_unsigned(0,32)));
		i_vld <= '1';
		start <= true;

		wait until rising_edge(clk);

		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(1,32)));
		set_dw(i, 1, std_logic_vector(to_unsigned(2,32)));
		set_dw(i, 2, std_logic_vector(to_unsigned(3,32)));
		set_dw(i, 3, std_logic_vector(to_unsigned(4,32)));

		wait until rising_edge(clk);
		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(5,32)));
		set_dw(i, 1, std_logic_vector(to_unsigned(6,32)));
		set_dw(i, 2, std_logic_vector(to_unsigned(7,32)));
		set_dw(i, 3, std_logic_vector(to_unsigned(8,32)));

		wait until rising_edge(clk);
		reset(i);
		set_dw(i, 0, std_logic_vector(to_unsigned(9,32)));
		set_dw(i, 1, std_logic_vector(to_unsigned(10,32)));

		wait until rising_edge(clk);
		i_vld <= '0';

		wait until done;

	end if;
	end loop;
	test_runner_cleanup(runner);
end process;
test_runner_watchdog(runner, 10 ms);

validate: process
	variable cnt: natural := 0;
	variable o_val: integer := -1;
begin
	wait until start;

	loop
		wait until rising_edge(clk) and o_vld = '1';
		check_relation(o_keep /= std_logic_vector'("0000"));
		info("Keep: " & to_string(o_keep));
		outer: for idx in 0 to 3 loop
				if o_keep(idx) then
					o_val := to_integer(unsigned(o((idx+1)*32-1 downto idx*32)));
					check_relation(o_val = cnt);
					info("Cnt: " & to_string(cnt) & ", Val: " & to_string(o_val));
					cnt := cnt + 1;
					if cnt = length - 1 then
						done <= true;
						wait until rising_edge(clk);
						exit outer;
					end if;
					exit outer when cnt = length - 1;
				end if;
		end loop;
	end loop;


end process;

check_req: process
begin
	loop
		wait until rising_edge(clk);
		check_equal(i_req, '1');
		exit when done;
	end loop;
end process;

uut: entity work.receiver_repack
port map(
	clk    => clk,
	i      => i,
	i_vld  => i_vld,
	i_req  => i_req,
	o      => o,
	o_keep => o_keep,
	o_vld  => o_vld,
	o_req  => o_req
);

end architecture arch;


