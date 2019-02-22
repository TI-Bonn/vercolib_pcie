library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.pcie.all;
use work.host_types.all;
use work.transceiver_128bit_types.all;

entity gen2_endpoint is
	generic(config: transceiver_configuration);
	port(
		clk : out std_logic;
		rst : out std_logic;

		------------------------
		-- toplevel interface --
		------------------------
		pci_exp_txp : out std_logic_vector(7 downto 0);
		pci_exp_txn : out std_logic_vector(7 downto 0);
		pci_exp_rxp : in  std_logic_vector(7 downto 0);
		pci_exp_rxn : in  std_logic_vector(7 downto 0);
		sys_clk_p   : in  std_logic;
		sys_clk_n   : in  std_logic;
		sys_rst_n   : in  std_logic;

		-----------------------
		-- channel interface --
		-----------------------
		-- downstream:
		-- rx_host_channel output
		to_rx_vld   : out std_ulogic_vector(rx_count(config)-1 downto 0) := (others => '0');
		to_rx_req   : in  std_ulogic_vector(rx_count(config)-1 downto 0);
		to_rx       : out fragment_vector(rx_count(config)-1 downto 0);
		-- rx_host_channel input
		from_rx_vld : in  std_ulogic_vector(rx_count(config)-1 downto 0) := (others => '0');
		from_rx_req : out std_ulogic_vector(rx_count(config)-1 downto 0);
		from_rx     : in  fragment_vector(rx_count(config)-1 downto 0);

		-- upstream:
		-- tx_host_channel input
		from_tx_vld : in  std_ulogic_vector(tx_count(config)-1 downto 0) := (others => '0');
		from_tx_req : out std_ulogic_vector(tx_count(config)-1 downto 0);
		from_tx     : in  fragment_vector(tx_count(config)-1 downto 0);
		-- tx_host_channel output
		to_tx_vld   : out std_ulogic_vector(tx_count(config)-1 downto 0) := (others => '0');
		to_tx_req   : in  std_ulogic_vector(tx_count(config)-1 downto 0);
		to_tx       : out fragment_vector(tx_count(config)-1 downto 0)
	);
end gen2_endpoint;

architecture vc707 of gen2_endpoint is
attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of vc707 : architecture is "yes";

constant C_DATA_WIDTH : integer range 64 to 128 := 128;

  component pcie_7x_0
    port (
     -------------------------------------------------------------------------------------------------------------------
     -- PCI Express (pci_exp) Interface                                                                               --
     -------------------------------------------------------------------------------------------------------------------
      pci_exp_txp                                : out std_logic_vector(7 downto 0);
      pci_exp_txn                                : out std_logic_vector(7 downto 0);
      pci_exp_rxp                                : in  std_logic_vector(7 downto 0);
      pci_exp_rxn                                : in  std_logic_vector(7 downto 0);

     -------------------------------------------------------------------------------------------------------------------
     -- AXI-S Interface                                                                                               --
     -------------------------------------------------------------------------------------------------------------------
      -- Common
      user_clk_out                               : out std_logic;
      user_reset_out                             : out std_logic;
      user_lnk_up                                : out std_logic;
      user_app_rdy                               : out std_logic;

      -- TX
      s_axis_tx_tready                           : out std_logic;
      s_axis_tx_tdata                            : in std_logic_vector((C_DATA_WIDTH - 1) downto 0);
      s_axis_tx_tkeep                            : in std_logic_vector((C_DATA_WIDTH / 8 - 1) downto 0);
      s_axis_tx_tlast                            : in std_logic;
      s_axis_tx_tvalid                           : in std_logic;
      s_axis_tx_tuser                            : in std_logic_vector(3 downto 0);

      -- RX
      m_axis_rx_tdata                            : out std_logic_vector((C_DATA_WIDTH - 1) downto 0);
      m_axis_rx_tkeep                            : out std_logic_vector((C_DATA_WIDTH / 8 - 1) downto 0);
      m_axis_rx_tlast                            : out std_logic;
      m_axis_rx_tvalid                           : out std_logic;
      m_axis_rx_tready                           : in std_logic;
      m_axis_rx_tuser                            : out std_logic_vector(21 downto 0);

      cfg_device_number                          : out std_logic_vector(4 downto 0);
      cfg_dcommand2                              : out std_logic_vector(15 downto 0);
      cfg_pmcsr_pme_status                       : out std_logic;
      cfg_status                                 : out std_logic_vector(15 downto 0);
      cfg_to_turnoff                             : out std_logic;
      cfg_received_func_lvl_rst                  : out std_logic;
      cfg_dcommand                               : out std_logic_vector(15 downto 0);
      cfg_bus_number                             : out std_logic_vector(7 downto 0);
      cfg_function_number                        : out std_logic_vector(2 downto 0);
      cfg_command                                : out std_logic_vector(15 downto 0);
      cfg_dstatus                                : out std_logic_vector(15 downto 0);
      cfg_lstatus                                : out std_logic_vector(15 downto 0);
      cfg_pcie_link_state                        : out std_logic_vector(2 downto 0);
      cfg_lcommand                               : out std_logic_vector(15 downto 0);
      cfg_pmcsr_pme_en                           : out std_logic;
      cfg_pmcsr_powerstate                       : out std_logic_vector(1 downto 0);
      tx_buf_av                                  : out std_logic_vector(5 downto 0);
      tx_err_drop                                : out std_logic;
      tx_cfg_req                                 : out std_logic;

      cfg_bridge_serr_en                         : out std_logic;
      cfg_slot_control_electromech_il_ctl_pulse  : out std_logic;
      cfg_root_control_syserr_corr_err_en        : out std_logic;
      cfg_root_control_syserr_non_fatal_err_en   : out std_logic;
      cfg_root_control_syserr_fatal_err_en       : out std_logic;
      cfg_root_control_pme_int_en                : out std_logic;
      cfg_aer_rooterr_corr_err_reporting_en      : out std_logic;
      cfg_aer_rooterr_non_fatal_err_reporting_en : out std_logic;
      cfg_aer_rooterr_fatal_err_reporting_en     : out std_logic;
      cfg_aer_rooterr_corr_err_received          : out std_logic;
      cfg_aer_rooterr_non_fatal_err_received     : out std_logic;
      cfg_aer_rooterr_fatal_err_received         : out std_logic;
      cfg_vc_tcvc_map                            : out std_logic_vector(6 downto 0);

     ---------------------------------------------------------------------
      -- EP Only                                                        --
     ---------------------------------------------------------------------
      cfg_interrupt                              : in std_logic;
      cfg_interrupt_rdy                          : out std_logic;
      cfg_interrupt_assert                       : in std_logic;
      cfg_interrupt_di                           : in std_logic_vector(7 downto 0);
      cfg_interrupt_do                           : out std_logic_vector(7 downto 0);
      cfg_interrupt_mmenable                     : out std_logic_vector(2 downto 0);
      cfg_interrupt_msienable                    : out std_logic;
      cfg_interrupt_msixenable                   : out std_logic;
      cfg_interrupt_msixfm                       : out std_logic;
      cfg_interrupt_stat                         : in std_logic;
      cfg_pciecap_interrupt_msgnum               : in std_logic_vector(4 downto 0);

     --------------------------------------------------------------------------------------------------------------------
     -- System(SYS) Interface                                                                                         --
     -------------------------------------------------------------------------------------------------------------------
     sys_clk                       : in std_logic;
     sys_rst_n                     : in std_logic);
  end component;

  -- Common
  signal user_lnk_up            : std_logic;
  signal user_clk               : std_logic;
  signal user_reset             : std_logic;

  -- Tx
  signal s_axis_tx_tready       : std_logic;
  signal s_axis_tx_tuser        : std_logic_vector (3 downto 0);
  signal s_axis_tx_tdata        : std_logic_vector((C_DATA_WIDTH - 1) downto 0);
  signal s_axis_tx_tkeep        : std_logic_vector((C_DATA_WIDTH/8 - 1) downto 0);
  signal s_axis_tx_tlast        : std_logic;
  signal s_axis_tx_tvalid       : std_logic;

  -- Rx
  signal m_axis_rx_tdata        : std_logic_vector((C_DATA_WIDTH - 1) downto 0);
  signal m_axis_rx_tkeep        : std_logic_vector((C_DATA_WIDTH/8- 1) downto 0);
  signal m_axis_rx_tlast        : std_logic;
  signal m_axis_rx_tvalid       : std_logic;
  signal m_axis_rx_tready       : std_logic;
  signal m_axis_rx_tuser        : std_logic_vector (21 downto 0);

  -- Config
  signal cfg_interrupt                 : std_logic;
  signal cfg_interrupt_assert          : std_logic;
  signal cfg_interrupt_di              : std_logic_vector(7 downto 0);
  signal cfg_interrupt_stat            : std_logic;
  signal cfg_pciecap_interrupt_msgnum  : std_logic_vector(4 downto 0);

  signal cfg_to_turnoff                : std_logic;
  signal cfg_bus_number                : std_logic_vector(7 downto 0);
  signal cfg_device_number             : std_logic_vector(4 downto 0);
  signal cfg_function_number           : std_logic_vector(2 downto 0);

  signal sys_clk                        : std_logic;
  signal sys_rst_n_c                    : std_logic;

  signal cfg_completer_id     : std_logic_vector(15 downto 0);
  
  -- arbiter
	signal rx_arb_ep : fragment;
	signal rx_arb_ep_vld  : std_logic;
	signal rx_arb_ep_req  : std_logic;
	signal tx_arb_ep : fragment;
	signal tx_arb_ep_vld  : std_logic;
	signal tx_arb_ep_req  : std_logic;
	
	signal to_rx_vld_multi : std_logic;
	signal to_rx_req_multi : std_logic;
	signal to_rx_multi     : fragment;
	
	signal to_tx_vld_multi : std_logic;
	signal to_tx_req_multi : std_logic;
	signal to_tx_multi     : fragment;

begin
	clk <= user_clk;

  refclk_ibuf : IBUFDS_GTE2
     port map(
       O => sys_clk,
       ODIV2 => open,
       CEB => '0',
       I => sys_clk_p,
       IB => sys_clk_n);

  sys_reset_n_ibuf : IBUF
     port map(
       O       => sys_rst_n_c,
       I       => sys_rst_n);

  pcie_7x_0_i : pcie_7x_0
  port map(
  --------------------------------------------------------------------------------------------
  -- PCI Express (pci_exp) Interface                                                        --
  --------------------------------------------------------------------------------------------
  -- TX
  pci_exp_txp                               => pci_exp_txp,
  pci_exp_txn                               => pci_exp_txn,
  -- RX
  pci_exp_rxp                               => pci_exp_rxp,
  pci_exp_rxn                               => pci_exp_rxn,

  -------------------------------------------------------------------------------------------------------------------
  -- AXI-S Interface                                                                                            --
  -------------------------------------------------------------------------------------------------------------------
  -- Common
  user_clk_out                               => user_clk ,
  user_reset_out                             => user_reset,
  user_lnk_up                                => user_lnk_up,
  user_app_rdy                               => open,

  -- TX
  s_axis_tx_tready                           => s_axis_tx_tready ,
  s_axis_tx_tdata                            => s_axis_tx_tdata ,
  s_axis_tx_tkeep                            => s_axis_tx_tkeep ,
  s_axis_tx_tlast                            => s_axis_tx_tlast ,
  s_axis_tx_tvalid                           => s_axis_tx_tvalid ,
  s_axis_tx_tuser                            => s_axis_tx_tuser,

  -- RX
  m_axis_rx_tdata                            => m_axis_rx_tdata ,
  m_axis_rx_tkeep                            => m_axis_rx_tkeep ,
  m_axis_rx_tlast                            => m_axis_rx_tlast ,
  m_axis_rx_tvalid                           => m_axis_rx_tvalid ,
  m_axis_rx_tready                           => m_axis_rx_tready ,
  m_axis_rx_tuser                            => m_axis_rx_tuser,

  cfg_device_number                          => cfg_device_number ,
  cfg_dcommand2                              => open ,
  cfg_pmcsr_pme_status                       => open ,
  cfg_status                                 => open ,
  cfg_to_turnoff                             => cfg_to_turnoff ,
  cfg_received_func_lvl_rst                  => open ,
  cfg_dcommand                               => open ,
  cfg_bus_number                             => cfg_bus_number ,
  cfg_function_number                        => cfg_function_number ,
  cfg_command                                => open ,
  cfg_dstatus                                => open ,
  cfg_lstatus                                => open ,
  cfg_pcie_link_state                        => open ,
  cfg_lcommand                               => open ,
  cfg_pmcsr_pme_en                           => open ,
  cfg_pmcsr_powerstate                       => open ,
  tx_buf_av                                  => open ,
  tx_err_drop                                => open ,
  tx_cfg_req                                 => open ,

  cfg_bridge_serr_en                         => open ,
  cfg_slot_control_electromech_il_ctl_pulse  => open ,
  cfg_root_control_syserr_corr_err_en        => open ,
  cfg_root_control_syserr_non_fatal_err_en   => open ,
  cfg_root_control_syserr_fatal_err_en       => open ,
  cfg_root_control_pme_int_en                => open ,
  cfg_aer_rooterr_corr_err_reporting_en      => open ,
  cfg_aer_rooterr_non_fatal_err_reporting_en => open ,
  cfg_aer_rooterr_fatal_err_reporting_en     => open ,
  cfg_aer_rooterr_corr_err_received          => open ,
  cfg_aer_rooterr_non_fatal_err_received     => open ,
  cfg_aer_rooterr_fatal_err_received         => open ,
  cfg_vc_tcvc_map                            => open ,

  ---------------------------------------------------------------------
   -- EP Only                                                        --
  ---------------------------------------------------------------------
  cfg_interrupt                              => cfg_interrupt ,
  cfg_interrupt_rdy                          => open ,
  cfg_interrupt_assert                       => cfg_interrupt_assert ,
  cfg_interrupt_di                           => cfg_interrupt_di ,
  cfg_interrupt_do                           => open ,
  cfg_interrupt_mmenable                     => open ,
  cfg_interrupt_msienable                    => open ,
  cfg_interrupt_msixenable                   => open ,
  cfg_interrupt_msixfm                       => open ,
  cfg_interrupt_stat                         => cfg_interrupt_stat ,
  cfg_pciecap_interrupt_msgnum               => cfg_pciecap_interrupt_msgnum,

  ----------------------------------------------------------------------------------------------------------------
  -- System(SYS) Interface                                                                                      --
  ----------------------------------------------------------------------------------------------------------------
  sys_clk                                    => sys_clk ,
  sys_rst_n                                  => sys_rst_n_c

);

  cfg_interrupt_stat           <= '0';      -- Never set the Interrupt Status bit
  cfg_pciecap_interrupt_msgnum <= "00000";  -- Zero out Interrupt Message Number
  cfg_interrupt_assert         <= '0';      -- Always drive interrupt de-assert
  cfg_interrupt                <= '0';      -- Never drive interrupt by qualifying cfg_interrupt_assert
  cfg_interrupt_di             <= x"00";    -- Do not set interrupt fields

  cfg_completer_id     <= (cfg_bus_number & cfg_device_number & cfg_function_number);

ep: entity work.endpoint_core
	generic map(config => config)
	port map(
		clk => user_clk,
		rst => rst,
		Core_ID => cfg_completer_id,
		axis_rx_user => m_axis_rx_tuser,
		axis_rx_data => m_axis_rx_tdata,
		axis_rx_valid => m_axis_rx_tvalid,
		axis_rx_ready => m_axis_rx_tready,
		axis_tx_user => s_axis_tx_tuser,
		axis_tx_last => s_axis_tx_tlast,
		axis_tx_keep => s_axis_tx_tkeep,
		axis_tx_data => s_axis_tx_tdata,
		axis_tx_valid => s_axis_tx_tvalid,
		axis_tx_ready => s_axis_tx_tready,
		to_rx_vld => to_rx_vld_multi,
		to_rx_req => to_rx_req_multi,
		to_rx => to_rx_multi,
		from_rx_vld => rx_arb_ep_vld,
		from_rx_req => rx_arb_ep_req,
		from_rx => rx_arb_ep,
		from_tx_vld => tx_arb_ep_vld,
		from_tx_req => tx_arb_ep_req,
		from_tx => tx_arb_ep,
		to_tx_vld => to_tx_vld_multi,
		to_tx_req => to_tx_req_multi,
		to_tx => to_tx_multi
	);
	
rx_loop: for i in 0 to config.host_rx_channels+config.fpga_rx_channels-1 generate
	to_rx_vld(i) <= to_rx_vld_multi;
	to_rx(i) <= to_rx_multi;
end generate;
to_rx_req_multi <= and to_rx_req;

tx_loop: for i in 0 to config.host_tx_channels+config.fpga_tx_channels-1 generate
	to_tx_vld(i) <= to_tx_vld_multi;
	to_tx(i) <= to_tx_multi;
end generate;
to_tx_req_multi <= and to_tx_req;

rx_arbiter: entity work.packet_arbiter
	generic map(
		ports => config.host_rx_channels+config.fpga_rx_channels
	)
	port map(
		clk    => clk,
		rst    => rst,
		i_req  => from_rx_req,
		i_vld  => from_rx_vld,
		i      => from_rx,    
		o_req  => rx_arb_ep_req,
		o_vld  => rx_arb_ep_vld,
		o      => rx_arb_ep
	);

tx_arbiter: entity work.packet_arbiter
	generic map(
		ports => config.host_tx_channels+config.fpga_tx_channels
	)
	port map(
		clk    => clk,
		rst    => rst,
		i_req  => from_tx_req,
		i_vld  => from_tx_vld,
		i      => from_tx,    
		o_req  => tx_arb_ep_req,
		o_vld  => tx_arb_ep_vld,
		o      => tx_arb_ep
	);

end architecture;







