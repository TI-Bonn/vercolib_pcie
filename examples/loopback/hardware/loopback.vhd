library ieee;
use ieee.std_logic_1164.all;

library vercolib;
use vercolib.pcie;
use vercolib.pcie_utilities;

entity loopback is
port(
	pci_exp_txp: out std_logic_vector(7 downto 0);
	pci_exp_txn: out std_logic_vector(7 downto 0);
	pci_exp_rxp: in  std_logic_vector(7 downto 0);
	pci_exp_rxn: in  std_logic_vector(7 downto 0);
	sys_clk_p: in std_logic;
	sys_clk_n: in std_logic;
	sys_rst_n: in std_logic);
end entity;

architecture top of loopback is
	signal clk, rst: std_logic := '0';

	constant pcie_config: pcie.transceiver_configuration := pcie.new_config(
		host_rx => 1, host_tx => 1
	);


	signal to_rx_vld, from_rx_vld, to_rx_req, from_rx_req:
		std_ulogic_vector(pcie.rx_count(pcie_config) - 1 downto 0) := (others => '0');
	signal to_rx, from_rx: pcie.fragment_vector(pcie.rx_count(pcie_config) - 1 downto 0);

	signal to_tx_vld, from_tx_vld, to_tx_req, from_tx_req:
		std_ulogic_vector(pcie.tx_count(pcie_config) - 1 downto 0) := (others => '0');
	signal to_tx, from_tx: pcie.fragment_vector(pcie.tx_count(pcie_config) - 1 downto 0);

	signal rx_user_vld, rx_user_req, tx_user_vld, tx_user_req: std_ulogic := '0';
	signal rx_user: pcie.rx_stream := pcie.default_rx_stream;
	signal tx_no_eos: pcie.tx_stream := pcie.default_tx_stream;
	signal tx_user: pcie.tx_stream := pcie.default_tx_stream;

begin

ep: pcie.gen2_endpoint
generic map(config => pcie_config)
port map(
	clk => clk,
	rst => rst,

	pci_exp_txp => pci_exp_txp,
	pci_exp_txn => pci_exp_txn,
	pci_exp_rxp => pci_exp_rxp,
	pci_exp_rxn => pci_exp_rxn,

	sys_clk_p => sys_clk_p,
	sys_clk_n => sys_clk_n,
	sys_rst_n => sys_rst_n,

	to_rx_vld => to_rx_vld,
	to_rx_req => to_rx_req,
	to_rx => to_rx,
	from_rx_vld => from_rx_vld,
	from_rx_req => from_rx_req,
	from_rx => from_rx,

	from_tx_vld => from_tx_vld,
	from_tx_req => from_tx_req,
	from_tx => from_tx,
	to_tx_vld => to_tx_vld,
	to_tx_req => to_tx_req,
	to_tx => to_tx
);

rx: pcie.host_rx_channel
generic map(config => pcie_config, id => 1)
port map(
	clk => clk,
	rst => rst,

	from_ep_vld => to_rx_vld(0),
	from_ep_req => to_rx_req(0),
	from_ep => to_rx(0),

	to_ep_vld => from_rx_vld(0),
	to_ep_req => from_rx_req(0),
	to_ep => from_rx(0),

	o_vld => rx_user_vld,
	o_req => rx_user_req,
	o => rx_user
);


tx_no_eos.payload <= rx_user.payload;
tx_no_eos.cnt     <= rx_user.cnt;
timeout: pcie_utilities.tx_stream_timeout
generic map(timeout => 100)
port map(
	clk => clk,

	i => tx_no_eos,
	i_vld => rx_user_vld,
	i_req => rx_user_req,

	o => tx_user,
	o_vld => tx_user_vld,
	o_req => tx_user_req
);


tx: pcie.host_tx_channel
generic map(config => pcie_config, id => 2)
port map(
	clk => clk,
	rst => rst,

	from_ep_vld => to_tx_vld(0),
	from_ep_req => to_tx_req(0),
	from_ep => to_tx(0),

	to_ep_vld => from_tx_vld(0),
	to_ep_req => from_tx_req(0),
	to_ep => from_tx(0),

	i_vld => tx_user_vld,
	i_req => tx_user_req,
	i => tx_user
);

end architecture;

