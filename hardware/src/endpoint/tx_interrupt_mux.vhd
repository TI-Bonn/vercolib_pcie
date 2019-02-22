library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pcie.all;
use work.transceiver_128bit_types.all;

entity tx_interrupt_mux is
	port(
		clk    : in std_logic;
		rst    : in std_logic;

		-- host_rx_channel interrupt input port
 		host_rx_vld : in  std_logic;
		host_rx_req : out std_logic := '1';
		host_rx     : in  fragment;

		-- host_tx_channel interrupt input port
		host_tx_vld : in  std_logic;
		host_tx_req : out std_logic := '1' ;
		host_tx     : in  fragment;

		-- output port "o"
		o_vld  : out std_logic := '0';
		o_req  : in  std_logic;
		o      : out fragment := default_fragment
	);
end tx_interrupt_mux;

architecture arch of tx_interrupt_mux is

	type state_t is (PRIORITY_RX, PRIORITY_TX);
	signal state : state_t := PRIORITY_RX;

begin

	host_rx_req <= '1' when host_rx.sof = '0' or host_rx_vld = '0' or get_type(host_rx) /= MSIX_desc else
			 '0' when state = PRIORITY_TX and host_tx.sof = '1' and host_tx_vld = '1' and get_type(host_tx) = MSIX_desc else o_req;

	host_tx_req <= '1' when host_tx.sof = '0' or host_tx_vld = '0' or get_type(host_tx) /= MSIX_desc else
			 '0' when state = PRIORITY_RX and host_rx.sof = '1' and host_rx_vld = '1' and get_type(host_rx) = MSIX_desc else o_req;

	process(clk)
	begin
		if rising_edge(clk) then

			if o_req = '1' then

				case state is

				when PRIORITY_RX =>

					if host_rx.sof = '1' and (host_rx.data(3 downto 0) = MSIX_desc) and host_rx_vld = '1' then
						o_vld  <= '1';
						o      <= host_rx;
						state  <= PRIORITY_TX;
					elsif host_tx.sof = '1' and (host_tx.data(3 downto 0) = MSIX_desc) and host_tx_vld = '1' then
						o_vld  <= '1';
						o      <= host_tx;
					else
						o_vld  <= '0';
					end if;

				when PRIORITY_TX =>

					if host_tx.sof = '1' and host_tx.data(3 downto 0) = MSIX_desc and host_tx_vld = '1' then
						o_vld  <= host_tx_vld;
						o      <= host_tx;
						state  <= PRIORITY_RX;
					elsif host_rx.sof = '1' and host_rx.data(3 downto 0) = MSIX_desc and host_rx_vld = '1' then
						o_vld  <= host_rx_vld;
						o      <= host_rx;
					else
						o_vld  <= '0';
					end if;

				end case;

			end if;

			if rst = '1' then
				o_vld <= '0';
				o <= default_fragment;
				state <= PRIORITY_RX;
			end if;

		end if;
	end process;

end architecture;

