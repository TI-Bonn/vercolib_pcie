-- Public package for transceiver utilites
-- Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;

use work.pcie;

package pcie_utilities is

	--! Set the 'end_of_stream' tag after a generic timeout

	--! This module can be used in front of all tx-channels, if
	--! the user application doesn't mark the last valid output.
	--! It can also be used to control the maximum latency until
	--! output data of the user application takes until it reaches
	--! the host system.
	--! The latest input is held internally for up to `timeout`
	--! cycles if no new valid input is presented.
	--! After this time the held word is presented at the output,
	--! marked as the last word of the stream.
	--! If new valid input is presented in the time it taken it
	--! it presents the held word without changing it at all.
	component tx_stream_timeout
	generic(timeout: natural);
	port(
		clk: in std_ulogic;

		i: in pcie.tx_stream;
		i_vld: in std_ulogic;
		i_req: out std_ulogic := '0';

		o: out pcie.tx_stream := pcie.default_tx_stream;
		o_vld: out std_ulogic := '0';
		o_req: in std_ulogic);
	end component;
end package;
