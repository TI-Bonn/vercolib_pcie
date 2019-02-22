-- Sender write data testbench
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;


use work.host_types.all;
use work.transceiver_128bit_types.all;

use work.sender_cfg_ctrl_types.all;

use work.pcie;
use work.pcie_fifo_packet.all;

entity tb_sender_write_data is
generic(runner_cfg: string);
end entity;

architecture tb of tb_sender_write_data is
	constant clk_period: natural := 2;
	signal clk: std_logic := '0';

	constant chn_id: natural := 2;
	constant max_payload: natural := 512;

	constant test_addr: u64 := x"0123456789abcdef";

	signal fifo_in: pcie.tx_stream := pcie.default_tx_stream;
	signal fifo: fifo_packet := init_fifo_packet;
	signal status: fifo_status := ((others => '0'), '0');

	signal config: fpga_tx_config_t := init_config;

	signal o_pkt: pcie.fragment := pcie.default_fragment;
	signal o_vld, o_req, fifo_req, fifo_in_vld, fifo_in_req: std_logic := '0';

begin

clk <= not clk after clk_period/2 * 1 ns;

o_req <= '1';
main: process
	variable rqst: rqst32 := init_rqst32;
begin
	test_runner_setup(runner, runner_cfg);
	while test_suite loop
		if run("test_single_dw") then
			check_relation(config.addr_mode = ADDR_32BIT);
			check_equal(o_req, '1');
			--check_equal(fifo_req, '0', "Fifo req is not 0 in line 58");
			wait until rising_edge(clk) and fifo_in_req = '1';

			config.size_bytes <= to_unsigned(4, 32);
			config.addr <= test_addr;
			fifo_in_vld <= '1';
			fifo_in.payload <= (127 downto 32 => '1', 31 downto 0 => '1');
			fifo_in.cnt <= 3x"4";
			fifo_in.end_of_stream <= '0';
			wait until rising_edge(clk);

			config.size_bytes <= 32ux"0";
			fifo_in_vld <= '0';

			wait until rising_edge(clk) and o_vld = '1';

			check_equal(o_vld, '1');
			check_equal(o_pkt.sof, '1');
			check_equal(o_pkt.eof, '1');
			check_equal(o_pkt.keep, std_logic_vector'("1111"));
			check_relation(get_type(o_pkt) = MWr32_desc);
			rqst := get_rqst32(o_pkt.data);
			check_equal(rqst.dw0.length, 1);
			check_equal(rqst.dw0.chn_id, chn_id);
			check_equal(rqst.dw1.first_be, std_logic_vector'("1111"));
			check_equal(rqst.dw1.last_be, std_logic_vector'("0000"));
			check_equal(rqst.dw2.address, x"0000_0000" & test_addr(31 downto 0));
			info(to_string(get_dword(o_pkt, 3)));
			info(to_string(get_dword(o_pkt, 2)));
			info(to_string(get_dword(o_pkt, 1)));
			info(to_string(get_dword(o_pkt, 0)));
			check_equal(get_dword(o_pkt, 3), std_logic_vector'(32Sb"1"));

			check_equal(fifo_req, '0');
			wait until rising_edge(clk) and (??o_vld);

			check_equal(o_vld, '1');
			check_relation(get_type(o_pkt) = MSIX_desc);
			wait until rising_edge(clk);

			check_equal(o_vld, '0');

		elsif run("test_header32") then
			for i in 0 to 300 loop
				check_equal(fifo_in_req, '1');
				fifo_in_vld <= '1';
				fifo_in.cnt <= 3x"4";
				fifo_in.payload( 31 downto  0) <= std_logic_vector(to_unsigned((i*4)+0, 32));
				fifo_in.payload( 63 downto 32) <= std_logic_vector(to_unsigned((i*4)+1, 32));
				fifo_in.payload( 95 downto 64) <= std_logic_vector(to_unsigned((i*4)+2, 32));
				fifo_in.payload(127 downto 96) <= std_logic_vector(to_unsigned((i*4)+3, 32));
				wait until rising_edge(clk);
			end loop;
			config.target<= TARGET_HOST;
			config.addr_mode <= ADDR_32BIT;
			config.size_bytes <= to_unsigned(1024, 32);
			wait until rising_edge(clk);


		end if;
	end loop;
	test_runner_cleanup(runner);
	wait;
end process main;
test_runner_watchdog(runner, 1 ms);

feeder: entity work.fpga_tx_fifo
port map(
	clk => clk,
	i => fifo_in,
	i_vld => fifo_in_vld,
	i_req => fifo_in_req,
	o => fifo,
	o_req => fifo_req,
	status => status
);

uut: entity work.sender_pack_data
generic map(id => chn_id, max_payload_bytes => max_payload)
port map(
	clk => clk,
	fifo => fifo,
	fifo_req => fifo_req,
	status => status,
	cfg => config,
	transferred => open,
	o => o_pkt,
	o_vld => o_vld,
	o_req => o_req
);
end architecture;
