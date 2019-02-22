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
	constant timer_bits: natural := natural(ceil(log2(real(timeout))));
	signal count: unsigned(timer_bits - 1 downto 0) := (others => '0');
	signal timer_fired: std_ulogic := '0';

	signal stored_req: std_ulogic := '0';
	signal stored_word: pcie.tx_stream := pcie.default_tx_stream;
	signal stored_vld: std_ulogic := '0';

	signal update_output: std_ulogic := '0';
begin

i_req <= stored_req or not i_vld;
stored_req <= (o_req and update_output) or not stored_vld;

timer: process
begin
	wait until rising_edge(clk);

	if o_req and stored_vld and (not i_vld) then
		count <= count + 1;
	end if;

	if o_req and i_vld then
		count <= (count'range => '0');
	end if;
end process;
timer_fired <= '1' when (count = to_unsigned(timeout, timer_bits)) else '0';


hold: process
begin
	wait until rising_edge(clk);

	if stored_req then
		stored_word <= i;
		stored_vld <= i_vld;
	end if;
end process;

update_output <= (i_vld) or
                 (timer_fired) or
                 (stored_word.end_of_stream and stored_vld);
output: process
begin
	wait until rising_edge(clk);

	if o_req then

		o_vld <= '0';

		if update_output then
			o <= stored_word;
			o.end_of_stream <= o.end_of_stream or timer_fired;
			o_vld <= stored_vld;
		end if;

	end if;
end process;


end architecture;
