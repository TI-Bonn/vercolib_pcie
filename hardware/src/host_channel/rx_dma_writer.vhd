library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.host_types.all;
use work.transceiver_128bit_types.all;
use work.pcie.all;
use work.host_channel_types.all;
use work.utils.all;

entity rx_dma_writer is
	generic(
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
		
		-- input port for requester
		transfer_vld : in  std_logic;
		transfer_req : out std_logic;
		transfer     : in  tlp_header_info_t;
		
		o     : out fragment := default_fragment;
		o_vld : out std_logic := '0';
		o_req : in  std_logic
	);
end entity rx_dma_writer;

architecture RTL of rx_dma_writer is

	signal arb_payload : dword;
	signal arb : tlp_header_info_t;
	signal arb_req : std_logic;
	signal arb_vld : std_logic;

begin
	
writer_arbiter: entity work.rx_dma_writer_arbiter
	port map(
		int_vld      => int_vld,
		int_req      => int_req,
		int          => int,
		int_payload  => int_payload,
		transfer_vld => transfer_vld,
		transfer_req => transfer_req,
		transfer     => transfer,
		o_vld        => arb_vld,
		o_req        => arb_req,
		o            => arb,
		o_payload    => arb_payload
	);
	
writer_packer: entity work.dma_writer_packer
	generic map(
		CHANNEL_ID   => CHANNEL_ID,
		TRANSFER_DIR => "DOWNSTREAM"
	)
	port map(
		clk         => clk,
		rst         => rst,
		i_vld       => arb_vld,
		i_req       => arb_req,
		i           => arb,
		i_payload   => arb_payload,
		mwr_vld     => '0',
		mwr_req     => open,
		mwr         => init_tlp_header_info,
		payload_vld => '0',
		payload_req => open,
		payload     => default_tx_stream,
		payload_cnt => (others => '0'),
		payload_eot => '0',
		o           => o,
		o_eot       => open,
		o_vld       => o_vld,
		o_req       => o_req
	);

end architecture RTL;
