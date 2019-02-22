
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.pcie;
use work.dbg_types.all;

entity dbg_rx_channel_evaluator is
generic(
	channel_id   : natural range 0 to 31
);
port(
	clk     : in std_logic;
	rst     : in std_logic;
	
	dbg_from_rx_vld  : in  std_logic;
	dbg_from_rx_req  : out std_logic := '0';
	dbg_from_rx      : in pcie.rx_stream;

	dbg_to_tx_vld    : out std_logic := '0';
	dbg_to_tx_req    : in std_logic := '0';
	dbg_to_tx        : out pcie.tx_stream := pcie.default_tx_stream;
	
	dbg_command      : in dbg_command_t;
	dbg_state        : out dbg_rx_state_t;
	dbg_config       : out dbg_config_t
);
end entity;

architecture arch of dbg_rx_channel_evaluator is
	signal data_delay : unsigned(7 downto 0) := (others => '0');
	signal delay_clock_counter : unsigned(7 downto 0) := (others => '0');
	signal sequence_counter : unsigned(31 downto 0) := (others => '0');
	signal run : boolean := false;
	signal run_latency : boolean := false;
	signal received_rx : boolean := false;

begin
	
show_config : process
begin
	wait until rising_edge(clk);
	dbg_config <= ((others => '0'), false);
	case dbg_command.command is
	when get_data_delay =>
		dbg_config.param(7 downto 0) <= data_delay;
		dbg_config.valid <= true;
	when get_latency_mode =>
		dbg_config.param(0) <= '1' when run_latency else '0';
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
	end if;
	
	if rst = '1' then
		data_delay <= (others => '0');
		run <= false;
	end if;
end process;

req_logic: process
begin
	wait until rising_edge(clk);
	if not run_latency then
		dbg_from_rx_req <= '0';
	end if;

	if run then
		delay_clock_counter <= delay_clock_counter + 1;
		if delay_clock_counter = data_delay then
			dbg_from_rx_req <= '1';
			delay_clock_counter <= (others => '0');
		end if;
	end if;

	if dbg_command.command = set_latency_mode then
		dbg_from_rx_req <= '1';
	end if;

	if rst = '1' then
		dbg_from_rx_req <= '0';
		delay_clock_counter <= (others => '0');
	end if;
end process;

latency_test: process
begin
	wait until rising_edge(clk);
	if dbg_command.command = set_latency_mode and channel_id = dbg_command.channel_id then
		run_latency <= true;
	end if;
	
	if run_latency and dbg_from_rx_vld = '1' then
		received_rx <= true;
		run_latency <= false; 
	end if;
	
	dbg_to_tx_vld <= '0';
	if dbg_to_tx_req = '1' and received_rx then
		dbg_to_tx_vld     <= '1';
		dbg_to_tx.payload <= dbg_from_rx.payload;
		dbg_to_tx.cnt     <= "100";     -- TODO change this to dbg_from_rx.cnt
		dbg_to_tx.end_of_stream <= '1';
		received_rx <= false;
	end if;
	
	if rst = '1' then
		run_latency <= false;
		received_rx <= false;
		dbg_to_tx_vld <= '0';
		dbg_to_tx <= pcie.default_tx_stream;
	end if;
end process;

count_data: process
begin
	wait until rising_edge(clk);
	if dbg_from_rx_vld = '1' then
		dbg_state.rx_data_count <= dbg_state.rx_data_count + 1;
	end if;
	
	if rst then
		dbg_state.rx_data_count <= (others => '0');
	end if;
end process;

check_sequence: process
begin
	wait until rising_edge(clk);
	dbg_state.rx_sequence_err <= false;
	
	if dbg_from_rx_vld = '1' then
		
		-- check if sequence is correct
		if 	unsigned(dbg_from_rx.payload( 31 downto  0)) /= sequence_counter   or
			unsigned(dbg_from_rx.payload( 63 downto 32)) /= sequence_counter+1 or
			unsigned(dbg_from_rx.payload( 95 downto 64)) /= sequence_counter+2 or
			unsigned(dbg_from_rx.payload(127 downto 96)) /= sequence_counter+3 then
			
			dbg_state.rx_sequence_err <= true;
		end if;
		
		sequence_counter <= sequence_counter + 4;
		
		-- heal sequence after error, to detect the next one
		if dbg_state.rx_sequence_err then
			sequence_counter <= unsigned(dbg_from_rx.payload(31 downto 0)) + 4;
			dbg_state.rx_sequence_err <= false;
		end if;
	end if;
	
	if rst = '1' then
		dbg_state.rx_sequence_err <= false;
		sequence_counter <= (others => '0');
	end if;
end process;

dbg_state.rx_sequence_cnt <= sequence_counter;
	
end architecture arch;
