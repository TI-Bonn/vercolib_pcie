-- Sender cfg ctrl types
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.host_types.all;

package sender_cfg_ctrl_types is
	type target_mode_t is (TARGET_FPGA, TARGET_HOST);
	type addr_mode_t is (ADDR_32BIT, ADDR_64BIT);

	type fpga_tx_config_t is record
		target: target_mode_t;
		trigger_cpld: boolean;
		addr_mode: addr_mode_t;
		addr: u64;
		size_bytes: u32;
		cpld_tag: u8;
		cpld_offs: u8;
	end record;
	constant init_config: fpga_tx_config_t := (
		target => TARGET_HOST,
		trigger_cpld => false,
		addr_mode => ADDR_32BIT,
		addr => (others => '0'),
		size_bytes => (others => '0'),
		cpld_tag => (others => '0'),
		cpld_offs => (others => '0')
	);
end package;

