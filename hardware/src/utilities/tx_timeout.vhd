-- Force end_of_stream tags for tx_streams a given number of cycles after the
-- last valid word.
-- Author: Sebastian Schüller <schueller@ti.uni-bonn.de>


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.ceil;
use ieee.math_real.log2;

library vercolib;
use vercolib.pcie;


entity tx_stream_timeout is
generic(timeout: natural);
port(
	clk: in std_ulogic;

	i: in pcie.tx_stream;
	i_vld: in std_ulogic;
	i_req: out std_ulogic := '0';

	o: out pcie.tx_stream := pcie.default_tx_stream;
	o_vld: out std_ulogic := '0';
	o_req: in std_ulogic);
end entity;

architecture impl of tx_stream_timeout is
	signal counter: natural := 0;
	signal buffered: pcie.tx_stream := pcie.default_tx_stream;
	signal buffered_vld: std_ulogic := '0';
	signal timeout_triggered, eos_buffered: std_ulogic := '0';
begin

timer: process
begin
	wait until rising_edge(clk);
	if ((not i_vld) and buffered_vld and o_req) = '1' then
		counter <= counter + 1;
	else
		counter <= 0;
	end if;
end process;

timeout_triggered <= '1' when counter >= timeout else '0';
eos_buffered <= buffered_vld and buffered.end_of_stream;
i_req <= o_req or not i_vld;

output: process
begin
	wait until rising_edge(clk);
	if o_req = '1' then
		o_vld <= '0';
		if i_vld = '1' then
			buffered_vld <= '1';
			buffered <= i;
			if buffered_vld = '1' then
				o_vld <= buffered_vld;
				o <= buffered;
			end if;
		else
			if (eos_buffered or timeout_triggered) = '1' then
				o_vld <= buffered_vld;
				buffered_vld <= '0';
				o <= buffered;
				o.end_of_stream <= '1';
			end if;
		end if;
	end if;
end process;

end architecture;
