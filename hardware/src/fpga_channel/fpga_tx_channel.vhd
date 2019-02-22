-- FPGA2ALL sender channel
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.transceiver_128bit_types.all;
use work.pcie.all;

use work.pcie_fifo_packet.all;
use work.fpga_filter_pkg.all;

use work.utils.all;

entity fpga_tx_channel is
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
		i           : in  tx_stream;
		i_vld       : in  std_ulogic;
		i_req       : out std_ulogic := '1'
	);
end entity;


architecture hier of fpga_tx_channel is
	signal filtered: filter_packet;
	signal fifo_out: fifo_packet := init_fifo_packet;
	signal fifo_stat: fifo_status := (dwords => (others => '0'), got_eob => '0');
	signal filtered_vld: std_logic := '0';
	signal filtered_req, fifo_req: std_logic := '1';
	signal pipe : fragment;
	signal pipe_vld : std_logic;
	signal pipe_req : std_logic;
begin


filter: entity work.fpga_tx_filter
generic map(id => id)
port map(
	clk   => clk,
	i_pkt => from_ep,
	i_vld => from_ep_vld,
	i_req => from_ep_req,
	o_pkt => filtered,
	o_vld => filtered_vld,
	o_req => filtered_req
);

fifo: entity work.fpga_tx_fifo
port map(
	clk    => clk,
	i      => i,
	i_vld  => i_vld,
	i_req  => i_req,
	o      => fifo_out,
	o_req  => fifo_req,
	status => fifo_stat
);

ctrl: entity work.fpga_tx_ctrl
generic map(
	max_payload_bytes => config.max_payload_bytes,
	id => id)
port map(
	clk      => clk,
	cfg      => filtered,
	cfg_vld  => filtered_vld,
	cfg_req  => filtered_req,
	fifo     => fifo_out,
	fifo_req => fifo_req,
	send_dat => pipe,
	send_vld => pipe_vld,
	send_req => pipe_req,
	status   => fifo_stat
);

out_req_pipe: entity work.pipe_register
	port map(
		clk   => clk,
		i     => pipe,
		i_vld => pipe_vld,
		i_req => pipe_req,
		o     => to_ep,
		o_vld => to_ep_vld,
		o_req => to_ep_req
	);	

end architecture;
