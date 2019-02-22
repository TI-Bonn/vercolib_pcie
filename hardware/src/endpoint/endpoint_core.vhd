---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.host_types.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.tlp_types.all;

entity endpoint_core is
	generic(config     : transceiver_configuration);
	port(
		clk : in  std_logic;
		rst : out std_logic;

		-------------------
		-- pcie endpoint --
		-------------------
		Core_ID       : in  std_logic_vector(15 downto 0);

		-- rx
		axis_rx_user  : in  std_logic_vector(21 downto 0);
		axis_rx_data  : in  std_logic_vector(127 downto 0);
		axis_rx_valid : in  std_logic;
		axis_rx_ready : out std_logic := '1';

		-- tx
		axis_tx_user  : out std_logic_vector(3 downto 0);
		axis_tx_last  : out std_logic;
		axis_tx_keep  : out std_logic_vector(15 downto 0);
		axis_tx_data  : out std_logic_vector(127 downto 0);
		axis_tx_valid : out std_logic := '0';
		axis_tx_ready : in  std_logic;

		------------------------
		-- channel interfaces --
		------------------------
		-- downstream:
		-- rx_channel output
		to_rx_vld   : out std_logic := '0';
		to_rx_req   : in  std_logic;
		to_rx       : out fragment;
		-- rx_channel input
		from_rx_vld : in  std_logic := '0';
		from_rx_req : out std_logic;
		from_rx     : in fragment;

		-- upstream:
		-- tx_channel input
		from_tx_vld : in  std_logic := '0';
		from_tx_req : out std_logic;
		from_tx     : in  fragment;
		-- tx_channel output
		to_tx_vld   : out std_logic := '0';
		to_tx_req   : in  std_logic;
		to_tx       : out fragment
	);
end endpoint_core;

architecture arch of endpoint_core is
	signal rst_endpoint : std_ulogic;
	signal converter_demux_data : tlp_packet;
	signal converter_demux_vld : std_logic;       
	signal converter_demux_req : std_logic;       
	signal demux_bar0_data : fragment;              
	signal demux_bar0_vld : std_logic;            
	signal demux_bar0_req : std_logic;            
	signal demux_msix_data : fragment;              
	signal demux_msix_vld : std_logic;            
	signal demux_msix_req : std_logic;            
	signal intmux_msix_vld : std_logic;           
	signal intmux_msix_req : std_logic;           
	signal intmux_msix_data : fragment;             
	signal msix_tlpmux_data : fragment;             
	signal msix_tlpmux_vld : std_logic;           
	signal msix_tlpmux_req : std_logic;           
	signal tlpmux_converter_data : fragment;        
	signal tlpmux_converter_req : std_logic;      
	signal tlpmux_converter_vld : std_logic;      
	signal cpld_rx_tlptag_data : fragment;          
	signal cpld_rx_tlptag_vld : std_logic;        
	signal cpld_rx_tlptag_req : std_logic;        
	signal from_rx_tlpmux_req : std_logic;   
	signal from_rx_intmux_req : std_logic;   
	signal from_tx_tlpmux_req : std_logic;   
	signal from_tx_intmux_req : std_logic;   
	signal cfgchannel_tlpmux_vld : std_logic;     
	signal cfgchannel_tlpmux_data : fragment;       
	signal cfgchannel_tlpmux_req : std_logic;     
	signal demux_cfgchannel_req : std_ulogic;     
	signal demux_cpld_req : std_logic;            
	signal rx_tlptag_out : fragment;                
	signal rx_tlptag_out_vld : std_ulogic;        
	signal rx_tlptag_out_req : std_ulogic;        
	signal tx_tlptag_tlpmux : fragment;             
	signal tx_tlptag_tlpmux_vld : std_ulogic;     
	signal tx_tlptag_tlpmux_req : std_ulogic;     
	

begin
		-- converts axis to costum handshake protocol and destraddles data stream
	rx_converter: entity work.rx_axi_converter
		port map(
			clk           => clk,
			rst           => rst_endpoint,
			axis_rx_user  => axis_rx_user,
			axis_rx_data  => axis_rx_data,
			axis_rx_valid => axis_rx_valid,
			axis_rx_ready => axis_rx_ready,
			o             => converter_demux_data,
			o_vld         => converter_demux_vld,
			o_req         => converter_demux_req
		);

	rx_bar_dmx: entity work.rx_bar_demux
		port map(
			clk      => clk,
			rst      => rst_endpoint,
			i        => converter_demux_data,
			i_vld    => converter_demux_vld,
			i_req    => converter_demux_req,
			bar0     => demux_bar0_data,
			bar0_vld => demux_bar0_vld,
			bar0_req => demux_bar0_req,
			bar1     => demux_msix_data,
			bar1_vld => demux_msix_vld,
			bar1_req => demux_msix_req
		);

	demux_bar0_req <= demux_cfgchannel_req and demux_cpld_req;

	cfg_channel: entity work.config_channel
		generic map(
			fpga_id         => x"FFFF0000",
			core_id         => x"0000FFFF",
			num_rx_host_cnl => config.host_rx_channels,
			num_tx_host_cnl => config.host_tx_channels,
			num_rx_fpga_cnl => config.fpga_rx_channels,
			num_tx_fpga_cnl => config.fpga_tx_channels
		)
		port map(
			clk   => clk,
			rst_host_channel => rst,
			rst_fpga_channel => open,
			rst_endpoint     => rst_endpoint,
			i     => demux_bar0_data,
			i_vld => demux_bar0_vld,
			i_req => demux_cfgchannel_req,
			o     => cfgchannel_tlpmux_data,
			o_vld => cfgchannel_tlpmux_vld,
			o_req => cfgchannel_tlpmux_req
		);

	rx_cpld_preproc: entity work.rx_CplD_preprocessor
		port map(
			clk    => clk,
			rst    => rst_endpoint,
			i      => demux_bar0_data,
			i_vld  => demux_bar0_vld,
			i_req  => demux_cpld_req,
			o      => cpld_rx_tlptag_data,
			o_vld  => cpld_rx_tlptag_vld,
			o_req  => cpld_rx_tlptag_req
		);

	tlp_tag_translator: entity work.tlp_tag_mapper
		port map(
			clk      => clk,
			rst      => rst_endpoint,
			rx_i     => cpld_rx_tlptag_data,
			rx_i_vld => cpld_rx_tlptag_vld,
			rx_i_req => cpld_rx_tlptag_req,
			rx_o     => rx_tlptag_out,
			rx_o_vld => rx_tlptag_out_vld,
			rx_o_req => rx_tlptag_out_req,
			tx_i     => from_rx,
			tx_i_vld => from_rx_vld,
			tx_i_req => from_rx_tlpmux_req,
			tx_o     => tx_tlptag_tlpmux,
			tx_o_vld => tx_tlptag_tlpmux_vld,
			tx_o_req => tx_tlptag_tlpmux_req
		);

	to_rx     <= rx_tlptag_out;
	to_rx_vld <= rx_tlptag_out_vld;

	to_tx     <= rx_tlptag_out;
	to_tx_vld <= rx_tlptag_out_vld;

	rx_tlptag_out_req <= to_rx_req and to_tx_req;

	msix_handler: entity work.MSIX_table
		generic map(
			interrupts => config.interrupts
		)
		port map(
			clk      => clk,
			rst      => rst_endpoint,
			cfg      => demux_msix_data,
			cfg_vld  => demux_msix_vld,
			cfg_req  => demux_msix_req,
			i        => intmux_msix_data,
			i_vld    => intmux_msix_vld,
			i_req    => intmux_msix_req,
			o        => msix_tlpmux_data,
			o_vld    => msix_tlpmux_vld,
			o_req    => msix_tlpmux_req
		);

	tx_interrupt_mux: entity work.tx_interrupt_mux
		port map(
			clk    => clk,
			rst    => rst_endpoint,
			host_rx_vld  => from_rx_vld,
			host_rx_req  => from_rx_intmux_req,
			host_rx      => from_rx,
			host_tx_vld  => from_tx_vld,
			host_tx_req  => from_tx_intmux_req,
			host_tx      => from_tx,
			o_vld  => intmux_msix_vld,
			o_req  => intmux_msix_req,
			o      => intmux_msix_data
		);

	tx_tlp_mux: entity work.tx_tlp_mux
		port map(
			clk => clk,
			rst => rst_endpoint,
			int_vld => msix_tlpmux_vld,
			int_req => msix_tlpmux_req,
			int => msix_tlpmux_data,
			cfg_vld => cfgchannel_tlpmux_vld,
			cfg_req => cfgchannel_tlpmux_req,
			cfg => cfgchannel_tlpmux_data,
			rx_vld => tx_tlptag_tlpmux_vld,
			rx_req => tx_tlptag_tlpmux_req,
			rx => tx_tlptag_tlpmux,
			tx_vld => from_tx_vld,
			tx_req => from_tx_tlpmux_req,
			tx => from_tx,
			o_vld => tlpmux_converter_vld,
			o_req => tlpmux_converter_req,
			o => tlpmux_converter_data
		);

	tx_axi_converter: entity work.tx_axi_converter
		port map(
			clk           => clk,
			rst           => rst_endpoint,
			Core_ID       => Core_ID,
			i             => tlpmux_converter_data,
			i_vld         => tlpmux_converter_vld,
			i_req         => tlpmux_converter_req,
			axis_tx_user  => axis_tx_user,
			axis_tx_last  => axis_tx_last,
			axis_tx_keep  => axis_tx_keep,
			axis_tx_data  => axis_tx_data,
			axis_tx_valid => axis_tx_valid,
			axis_tx_ready => axis_tx_ready
		);

	from_rx_req <= from_rx_intmux_req and from_rx_tlpmux_req;
	from_tx_req <= from_tx_intmux_req and from_tx_tlpmux_req;

end architecture arch;
