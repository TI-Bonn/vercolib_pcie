---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description:	checks if incoming MWr or MRd is send to config_channel (id = 0)
--				and decodes opcode for further processing
-- Version: 	0.1
---------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity cfg_channel_decoder is
	port(
		clk      : in  std_ulogic;
		rst      : in  std_ulogic;

		i        : in  fragment;
		i_vld    : in  std_ulogic;
		i_req    : out std_ulogic := '1';

		op_code  : out op_code_t;
		op_addr  : out cfg_reg_addr_t := 0;
		op_data  : out std_ulogic_vector(31 downto 0) := (others => '0');
		op_tag   : out std_ulogic_vector(7 downto 0);
		op_vld   : out std_ulogic := '0';
		op_ready : in  std_ulogic := '0'
	);
end cfg_channel_decoder;

architecture arch of cfg_channel_decoder is
	signal bar_addr : cfg_reg_addr_t;
begin

-- possible race condition if two host instructions are sent to config channel in consecutive clock cycles
-- should never occur because of host-fpga communication protocol
i_req <= op_ready;

bar_addr <= to_integer(unsigned(get_rqst32(i.data).dw2.address(5 downto 2)));

main: process
begin
	wait until rising_edge(clk);
	if op_ready = '1' then
		-- considering only MWr and MRd with 3DW header because BAR registers are mapped
		-- to 32 Bit addresses; channel_id of config channel is 0
		op_vld <= '0';
		if i.sof = '1' and get_rqst32(i.data).dw0.chn_id = x"00" then
			op_vld <= i_vld;
		end if;

		case get_type(i) is
		when MWr32_desc => op_code <= INSTR when bar_addr = 7 else WR_REG;
		when MRd32_desc => op_code <= RD_REG;
		when others =>     op_code <= INVALID;
		end case;

		op_addr <= bar_addr;                   -- BAR-address
		op_data <= get_dword(i, 3);            -- data to be written
		op_tag  <= get_rqst32(i.data).dw0.tag; -- needed only for CplD generation
	end if;
	if rst = '1' then
		op_vld  <= '0';
		op_addr <= 0;
		op_data <= (others => '0');
		op_tag  <= (others => '0');
		op_code <= INVALID;
	end if;
end process;

end architecture;
