---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description:
-- Version: 	0.1
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.transceiver_128bit_types.all;

package cfg_channel_types is

	subtype cfg_reg_addr_t is natural range 0 to 15;
	-- BAR-address encoding:
	-- registers 0 to 7 are the same for every channel
	constant MSG_BUFFER_ADDR_LOW    : cfg_reg_addr_t := 0;
	constant MSG_BUFFER_ADDR_HIGH   : cfg_reg_addr_t := 1;
	constant MSG_BUFFER_SIZE        : cfg_reg_addr_t := 2;
	constant ADDR_3_UNUSED          : cfg_reg_addr_t := 3;
	constant MSG_BUFFER_TRANSFERRED : cfg_reg_addr_t := 4;
	constant ADDR_5_UNUSED          : cfg_reg_addr_t := 5;
	constant ADDR_6_UNUSED          : cfg_reg_addr_t := 6;
	constant HOST_INSTR             : cfg_reg_addr_t := 7;
	-- registers 8 to 15 are channel specific
	constant FPGA_ID                : cfg_reg_addr_t := 8;
	constant CORE_ID                : cfg_reg_addr_t := 9;
	constant NUM_CHANNEL            : cfg_reg_addr_t := 10;
	constant ADDR_11_UNUSED         : cfg_reg_addr_t := 11;
	constant ADDR_12_UNUSED         : cfg_reg_addr_t := 12;
	constant ADDR_13_UNUSED         : cfg_reg_addr_t := 13;
	constant ADDR_14_UNUSED         : cfg_reg_addr_t := 14;
	constant ADDR_15_UNUSED         : cfg_reg_addr_t := 15;

	-- host instructions are encoded with an one-hot scheme in MWr-payload (DW3),
	-- if host writes to register HOST_INSTR
	subtype host_instr_idx_t is natural range 0 to 31;
	constant RESET_TRANSCEIVER  : host_instr_idx_t := 0;
	constant RESET_HOST_CHANNEL : host_instr_idx_t := 1;
	constant RESET_FPGA_CHANNEL : host_instr_idx_t := 2;

	type op_code_t is (RD_REG, WR_REG, INSTR, INVALID);
end package cfg_channel_types;

package body cfg_channel_types is

end package body cfg_channel_types;
