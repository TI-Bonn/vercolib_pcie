
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie;

use work.transceiver_128bit_types.all;
use work.dbg_types.all;

entity dbg_controller is
port(
	clk     : in std_logic;
	rst     : in std_logic;
	
	from_ep_vld  : in  std_logic;
	from_ep_req  : out std_logic := '0';
	from_ep      : in  pcie.fragment;
	
	clock_counter    : out unsigned(47 downto 0);
	
	dbg_command      : out dbg_command_t
);
end entity;

architecture arch of dbg_controller is
	signal payload : unsigned(31 downto 0);
	signal to_dbg_channel_id : unsigned(3 downto 0);
	signal to_dbg_command : unsigned(3 downto 0);
	signal to_dbg_param : unsigned(23 downto 0);
	
	signal run : boolean := false;
	
begin

from_ep_req <= '1';

payload <= unsigned(get_dword(from_ep, 3));

to_dbg_channel_id <= payload(3 downto 0);
to_dbg_command    <= payload(7 downto 4);
to_dbg_param      <= payload(31 downto 8);

test_state : process
begin
	wait until rising_edge(clk);
	dbg_command <= (0, 0, to_unsigned(0, 24));
	
	if from_ep.sof = '1' and get_rqst32(from_ep.data).dw0.chn_id = x"1F" and from_ep_vld = '1' then
		dbg_command.channel_id  <= to_integer(to_dbg_channel_id);
		dbg_command.command     <= to_integer(to_dbg_command);
		dbg_command.param       <= to_dbg_param;
	end if;
	
	if dbg_command.command = set_start then
		run <= true;
	end if;
	
	if run then
		clock_counter <= clock_counter + 1;
	end if;
	
	if rst then
		clock_counter <= (others => '0');
		run <= false;
	end if;
end process;


	
end architecture arch;
