library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.host_channel_types.all;

entity rx_dma_interrupt_handler_filter is
	port (
		cpl_vld  : in std_logic;
		cpl      : in fragment;
		
		transfer_vld    : out std_logic;
		transfer_length : out unsigned(9 downto 0)
	);
end entity rx_dma_interrupt_handler_filter;

architecture RTL of rx_dma_interrupt_handler_filter is
	
begin
	transfer_vld    <= cpl_vld and cpl.sof;
	transfer_length <= unsigned(to_common_dw0(get_dword(cpl, 0)).length);
end architecture RTL;
