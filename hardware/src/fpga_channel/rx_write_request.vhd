-- Send data requests
-- Author: Sebastian Sch�ller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.host_types.all;
use work.fpga_rx_cfg_ctrl_types.all;
use work.fpga_rx_tag_types.all;


entity fpga_rx_rqst is
generic(
	id: natural;
	fifo_addr_bits: positive
);
port(
	clk: in std_logic;

	cfg:     in fpga_rx_config_t;

	o:     out fragment := default_fragment;
	o_vld: out std_logic := '0';
	o_req: in  std_logic;

	tag:     in  rqst_tag_t;
	tag_vld: in  std_logic;
	tag_req: out std_logic);
end entity;


architecture arch of fpga_rx_rqst is
	constant fifo_size: positive := 2**fifo_addr_bits;

	signal size: u32 := (others => '0');
begin

size <= to_unsigned((fifo_size*16),32) - 16 when tag = READ_FULL else
        to_unsigned(((fifo_size/2)*16),32) when tag = READ_HALF;

tag_req <= not tag_vld or o_req;

process
begin
	wait until rising_edge(clk);

	if o_req then
		o_vld <= '0';
		reset(o);
		if tag_vld = '1' and cfg.target = TARGET_FPGA then
			o_vld <= '1';
			set_rqst32_header(o, make_wr_rqst32(
				length => 1,
				chn_id => id,
				address => std_logic_vector(cfg.addr)
			));
			set_dw(o, 3, std_logic_vector(size));
		end if;
	end if;

end process;

end architecture arch;
