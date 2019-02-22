library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.host_types.all;
use work.transceiver_128bit_types.all;
use work.host_channel_types.all;
use work.utils.all;

entity rx_dma_writer_arbiter is
	port (
		-- input port for interrupt handler
		int_vld     : in  std_logic;
		int_req     : out std_logic;
		int         : in  tlp_header_info_t;
		int_payload : in  dword;
		
		-- input port for requester
		transfer_vld : in  std_logic;
		transfer_req : out std_logic;
		transfer     : in  tlp_header_info_t;
		
		o_vld     : out std_logic := '0';
		o_req     : in  std_logic;
		o         : out tlp_header_info_t;
		o_payload : out dword
	);
end entity rx_dma_writer_arbiter;

architecture RTL of rx_dma_writer_arbiter is
	
begin

-- packets for host driver communication (interrupts and BAR reads) should be handled with highest priority
int_req       <=  o_req;
transfer_req  <= '0' when int_vld = '1' else o_req;
	
o_payload <= int_payload;

o_vld <= int_vld or transfer_vld;
	
o <= int when int_vld = '1' else transfer;

end architecture RTL;
