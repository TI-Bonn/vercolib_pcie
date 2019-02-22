library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.host_channel_types.all;

entity rx_dma_interrupt_handler is
	generic (
		CHANNEL_ID: natural
	);
	port (
		clk : in std_logic;
		rst : in std_logic;
		
		-- signal to reset requester 
		-- in case of an interrupt this signal is active exactly for one clock cycle
		ctrl_rst : out std_logic := '0';

		-- input port from host_channel_decoder
		-- no req signal needed: never blocks input data stream:
		-- ensured by driver-FPGA protocol, otherwise its undefined behaviour
		instr_vld : in std_logic;
		instr     : in interrupt_instr_t;

		-- input ports for data stream to be observed, only length field in header is relevant.
		-- no req signal needed: never interferes with observed data stream.
		cpl_vld : in std_logic;
		cpl     : in fragment;

		-- output port "packer" to packer
		writer_vld     : out std_logic;
		writer_req     : in  std_logic;
		writer         : out tlp_header_info_t;
		writer_payload : out std_logic_vector(31 downto 0)
	);
end entity rx_dma_interrupt_handler;

architecture RTL of rx_dma_interrupt_handler is
	signal transfer_vld : std_logic;
	signal transfer_length : unsigned(9 downto 0);
	
begin
	
filter: entity work.rx_dma_interrupt_handler_filter
	port map(
		cpl_vld         => cpl_vld,
		cpl             => cpl,
		transfer_vld    => transfer_vld,
		transfer_length => transfer_length
	);
	
handler: entity work.dma_interrupt_handler
	generic map(CHANNEL_ID => CHANNEL_ID)
	port map(
		clk             => clk,
		rst             => rst,
		ctrl_rst        => ctrl_rst,
		instr_vld       => instr_vld,
		instr           => instr,
		transfer_vld    => transfer_vld,
		transfer_length => transfer_length,
		transfer_eot    => '0',
		transfer_eof    => '1',
		writer_vld      => writer_vld,
		writer_req      => writer_req,
		writer          => writer,
		writer_payload  => writer_payload
	);

end architecture RTL;
