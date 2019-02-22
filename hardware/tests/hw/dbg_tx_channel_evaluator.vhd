
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.pcie;
use work.dbg_types.all;

entity dbg_tx_channel_evaluator is
generic(channel_id : natural range 0 to 31);
port(
	clk     : in std_logic;
	rst     : in std_logic;
	
	dbg_from_rx_vld    : in std_logic := '0';
	dbg_from_rx_req    : out std_logic := '0';
	dbg_from_rx        : in pcie.tx_stream;
	
	dbg_to_tx_vld  : out  std_logic;
	dbg_to_tx_req  : in std_logic;
	dbg_to_tx      : out pcie.tx_stream;
	
	dbg_command    : in dbg_command_t;
	dbg_config     : out dbg_config_t
);
end entity;

architecture arch of dbg_tx_channel_evaluator is
	signal data_delay : unsigned(7 downto 0) := (others => '0');
	signal delay_clock_counter : unsigned(7 downto 0) := (others => '0');
	signal sequence_counter : unsigned(31 downto 0) := (others => '0');
	signal run, set_eos_tag : boolean := false;
	signal stream_size : unsigned(23 downto 0) := (others => '0');
	signal stream_counter : unsigned(35 downto 0) := (others => '0');

begin
	
show_config : process
begin
	wait until rising_edge(clk);
	dbg_config <= ((others => '0'), false);
	case dbg_command.command is
	when get_data_delay =>
		dbg_config.param(7 downto 0) <= data_delay;
		dbg_config.valid <= true;
	when get_stream_size =>
		dbg_config.param(23 downto 0) <= stream_size;
		dbg_config.valid <= true;
	when get_start =>
		dbg_config.param(0) <= '1' when run else '0';
		dbg_config.valid <= true;
	when others => null;
	end case;
end process;
	
get_test_param: process
begin
	wait until rising_edge(clk);
	if channel_id = dbg_command.channel_id or dbg_command.channel_id = 15 then
		if dbg_command.command = set_start then
			run <= true;
		end if;
		if dbg_command.command = set_data_delay then
			data_delay <= dbg_command.param(7 downto 0);
		end if;
		if dbg_command.command = set_stream_size then
			stream_size <= dbg_command.param;
			set_eos_tag <= true;
		end if;
	end if;
	
	if rst = '1' then
		data_delay <= (others => '0');
		run <= false;
		set_eos_tag <= false;
	end if;
end process;

send_sequence: process
begin
	wait until rising_edge(clk);
	if dbg_to_tx_req = '1' then
		dbg_to_tx_vld <= '0';
	end if;
	
	if run then
		delay_clock_counter <= delay_clock_counter + 1;
		if delay_clock_counter = data_delay then
			delay_clock_counter <= (others => '0');
		end if;
		
		if dbg_to_tx_req = '1' and delay_clock_counter = data_delay then
			dbg_to_tx.payload <= std_logic_vector(sequence_counter+3) &
								 std_logic_vector(sequence_counter+2) &
								 std_logic_vector(sequence_counter+1) &
								 std_logic_vector(sequence_counter);
								 
			sequence_counter <= sequence_counter + 4;
	
			dbg_to_tx.cnt <= "100";
			dbg_to_tx_vld <= '1';

			stream_counter <= stream_counter + 16;
			
			dbg_to_tx.end_of_stream <= '0';
			if stream_counter(35 downto 12) = stream_size then  -- stream_size is a multiple of 4kb
				dbg_to_tx.end_of_stream <= '1' when set_eos_tag else '0';
				stream_counter <= (others => '0');
			end if;
		end if;
	end if;
	if dbg_command.command = set_latency_mode and channel_id = dbg_command.channel_id then
		dbg_from_rx_req <= '1';
	end if;
	
	if dbg_to_tx_req = '1' and dbg_from_rx_vld = '1' then
		dbg_to_tx <= dbg_from_rx;
		dbg_to_tx_vld <= '1';
		dbg_from_rx_req <= '0';
	end if;
	
	if rst = '1' then
		dbg_to_tx <= pcie.default_tx_stream;
		sequence_counter <= (others => '0');
		stream_counter <= (others => '0');
		dbg_to_tx_vld <= '0';
	end if;
end process;

	
end architecture arch;
