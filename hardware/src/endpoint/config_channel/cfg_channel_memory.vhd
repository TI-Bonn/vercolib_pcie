---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description:	contains and provides configuration data for the whole transceiver
--				can only read or write in one clock cycle
-- Version: 	0.1
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.host_types.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity cfg_channel_memory is
	generic(
		fpga_id_c         : dword := x"ABCDABCD";
		core_id_c         : dword := x"01230123";
		num_rx_host_cnl_c : natural := 0;
		num_tx_host_cnl_c : natural := 0;
		num_rx_fpga_cnl_c : natural := 0;
		num_tx_fpga_cnl_c : natural := 0
	);
	port(
		clk      : in  std_ulogic;
		rst      : in  std_ulogic;

		addr     : in  cfg_reg_addr_t := 0;
		wr_data  : in  std_ulogic_vector(31 downto 0) := (others => '0');
		wr_en    : in  std_ulogic := '0';
		rd_data  : out std_ulogic_vector(31 downto 0) := (others => '0');
		rd_en    : in  std_ulogic := '0'
	);
end cfg_channel_memory;

architecture arch of cfg_channel_memory is

	type ram_8_t is array (0 to 7) of std_logic_vector(7 downto 0);
	signal cfg_ram_8 : ram_8_t := (others => (others => '0'));

begin

main: process
begin
	wait until rising_edge(clk);
	rd_data <= (others => '0');

	case addr is
	when 0 to 7 =>
		if wr_en = '1' then
			cfg_ram_8(addr) <= wr_data(7 downto 0);
		elsif rd_en = '1' then
			rd_data(7 downto 0) <= cfg_ram_8(addr);
		end if;

	-- read 32 bit static value
	when FPGA_ID     => rd_data <= fpga_id_c;
	when CORE_ID     => rd_data <= core_id_c;

	when NUM_CHANNEL => rd_data <= std_ulogic_vector(to_unsigned(num_tx_fpga_cnl_c, 8)) &
	                               std_ulogic_vector(to_unsigned(num_rx_fpga_cnl_c, 8)) &
	                               std_ulogic_vector(to_unsigned(num_tx_host_cnl_c, 8)) &
	                               std_ulogic_vector(to_unsigned(num_rx_host_cnl_c, 8));

	when others => rd_data <= (others => '0');
	end case;

	if rst = '1' then
		rd_data <= (others => '0');
	end if;
end process;

end architecture;
