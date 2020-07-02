-- Channel Type definitions that hold for all kinds of channels.
-- Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.host_types.dword;

package channel_types is
	type channel_info_kind is (channel_kind_host, channel_kind_fpga);
	type channel_info_dir is (channel_dir_rx, channel_dir_tx, channel_dir_bi, channel_dir_none);

	type channel_info_t is record
		id: unsigned(7 downto 0);
		dir: channel_info_dir;
		kind: channel_info_kind;
	end record;

	function new_host_channel_info(id: natural range 0 to 2**8; dir: channel_info_dir)
		return channel_info_t;
	function new_fpga_channel_info(id: natural range 0 to 2**8; dir: channel_info_dir)
		return channel_info_t;

	function slv(kind: channel_info_kind) return std_logic_vector;
	function slv(dir: channel_info_dir) return std_logic_vector;

	function from_string(str: string) return channel_info_dir;

	function to_dw(info: channel_info_t) return dword;
end package;


package body channel_types is
	function new_host_channel_info(id: natural range 0 to 2**8; dir: channel_info_dir)
	return channel_info_t is
	begin
		return channel_info_t'(
			id => to_unsigned(id, 8),
			dir => dir,
			kind => channel_kind_host
		);
	end new_host_channel_info;

	function new_fpga_channel_info(id: natural range 0 to 2**8; dir: channel_info_dir)
	return channel_info_t is
	begin
		return channel_info_t'(
			id => to_unsigned(id, 8),
			dir => dir,
			kind => channel_kind_fpga
		);
	end new_fpga_channel_info;

	function slv(kind: channel_info_kind) return std_logic_vector is
		variable ret: std_logic_vector(3 downto 0);
	begin
		case kind is
		when channel_kind_host => ret :=  x"0";
		when channel_kind_fpga => ret :=  x"1";
		when others =>            ret :=  x"F";
		end case;
		return ret;
	end;

	function slv(dir: channel_info_dir) return std_logic_vector is
		variable ret: std_logic_vector(1 downto 0);
	begin
		case dir is
		when channel_dir_rx =>   ret :=  b"00";
		when channel_dir_tx =>   ret :=  b"01";
		when channel_dir_bi =>   ret :=  b"10";
		when channel_dir_none => ret :=  b"11";
		end case;
		return ret;
	end;

	function from_string(str: string) return channel_info_dir is
	begin
		case str(1 to 2) is
		when "rx" => return channel_dir_rx;
		when "tx" => return channel_dir_tx;
		when "bi" => return channel_dir_bi;
		when "no" => return channel_dir_none;
		when others => 
			assert false
				report "Channel direction string :" & str & " is invalid"
				severity failure;
			return channel_dir_none;
		end case;
	end;

	function to_dw(info: channel_info_t) return dword is
	begin
		return dword'(
			 7 downto  0 => std_logic_vector(info.id),
			 9 downto  8 => slv(info.dir),
			13 downto 10 => slv(info.kind),
			others      => '0'
		);
	end to_dw;
end package body;
