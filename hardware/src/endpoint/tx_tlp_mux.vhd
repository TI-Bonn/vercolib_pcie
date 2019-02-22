library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pcie.all;
use work.transceiver_128bit_types.all;

entity tx_tlp_mux is
	port(
		clk      : in std_logic;
		rst      : in std_logic;

		-- 1st prioritized input port "int"
		int_vld  : in  std_logic;
		int_req  : out std_logic := '1';
		int      : in  fragment;

		-- 2nd prioritized input port "cfg"
		cfg_vld  : in  std_logic;
		cfg_req  : out std_logic := '1';
		cfg      : in  fragment;

		-- 3rd prioritized input port "rx"
		rx_vld  : in  std_logic;
		rx_req  : out std_logic := '1';
		rx      : in  fragment;

		-- least prioritized input port "tx"
		tx_vld  : in  std_logic;
		tx_req  : out std_logic := '1';
		tx      : in  fragment;

		-- output port "o"
		o_vld   : out std_logic := '0';
		o_req   : in  std_logic;
		o       : out fragment
	);
end tx_tlp_mux;

architecture arch of tx_tlp_mux is
	
	constant prio_mwr : natural := 1;

	type state_t is (IDLE, TRANSFER_TX_PACKET);
	signal state : state_t := IDLE;
	signal tx_req_logic : std_logic;
	signal rx_req_logic : std_logic;
	signal int_req_logic : std_logic;
	signal cfg_req_logic : std_logic;
	
	signal tx_or_rx : natural range 0 to 15 := 0;

begin

int_req <= int_req_logic or not int_vld;
cfg_req <= cfg_req_logic or not cfg_vld;
rx_req  <=  rx_req_logic or not  rx_vld;
tx_req  <=  tx_req_logic or not  tx_vld;

int_req_logic <= '0' when state = TRANSFER_TX_PACKET else o_req;

cfg_req_logic <= '0' when int_vld = '1' or state = TRANSFER_TX_PACKET else o_req;

rx_req_logic  <= '1' when rx_vld = '1' and rx.sof = '1' and (get_type(rx) = MSIX_desc) else
				 '0' when    int_vld = '1'
				          or cfg_vld = '1'
				          or state = TRANSFER_TX_PACKET
				          or (tx_vld = '1' and tx.sof = '1' and get_type(tx) /= MSIX_desc and tx_or_rx /= 0)
				     else o_req;

tx_req_logic  <= '1' when tx_vld = '1' and tx.sof = '1' and (get_type(tx) = MSIX_desc) else
				 '0' when state = IDLE and (   int_vld = '1'
				 	                        or cfg_vld = '1'
				 	                        or (rx_vld = '1' and rx.sof = '1' and get_type(rx) /= MSIX_desc and tx_or_rx = 0))
				 	                   else o_req;

process
begin
	wait until rising_edge(clk) and o_req = '1';

	case state is
	when IDLE =>

		-- MWr and CplD from the MSIX_table module (interrupt handling) have the highest priority, always one word
		if int_vld = '1' then
			o_vld <= int_vld;
			o     <= int;

		-- CplD from config_channel module have the 2nd highest priority, always one word
		elsif cfg_vld = '1' then
			o_vld <= cfg_vld;
			o     <= cfg;

		-- MRd from Downstream Channel (DMA requests, always one word) have the 3rd highest priority
		elsif       rx_vld = '1' and  rx.sof = '1' and (rx.data(3 downto 0) /= MSIX_desc) 
		       and (tx_or_rx = 0 or tx_vld = '0' or get_type(tx) = MSIX_desc or tx.sof = '0') then
			o_vld  <= rx_vld;
			o      <= rx;
			
			tx_or_rx <= 1; --TODO

		-- MWr from Upstream Channel (DMA data transfers) have the least highest priority
		elsif  tx_vld = '1' and  tx.sof = '1' and ( tx.data(3 downto 0) /= MSIX_desc) then
			o_vld  <= tx_vld;
			o      <= tx;
			
			tx_or_rx <= tx_or_rx + 1; --TODO
			if tx_or_rx = prio_mwr then
				tx_or_rx <= 0;
			end if;

			if tx.eof = '0' then
				state  <= TRANSFER_TX_PACKET;
			end if;
		else
			o_vld  <= '0';
		end if;

	-- send the whole MWr packet before switching to the next available input
	when TRANSFER_TX_PACKET =>

		o_vld <= tx_vld;
		o     <= tx;

		if tx_vld = '1' and tx.eof = '1' then
			state <= IDLE;
		end if;

	end case;

	if rst = '1' then
		o_vld <= '0';
		o <= default_fragment;
		state <= IDLE;
	end if;
end process;

end architecture;
