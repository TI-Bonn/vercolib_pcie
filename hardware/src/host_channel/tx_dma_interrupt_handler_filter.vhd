library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.host_channel_types.all;

entity tx_dma_interrupt_handler_filter is
	port (
		clk : in std_logic;
		
		mwr_vld : in std_logic;
		mwr_req : in std_logic;
		mwr     : in fragment;
		mwr_eot : in std_logic;

		transfer_vld    : out std_logic;
		transfer_length : out unsigned(9 downto 0);
		transfer_eof    : out std_logic;
		transfer_eot    : out std_logic
	);
end entity tx_dma_interrupt_handler_filter;

architecture RTL of tx_dma_interrupt_handler_filter is
	signal dword0 : common_dw0;
begin
dword0 <= to_common_dw0(get_dword(mwr, 0));

filter: process
begin
	wait until rising_edge(clk);
	-- registered for optimization
	transfer_vld    <= (mwr_vld and mwr_req and mwr.sof) when dword0.desc = MWr32_desc or dword0.desc = MWr64_desc else '0';
	transfer_eof    <= mwr_vld and mwr_req and mwr.eof;
	transfer_length <= unsigned(dword0.length);
	transfer_eot    <= mwr_eot;
end process;
end architecture RTL;
