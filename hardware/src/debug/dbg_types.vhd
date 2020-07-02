-- Author: Oguzhan Sezenlik

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package dbg_types is
	subtype counter_width_t is unsigned(23 downto 0);

	procedure increment_cnt (
		signal reset   : std_logic;
		signal counter : inout counter_width_t;
		signal valid   : in boolean;
		signal size    : in natural
	);

	procedure increment_cnt (
		signal reset   : std_logic;
		signal counter : inout counter_width_t;
		signal valid   : in boolean
	);

	constant set_stream_size : natural := 1;
	constant set_data_delay : natural := 2;
	constant set_latency_mode : natural := 3;
	constant set_start : natural := 7;

	constant get_stream_size : natural := 8+set_stream_size;
	constant get_data_delay : natural := 8+set_data_delay;
	constant get_latency_mode : natural := 8+set_latency_mode;
	constant get_start : natural := 8+set_start;

	type dbg_command_t is record
		channel_id : natural range 0 to 15;
		command    : natural range 0 to 15;
		param      : unsigned(23 downto 0);
	end record;

	type dbg_config_t is record
		param : unsigned(31 downto 0);
		valid : boolean;
	end record;
	type dbg_config_vec_t is array (natural range <>) of dbg_config_t;

	type dbg_rx_state_t is record
		rx_sequence_err : boolean;
		rx_sequence_cnt : unsigned(31 downto 0);
		rx_data_count   : unsigned(47 downto 0);
	end record;
	type dbg_rx_state_vec_t is array (natural range <>) of dbg_rx_state_t;

	type channel_type is (FPGA, HOST);

end package dbg_types;

package body dbg_types is

	procedure increment_cnt (
		signal reset   : std_logic;
		signal counter : inout counter_width_t;
		signal valid   : in boolean;
		signal size    : in natural
	) is
	begin
		if valid  then
			counter <= counter + size;
		end if;
		if reset then
			counter <= (others => '0');
		end if;
	end;

	procedure increment_cnt (
		signal reset   : std_logic;
		signal counter : inout counter_width_t;
		signal valid   : in boolean
	) is
	begin
		if valid  then
			counter <= counter + 1;
		end if;
		if reset then
			counter <= (others => '0');
		end if;
	end;

end package body dbg_types;
