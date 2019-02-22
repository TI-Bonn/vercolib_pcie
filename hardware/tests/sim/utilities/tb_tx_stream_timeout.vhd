-- Testbench for timeout generator
-- Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vercolib;
use vercolib.pcie;

library vunit_lib;
context vunit_lib.vunit_context;
use vunit_lib.queue_pkg.all;

entity tb_tx_stream_timeout is
generic(runner_cfg: string; timeout: natural := 5);
end entity;


architecture tb of tb_tx_stream_timeout is
	constant clkperiod: time := 2 ns;
	signal clk: std_ulogic := '0';

	procedure Step is
	begin
		wait for 0 ns;
	end procedure;


	signal i,o: pcie.tx_stream := pcie.default_tx_stream;
	signal i_vld, i_req, o_vld, o_req: std_ulogic := '0';

	signal stim_data: queue_t := new_queue;
	signal stim_delay: queue_t := new_queue;

	signal val_data: queue_t := new_queue;

	signal delay_duty_cycle: natural := 0; -- in ticks
	signal delay_phase_shift: natural := 0;
	signal delay_period_length: natural := 0;

	signal start_stim, start_validate: boolean := false;
	signal sim_done: boolean := false;
begin

clk <= not clk after clkperiod / 2;

ctrl: process
begin
	test_runner_setup(runner, runner_cfg);
	while test_suite loop

	if run("Test single word") then
		push(stim_data, 1);
		push(stim_delay, 0);
		Step;
	elsif run("Test uninterrupted packet") then
		for i in 1 to 100 loop
			push(stim_data, i);
			push(stim_delay, 0);
		end loop;
	elsif run("Test interrupted packet") then
		for i in 1 to 100 loop
			push(stim_data, i);
			if i mod 4 = 0 then
				push(stim_delay, 3);
			else
				push(stim_delay, 0);
			end if;
		end loop;
	elsif run("Test stalled packet") then
		delay_period_length <= 20;
		delay_phase_shift <= 7;
		delay_duty_cycle <= 3;
		for i in 1 to 100 loop
			push(stim_data, i);
			push(stim_delay, 0);
		end loop;
	elsif run("Test stalled interrupted packet") then
		delay_period_length <= 10;
		delay_phase_shift <= 7;
		delay_duty_cycle <= 5;
		for i in 1 to 100 loop
			push(stim_data, i);
			if i mod 2 = 0 then
				push(stim_delay, 3);
			else
				push(stim_delay, 0);
			end if;
		end loop;
	end if;
	
	start_stim <= true;
	start_validate <= true;
	Step;
	start_stim <= false;
	start_validate <= false;
	wait until sim_done;

	end loop;
	test_runner_cleanup(runner);
end process;
test_runner_watchdog(runner, 1000 * clkperiod);

stim: process
	variable current_data: integer := 0;
	variable current_delay: integer := 0;
begin
	wait until start_stim;
	loop
	exit when is_empty(stim_data);

	current_data := pop(stim_data);
	current_delay := pop(stim_delay);

	while current_delay > 0 loop
		wait until rising_edge(clk);
		if i_req then
			i_vld <= '0';
			current_delay := current_delay - 1;
		end if;
	end loop;
	
	if not i_req then
		wait until i_req = '1';
		wait until rising_edge(clk);
	end if;

	push(val_data, current_data);
	i_vld <= '1';
	i <= pcie.tx_stream'(
		payload => std_ulogic_vector(to_unsigned(current_data, 128)),
		cnt => to_unsigned(4, 3),
		end_of_stream => '0'
	);

	wait until rising_edge(clk);
	if not i_req then
		wait until i_req = '1';
		wait until rising_edge(clk);
	end if;
	i_vld <= '0';

	end loop;
	wait until sim_done;
end process;

validate: process
	variable delay_counter: natural := 0;
	variable delay_cycles: natural := 0;

	variable validate_value: integer := 0;
begin
	o_req <= '0';

	wait until start_validate;

	loop
	delay_counter := delay_counter + 1;
	if delay_counter = delay_period_length then
		delay_counter := 0;
	end if;
	if delay_counter = delay_phase_shift then
		delay_cycles := delay_duty_cycle;
	end if;

	if delay_cycles > 0 then
		delay_cycles := delay_cycles - 1;
		if o_req and not o_vld then
			wait until o_vld = '1';
		end if;
		o_req <= '0';
		wait until rising_edge(clk);
		next;

	end if;
	o_req <= '1';
	wait until rising_edge(clk);

	if o_vld then
		validate_value := to_integer(resize(unsigned(o.payload), 32));
		check_equal(validate_value, pop_integer(val_data));
		if is_empty(val_data) then
			check_equal(o.end_of_stream, '1');
			wait until rising_edge(clk);
			check_equal(o_vld, '0');
			exit;
		end if;
	end if;

	end loop;

	sim_done <= true;
	Step;
end process;

uut: entity vercolib.tx_stream_timeout
generic map(timeout => timeout)
port map(
	clk   => clk,
	i     => i,
	i_vld => i_vld,
	i_req => i_req,
	o     => o,
	o_vld => o_vld,
	o_req => o_req
);

end architecture;
