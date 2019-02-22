-- Channel Type definitions that hold for all kinds of channels.
-- Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.host_types.dword;

package channel_types is
	constant host_channel_kind: std_logic_vector(3 downto 0) := x"0";
	constant fpga_channel_kind: std_logic_vector(3 downto 0) := x"1";

	type channel_info_t is record
		id: unsigned(7 downto 0);
		kind: std_logic_vector(3 downto 0);
	end record;

	function new_host_channel_info(id: natural range 0 to 2**8) return channel_info_t;
	function new_fpga_channel_info(id: natural range 0 to 2**8) return channel_info_t;

	function to_dw(info: channel_info_t) return dword;
end package;


package body channel_types is
	function new_host_channel_info(id: natural range 0 to 2**8) return channel_info_t is
	begin
		return channel_info_t'(
			id => to_unsigned(id, 8),
			kind => host_channel_kind
		);
	end new_host_channel_info;

	function new_fpga_channel_info(id: natural range 0 to 2**8) return channel_info_t is
	begin
		return channel_info_t'(
			id => to_unsigned(id, 8),
			kind => fpga_channel_kind
		);
	end new_fpga_channel_info;

	function to_dw(info: channel_info_t) return dword is
	begin
		return dword'(
			 7 downto 0 => std_logic_vector(info.id),
			11 downto 8 => info.kind,
			others      => '0'
		);
	end to_dw;
end package body;
