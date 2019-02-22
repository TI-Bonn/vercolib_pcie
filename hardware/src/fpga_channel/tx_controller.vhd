-- Pack PCIe Transciever packets and handle transfer requests
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.host_types.all;
use work.fpga_filter_pkg.all;
use work.pcie_fifo_packet.all;

use work.fpga_tx_write_cpld_types.all;
use work.sender_cfg_ctrl_types.all;

entity fpga_tx_ctrl is
generic(
	max_payload_bytes: positive := 256;
	id: positive := 1);
port(
	clk: in std_logic;

	cfg_vld: in  std_logic;
	cfg_req: out std_logic := '1';
	cfg:     in  filter_packet;

	fifo_req: out std_logic := '1';
	fifo:     in  fifo_packet;

	status: in fifo_status;

	send_vld: out std_logic := '0';
	send_req: in  std_logic;
	send_dat: out fragment);
end entity;


architecture arch of fpga_tx_ctrl is

	signal config: fpga_tx_config_t := init_config;

	signal cpld_packet, data_packet: fragment := default_fragment;
	signal cpld_vld, data_vld: std_logic := '0';
	signal cpld_req, data_req: std_logic := '1';

	signal transferred_bytes: u32 := (others => '0');
begin

	data_req <= send_req;
	cpld_req <= send_req;
	output: process(cpld_vld, cpld_packet, data_vld, data_packet)
	begin
		if cpld_vld then
			send_dat <= cpld_packet;
			send_vld <= cpld_vld;
		else
			send_dat <= data_packet;
			send_vld <= data_vld;
		end if;
	end process;

	ctrl: entity work.sender_cfg_ctrl
	port map(
		clk => clk,
		i     => cfg,
		i_vld => cfg_vld,
		i_req => cfg_req,
		cfg => config
	);

	cpld_gen: entity work.fpga_tx_write_cpld
	generic map(id => id)
	port map(
		clk => clk,
		cfg => config,

		data => transferred_bytes,

		o => cpld_packet,
		o_vld => cpld_vld,
		o_req => cpld_req
	);

	data_gen: entity work.sender_pack_data
	generic map(id => id, max_payload_bytes => max_payload_bytes)
	port map(
		clk => clk,
		fifo => fifo,
		fifo_req => fifo_req,
		status => status,
		cfg => config,

		o => data_packet,
		o_vld => data_vld,
		o_req => data_req,

		transferred => transferred_bytes
	);
end architecture;
