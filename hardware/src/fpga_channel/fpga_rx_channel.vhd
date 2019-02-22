-- FPGA to FPGA communiciton receiver
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.host_types.all;
use work.transceiver_128bit_types.all;
use work.pcie.all;

use work.fpga_filter_pkg.all;
use work.fpga_rx_cfg_ctrl_types.all;
use work.fpga_rx_tag_types.all;

use work.utils.all;

entity fpga_rx_channel is
	generic(
		config         : transceiver_configuration;
		id             : positive;
		fifo_addr_bits : positive := 9
	);
	port(
		clk         : in  std_logic;
		rst         : in  std_logic;
		from_ep     : in  fragment;
		from_ep_vld : in  std_ulogic;
		from_ep_req : out std_ulogic := '1';
		to_ep       : out fragment := default_fragment;
		to_ep_vld   : out std_ulogic := '0';
		to_ep_req   : in  std_ulogic;
		o           : out rx_stream := default_rx_stream;
		o_vld       : out std_ulogic := '0';
		o_req       : in  std_ulogic
	);
end entity;


architecture arch of fpga_rx_channel is
	signal cfg: filter_packet;
	signal cfg_vld: std_logic;

	signal data: fragment;
	signal data_vld, data_req: std_logic;

	signal fpga_rx_config: fpga_rx_config_t;

	signal tag: rqst_tag_t;
	signal tag_req, tag_vld: std_logic;

	signal fifo_rst: std_logic := '0';
	
	signal keep_to_cnt : std_logic_vector(3 downto 0);
begin

filter: entity work.fpga_rx_filter
generic map(id => id)
port map(
	clk      => clk,
	i        => from_ep,
	i_vld    => from_ep_vld,
	i_req    => from_ep_req,
	cfg      => cfg,
	cfg_vld  => cfg_vld,
	data     => data,
	data_vld => data_vld,
	data_req => data_req
);

ctrl: entity work.fpga_rx_cfg_ctrl
port map(
	clk   => clk,
	i     => cfg,
	i_vld => cfg_vld,
	cfg   => fpga_rx_config
);

write_rqst: entity work.fpga_rx_rqst
generic map(
	id             => id,
	fifo_addr_bits => fifo_addr_bits
)
port map(
	clk     => clk,
	cfg     => fpga_rx_config,
	o       => to_ep,
	o_vld   => to_ep_vld,
	o_req   => to_ep_req,
	tag     => tag,
	tag_vld => tag_vld,
	tag_req => tag_req
);

fifo: entity work.fpga_rx_fifo
generic map(
	fifo_addr_bits => fifo_addr_bits
)
port map(
	clk     => clk,
	rst     => fifo_rst,
	i       => data,
	i_vld   => data_vld,
	i_req   => data_req,
	o       => o.payload,
	o_keep  => keep_to_cnt,
	o_vld   => o_vld,
	o_req   => o_req,
	tag     => tag,
	tag_vld => tag_vld,
	tag_req => tag_req
);

fifo_rst <= '1' when fpga_rx_config.target /= TARGET_FPGA else '0';

o.cnt <= keep2cnt(keep_to_cnt);

end architecture arch;
