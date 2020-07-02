library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.host_types.all;
use work.pcie.all;
use work.host_channel_types.all;
use work.utils.all;

entity tx_dma_writer is
	generic(
		debug        : boolean;
		CHANNEL_ID   : natural
	);
	port (
		clk : in std_logic;
		rst : in std_logic;

		-- input port for interrupt handler
		int_vld     : in  std_logic;
		int_req     : out std_logic;
		int         : in  tlp_header_info_t;
		int_payload : in  dword;

		-- input port for DMA transfers (MRd in DOWNSTREAM, MWr in UPSTREAM)
		transfer_vld : in  std_logic;
		transfer_req : out std_logic;
		transfer     : in  tlp_header_info_t;

		-- input from payload fifo
		payload_vld : in  std_logic;
		payload_req : out std_logic;
		payload     : in  tx_stream;
		payload_cnt : in  unsigned(11 downto 0);
		payload_eot : in  std_logic := '0';

		o     : out fragment := default_fragment;
		o_eot : out std_logic;
		o_vld : out std_logic := '0';
		o_req : in  std_logic
	);
end entity tx_dma_writer;

architecture RTL of tx_dma_writer is
	signal buf_vld : std_logic;
	signal buf_req : unsigned(2 downto 0);
	signal buf : tx_stream;
	signal buf_cnt : unsigned(11 downto 0);
	signal buf_eot : std_logic;

begin

writer_packer: entity work.dma_writer_packer
	generic map(
		debug        => debug,
		CHANNEL_ID   => CHANNEL_ID,
		TRANSFER_DIR => "UPSTREAM"
	)
	port map(
		clk         => clk,
		rst         => rst,
		i_vld       => int_vld,
		i_req       => int_req,
		i           => int,
		i_payload   => int_payload,
		mwr_vld     => transfer_vld,
		mwr_req     => transfer_req,
		mwr         => transfer,
		payload_vld => buf_vld,
		payload_req => buf_req,
		payload     => buf,
		payload_cnt => buf_cnt,
		payload_eot => buf_eot,
		o           => o,
		o_eot       => o_eot,
		o_vld       => o_vld,
		o_req       => o_req
	);

writer_buffer: entity work.writer_buffer
	generic map(
		debug      => debug
	)
	port map(
		clk        => clk,
		rst        => '0',
		i_vld      => payload_vld,
		i_req      => payload_req,
		i          => payload,
		fifo_eot   => payload_eot,
		fifo_count => payload_cnt,
		o_vld      => buf_vld,
		o_req      => buf_req,
		o          => buf,
		eot        => buf_eot,
		count      => buf_cnt
	);

end architecture RTL;
