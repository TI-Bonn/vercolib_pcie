-- Buffer data and generate read tags
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

package fpga_rx_tag_types is
	type rqst_tag_t is (READ_FULL, READ_HALF);
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.host_types.all;

use work.fpga_rx_tag_types.all;

entity fpga_rx_fifo is
generic(fifo_addr_bits: positive);
port(
	clk: in std_logic;
	rst: in std_logic;

	i:     in  fragment;
	i_vld: in  std_logic;
	i_req: out std_logic := '1';

	o:      out qdword := (others => '0');
	o_keep: out nibble := (others => '0');
	o_vld:  out std_logic := '0';
	o_req:  in  std_logic;

	tag:     out rqst_tag_t := READ_FULL;
	tag_vld: out std_logic := '0';
	tag_req: in  std_logic);
end entity;


architecture arch of fpga_rx_fifo is
	signal packed_data: qdword := (others => '0');
	signal packed_keep: nibble := (others => '0');
	signal packed_vld, packed_req:  std_logic;

	signal overflow: std_logic := '0';
	signal full_tag, half_tag: boolean := false;
begin


tag_gen: process
begin
	wait until rising_edge(clk);

	half_tag <= true when overflow;

	if tag_req then
		tag <= READ_FULL when full_tag else
		       READ_HALF;
		tag_vld <= '1' when full_tag or half_tag else
		           '0';
		half_tag <= false when half_tag and not full_tag;
		full_tag <= false;
	end if;

	if rst then
		tag_vld <= '0';
		half_tag <= false;
		full_tag <= true;
	end if;
end process;

pack: entity work.receiver_repack
port map(
	clk    => clk,
	i      => i,
	i_vld  => i_vld,
	i_req  => i_req,
	o      => packed_data,
	o_keep => packed_keep,
	o_vld  => packed_vld,
	o_req  => packed_req
);

fifo: entity work.fpga_rx_fifo_internal
generic map(
	depth_bits => fifo_addr_bits
)
port map(
	clk    => clk,
	rst    => rst,
	i      => packed_data,
	i_keep => packed_keep,
	i_vld  => packed_vld,
	i_req  => packed_req,
	o      => o,
	o_keep => o_keep,
	o_vld  => o_vld,
	o_req  => o_req
);

cnt: entity work.receiver_output_count
generic map(
	max_count => ((2**fifo_addr_bits)/2)
)
port map(
	clk      => clk,
	rst      => rst,
	i_vld    => o_vld,
	o_req    => o_req,
	overflow => overflow
);



end architecture arch;
