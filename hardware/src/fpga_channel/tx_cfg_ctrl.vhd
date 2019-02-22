-- Config state machine for send_controller
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.host_types.all;
use work.fpga_filter_pkg.all;
use work.sender_cfg_ctrl_types.all;

entity sender_cfg_ctrl is
port(
	clk: in std_logic;

	i: in filter_packet;
	i_vld: in  std_logic;
	i_req: out std_logic;

	cfg: out fpga_tx_config_t := init_config);
end entity;

architecture arch of sender_cfg_ctrl is
begin


i_req <= '1';
process
begin
	wait until rising_edge(clk);

	-- NOTE(sebastian): Sending data starts automatically if size_bytes != 0.
	cfg.size_bytes   <= resize("0", 32);
	cfg.trigger_cpld <= false;

	if i_vld = '1' then
		case i.address is
		when x"0" =>
			cfg.addr(31 downto 0) <= i.payload;
			cfg.addr_mode <= ADDR_32BIT;
		when x"1" =>
			cfg.addr(63 downto 32) <= i.payload;
			cfg.addr_mode <= ADDR_64BIT;
		when x"2" =>
			cfg.size_bytes <= i.payload;
		when x"3" =>
			cfg.target    <= TARGET_FPGA when i.payload /= 0 else
			                 TARGET_HOST;
			cfg.addr_mode <= ADDR_32BIT;
		when x"4" =>
			cfg.trigger_cpld <= true;
			cfg.cpld_tag     <= i.payload(7 downto 0);
			cfg.cpld_offs    <= to_unsigned(4, 8);
		when others => null;
		end case;
	end if;
end process;


end architecture;
