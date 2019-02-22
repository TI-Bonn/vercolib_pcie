---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.pcie;
use work.dbg_types.all;

entity fpga_multichannel_eval_top is
	generic(
		config : pcie.transceiver_configuration := pcie.new_config(
			host_tx => 1,
			host_rx => 1,
			fpga_tx => 4,
			fpga_rx => 4
		)
	);
	port(
		pci_exp_txp: out std_logic_vector(7 downto 0);
		pci_exp_txn: out std_logic_vector(7 downto 0);
		pci_exp_rxp: in  std_logic_vector(7 downto 0);
		pci_exp_rxn: in  std_logic_vector(7 downto 0);
		sys_clk_p: in std_logic;
		sys_clk_n: in std_logic;
		sys_rst_n: in std_logic
	);
end fpga_multichannel_eval_top;

architecture arch of fpga_multichannel_eval_top is

	signal clk: std_logic;
	signal rst: std_logic;

	signal to_rx_vld : std_ulogic_vector(pcie.rx_count(config)-1 downto 0);
	signal to_rx_req : std_ulogic_vector(pcie.rx_count(config)-1 downto 0);
	signal to_rx : pcie.fragment_vector(pcie.rx_count(config)-1 downto 0);

	signal from_rx_vld : std_ulogic_vector(pcie.rx_count(config)-1 downto 0);
	signal from_rx_req : std_ulogic_vector(pcie.rx_count(config)-1 downto 0);
	signal from_rx : pcie.fragment_vector(pcie.rx_count(config)-1 downto 0);

	signal to_tx_vld : std_ulogic_vector(pcie.tx_count(config)-1 downto 0);
	signal to_tx_req : std_ulogic_vector(pcie.tx_count(config)-1 downto 0);
	signal to_tx : pcie.fragment_vector(pcie.tx_count(config)-1 downto 0);

	signal from_tx_vld : std_ulogic_vector(pcie.tx_count(config)-1 downto 0);
	signal from_tx_req : std_ulogic_vector(pcie.tx_count(config)-1 downto 0);
	signal from_tx : pcie.fragment_vector(pcie.tx_count(config)-1 downto 0);

	signal rx_o : pcie.rx_stream_vector(config.host_rx_channels+config.fpga_rx_channels-1 downto 0);
	signal rx_o_vld :std_logic_vector(config.host_rx_channels+config.fpga_rx_channels-1 downto 0);
	signal rx_o_req :std_logic_vector(config.host_rx_channels+config.fpga_rx_channels-1 downto 0);

	signal tx_i : pcie.tx_stream_vector(config.host_tx_channels+config.fpga_tx_channels-1 downto 0);
	signal tx_i_vld :std_logic_vector(config.host_tx_channels+config.fpga_tx_channels-1 downto 0);
	signal tx_i_req :std_logic_vector(config.host_tx_channels+config.fpga_tx_channels-1 downto 0);

	signal rx_to_tx : pcie.tx_stream_vector(config.host_tx_channels-1 downto 0);
	signal rx_to_tx_vld :std_logic_vector(config.host_tx_channels-1 downto 0);
	signal rx_to_tx_req :std_logic_vector(config.host_tx_channels-1 downto 0);

	signal dbg_rx_state : dbg_rx_state_vec_t(config.host_rx_channels+config.fpga_rx_channels-1 downto 0);
	signal dbg_command  : dbg_command_t;

	signal dbg_rx_config : dbg_config_vec_t(config.host_rx_channels+config.fpga_rx_channels-1 downto 0);
	signal dbg_tx_config : dbg_config_vec_t(config.host_tx_channels+config.fpga_tx_channels-1 downto 0);

	attribute dont_touch : string;
	attribute mark_debug : string;

	attribute dont_touch of dbg_rx_state : signal is "true";
	attribute mark_debug of dbg_rx_state : signal is "true";

	attribute dont_touch of dbg_command : signal is "true";
	attribute mark_debug of dbg_command : signal is "true";

	attribute dont_touch of dbg_rx_config : signal is "true";
	attribute mark_debug of dbg_rx_config : signal is "true";

	attribute dont_touch of dbg_tx_config : signal is "true";
	attribute mark_debug of dbg_tx_config : signal is "true";

	attribute dont_touch of rx_o : signal is "true";
	attribute dont_touch of rx_o_vld : signal is "true";
	attribute dont_touch of rx_o_req : signal is "true";

	attribute dont_touch of tx_i : signal is "true";
	attribute dont_touch of tx_i_vld : signal is "true";
	attribute dont_touch of tx_i_req : signal is "true";

	attribute mark_debug of rx_o : signal is "true";
	attribute mark_debug of rx_o_vld : signal is "true";
	attribute mark_debug of rx_o_req : signal is "true";

	attribute mark_debug of tx_i : signal is "true";
	attribute mark_debug of tx_i_vld : signal is "true";
	attribute mark_debug of tx_i_req : signal is "true";

	signal clock_counter : unsigned(47 downto 0);
	attribute dont_touch of clock_counter : signal is "true";
	attribute mark_debug of clock_counter : signal is "true";

begin

dbg_ctrl: entity work.dbg_controller
	port map(
		clk => clk,
		rst => rst,
		from_ep_vld => to_rx_vld(0),
		from_ep_req => open,
		from_ep => to_rx(0),
		clock_counter => clock_counter,
		dbg_command => dbg_command
	);

ep: entity work.gen2_endpoint(vc707)
generic map(config => config)
port map(
	clk => clk,
	rst => open,
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


host_rx_loop: for i in 0 to config.host_rx_channels-1 generate
	rx_channel: entity work.host_rx_channel
		generic map(
			config  => config,
			id        => i+1
		)
		port map(
			clk => clk,
			rst => rst,
			from_ep => to_rx(i),
			from_ep_vld => to_rx_vld(i),
			from_ep_req => to_rx_req(i),
			to_ep => from_rx(i),
			to_ep_vld => from_rx_vld(i),
			to_ep_req => from_rx_req(i),
			o => rx_o(i),
			o_vld => rx_o_vld(i),
			o_req => rx_o_req(i)
		);

	rx_eval: entity work.dbg_rx_channel_evaluator
		generic map(
			channel_id => i+1
		)
		port map(
			clk             => clk,
			rst             => rst,
			dbg_from_rx_vld => rx_o_vld(i),
			dbg_from_rx_req => rx_o_req(i),
			dbg_from_rx     => rx_o(i),
			dbg_to_tx_vld   => rx_to_tx_vld(i),
			dbg_to_tx_req   => rx_to_tx_req(i),
			dbg_to_tx       => rx_to_tx(i),
			dbg_command     => dbg_command,
			dbg_state       => dbg_rx_state(i),
			dbg_config      => dbg_rx_config(i)
		);
end generate;

fpga_rx_loop: for i in 0 to pcie.fpga_rx_count(config)-1 generate
	constant base: natural := pcie.host_rx_count(config);
begin
	rx_channel: entity work.fpga_rx_channel
		generic map(
			config  => config,
			id => i+1+config.host_rx_channels+config.host_tx_channels,
			fifo_addr_bits => 9
		)
		port map(
			clk => clk,
			rst => '0',
			from_ep => to_rx(i + base),
			from_ep_vld => to_rx_vld(i + base),
			from_ep_req => to_rx_req(i + base),
			to_ep => from_rx(i + base),
			to_ep_vld => from_rx_vld(i + base),
			to_ep_req => from_rx_req(i + base),

			o => rx_o(i + base),
			o_vld => rx_o_vld(i + base),
			o_req => rx_o_req(i + base)
		);

	rx_eval: entity work.dbg_rx_channel_evaluator
		generic map(
			channel_id => i+1+config.host_rx_channels+config.host_tx_channels
		)
		port map(
			clk             => clk,
			rst             => rst,
			dbg_from_rx_vld => rx_o_vld(i + base),
			dbg_from_rx_req => rx_o_req(i + base),
			dbg_from_rx     => rx_o(i + base),
			dbg_to_tx_vld   => open,
			dbg_to_tx_req   => '0',
			dbg_to_tx       => open,
			dbg_command     => dbg_command,
			dbg_state       => dbg_rx_state(i + base),
			dbg_config      => dbg_rx_config(i + base)
		);
end generate;

host_tx_loop: for i in 0 to config.host_tx_channels-1 generate
	tx_channel: entity work.host_tx_channel
		generic map(
			config  => config,
			id        => i+1+config.host_rx_channels
		)
		port map(
			clk => clk,
			rst => rst,
			i_vld => tx_i_vld(i),
			i_req => tx_i_req(i),
			i => tx_i(i),
			from_ep_vld => to_tx_vld(i),
			from_ep_req => to_tx_req(i),
			from_ep => to_tx(i),
			to_ep_vld => from_tx_vld(i),
			to_ep_req => from_tx_req(i),
			to_ep => from_tx(i)
		);

	tx_eval: entity work.dbg_tx_channel_evaluator
		generic map(
			channel_id => i+1+config.host_rx_channels
		)
		port map(
			clk             => clk,
			rst             => rst,
			dbg_from_rx_vld => rx_to_tx_vld(i),
			dbg_from_rx_req => rx_to_tx_req(i),
			dbg_from_rx     => rx_to_tx(i),
			dbg_to_tx_vld   => tx_i_vld(i),
			dbg_to_tx_req   => tx_i_req(i),
			dbg_to_tx       => tx_i(i),
			dbg_command     => dbg_command,
			dbg_config      => dbg_tx_config(i)
		);
end generate;

fpga_tx_loop: for i in 0 to config.fpga_tx_channels-1 generate
	constant base: natural := pcie.host_tx_count(config);
begin
	tx_channel: entity work.fpga_tx_channel
		generic map(
			config => config,
			id => i+1+config.host_rx_channels+config.host_tx_channels+config.fpga_rx_channels
		)
		port map(
			clk => clk,
			rst => rst,
			from_ep => to_tx(i + base),
			from_ep_vld => to_tx_vld(i + base),
			from_ep_req => to_tx_req(i + base),
			to_ep => from_tx(i + base),
			to_ep_vld => from_tx_vld(i + base),
			to_ep_req => from_tx_req(i + base),
			i => tx_i(i + base),
			i_vld => tx_i_vld(i + base),
			i_req => tx_i_req(i + base)
		);

	tx_eval: entity work.dbg_tx_channel_evaluator
		generic map(
			channel_id => i+1+config.host_rx_channels+config.host_tx_channels+config.fpga_rx_channels
		)
		port map(
			clk             => clk,
			rst             => rst,
			dbg_from_rx_vld => '0',
			dbg_from_rx_req => open,
			dbg_from_rx     => pcie.default_tx_stream,
			dbg_to_tx_vld   => tx_i_vld(i + base),
			dbg_to_tx_req   => tx_i_req(i + base),
			dbg_to_tx       => tx_i(i + base),
			dbg_command     => dbg_command,
			dbg_config      => dbg_tx_config(i + base)
		);
end generate;

end architecture;
