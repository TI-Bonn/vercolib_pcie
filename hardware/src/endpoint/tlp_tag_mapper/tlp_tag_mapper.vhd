---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description: has the overview about read requests which are in-flight
-- Version: 	0.1
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity tlp_tag_mapper is
	port(
		clk      : in  std_logic;
		rst      : in  std_logic;

		rx_i     : in  fragment;
		rx_i_vld : in  std_logic;
		rx_i_req : out std_logic := '0';

		rx_o     : out fragment;
		rx_o_vld : out std_logic := '0';
		rx_o_req : in  std_logic;

		tx_i     : in  fragment;
		tx_i_vld : in  std_logic;
		tx_i_req : out std_logic := '0';

		tx_o     : out fragment;
		tx_o_vld : out std_logic := '0';
		tx_o_req : in  std_logic
	);
end tlp_tag_mapper;

architecture struct of tlp_tag_mapper is
	signal wr_en : std_logic;
	signal wr_addr : std_logic_vector(7 downto 0);
	signal wr_chn_id : std_logic_vector(7 downto 0);
	signal wr_tag : std_logic_vector(7 downto 0);
	signal rd_addr : std_logic_vector(7 downto 0);
	signal rd_chn_id : std_logic_vector(7 downto 0);
	signal rd_tag : std_logic_vector(7 downto 0);
	signal tlp_tag_o : std_logic_vector(7 downto 0);
	signal tlp_tag_avail : std_logic;
	signal tlp_tag_rd_en : std_logic;
	signal tlp_tag_i : std_logic_vector(7 downto 0);
	signal tlp_tag_wr_en : std_logic;
begin

replacer: entity work.tx_tag_replacer
	port map(
		clk        => clk,
		rst        => rst,
		tag        => tlp_tag_o,
		tag_avail  => tlp_tag_avail,
		tag_set    => tlp_tag_rd_en,
		mem_wr     => wr_en,
		mem_addr   => wr_addr,
		mem_chn_id => wr_chn_id,
		mem_tag    => wr_tag,
		i          => tx_i,
		i_vld      => tx_i_vld,
		i_req      => tx_i_req,
		o          => tx_o,
		o_vld      => tx_o_vld,
		o_req      => tx_o_req
	);

restorer: entity work.rx_tag_restorer
	port map(
		clk        => clk,
		rst        => rst,
		tag        => tlp_tag_i,
		tag_rst    => tlp_tag_wr_en,
		mem_addr   => rd_addr,
		mem_chn_id => rd_chn_id,
		mem_tag    => rd_tag,
		i          => rx_i,
		i_vld      => rx_i_vld,
		i_req      => rx_i_req,
		o          => rx_o,
		o_vld      => rx_o_vld,
		o_req      => rx_o_req
	);

virtual_tag_mem: entity work.virtual_tag_memory
	port map(
		clk       => clk,
		rst       => rst,
		wr_en     => wr_en,
		wr_addr   => wr_addr,
		wr_chn_id => wr_chn_id,
		wr_tag    => wr_tag,
		rd_addr   => rd_addr,
		rd_chn_id => rd_chn_id,
		rd_tag    => rd_tag
	);

tlp_tag_mem: entity work.tlp_tag_memory
	port map(
		clk   => clk,
		rst   => rst,
		i     => tlp_tag_i,
		wr_en => tlp_tag_wr_en,
		o     => tlp_tag_o,
		rd_en => tlp_tag_rd_en,
		avail => tlp_tag_avail
	);

end architecture struct;
