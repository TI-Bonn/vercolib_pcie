---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description:	Handles HOST-FPGA information exchange about the whole transceiver
-- Version: 	0.1
---------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils.all;
use work.host_types.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity config_channel is
	generic(
		fpga_id         : dword := x"ABCDABCD";
		core_id         : dword := x"01230123";
		num_rx_host_cnl : natural := 0;
		num_tx_host_cnl : natural := 0;
		num_rx_fpga_cnl : natural := 0;
		num_tx_fpga_cnl : natural := 0
	);
	port(
		clk   : in  std_ulogic;

		-- reset signals
		rst_host_channel : out std_ulogic := '0';
		rst_fpga_channel : out std_ulogic := '0';
		rst_endpoint     : out std_ulogic := '0';

		-- input ports
		i     : in  fragment;
		i_vld : in  std_ulogic;
		i_req : out std_ulogic := '1';

		-- output ports
		o     : out fragment := default_fragment;
		o_vld : out std_ulogic := '0';
		o_req : in  std_ulogic
	);
end config_channel;

architecture arch of config_channel is
	signal cpld_payload : std_ulogic_vector(31 downto 0);
	signal cpld_tag : std_ulogic_vector(7 downto 0);
	signal cpld_vld : std_ulogic;
	signal cpld_lo_addr : std_ulogic_vector(6 downto 0);
	signal cpld_done : std_ulogic;
	signal mem_addr : cfg_reg_addr_t;
	signal mem_rd_data : std_ulogic_vector(31 downto 0);
	signal mem_rd_en : std_ulogic;
	signal mem_wr_data : std_ulogic_vector(31 downto 0);
	signal mem_wr_en : std_ulogic;
	signal op_addr : cfg_reg_addr_t;
	signal op_code : op_code_t;
	signal op_data : std_ulogic_vector(31 downto 0);
	signal op_rdy : std_ulogic;
	signal op_vld : std_ulogic;
	signal rq_tag : std_ulogic_vector(7 downto 0);

begin

dec: entity work.cfg_channel_decoder
	port map(
		clk      => clk,
		rst      => rst_endpoint,
		i        => i,
		i_vld    => i_vld,
		i_req    => i_req,
		op_code  => op_code,
		op_addr  => op_addr,
		op_data  => op_data,
		op_tag   => rq_tag,
		op_vld   => op_vld,
		op_ready => op_rdy
	);

ctrl: entity work.cfg_channel_controller
	port map(
		clk              => clk,
		rst_host_channel => rst_host_channel,
		rst_fpga_channel => rst_fpga_channel,
		rst_endpoint     => rst_endpoint,
		op_code          => op_code,
		op_addr          => op_addr,
		op_data          => op_data,
		op_vld           => op_vld,
		op_tag           => rq_tag,
		op_ready         => op_rdy,
		mem_addr         => mem_addr,
		mem_wr_data      => mem_wr_data,
		mem_wr_en        => mem_wr_en,
		mem_rd_data      => mem_rd_data,
		mem_rd_en        => mem_rd_en,
		cpld_payload     => cpld_payload,
		cpld_lo_addr     => cpld_lo_addr,
		cpld_tag         => cpld_tag,
		cpld_vld         => cpld_vld,
		cpld_done        => cpld_done
	);

mem: entity work.cfg_channel_memory
	generic map(
		fpga_id_c         => fpga_id,
		core_id_c         => core_id,
		num_rx_host_cnl_c => num_rx_host_cnl,
		num_tx_host_cnl_c => num_tx_host_cnl,
		num_rx_fpga_cnl_c => num_rx_fpga_cnl,
		num_tx_fpga_cnl_c => num_tx_fpga_cnl
	)
	port map(
		clk     => clk,
		rst     => rst_endpoint,
		addr    => mem_addr,
		wr_data => mem_wr_data,
		wr_en   => mem_wr_en,
		rd_data => mem_rd_data,
		rd_en   => mem_rd_en
	);

cpld: entity work.cfg_channel_completer
	port map(
		clk          => clk,
		rst          => rst_endpoint,
		cpld_tag     => cpld_tag,
		cpld_payload => cpld_payload,
		cpld_lo_addr => cpld_lo_addr,
		cpld_vld     => cpld_vld,
		cpld_done    => cpld_done,
		o            => o,
		o_vld        => o_vld,
		o_req        => o_req
	);

end architecture arch;
