-- Receiver cfg trl
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.host_types.all;

package fpga_rx_cfg_ctrl_types is
	type target_mode_t is (TARGET_NONE, TARGET_FPGA);
	type fpga_rx_config_t is record
		target: target_mode_t;
		addr: u32;
	end record;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fpga_rx_cfg_ctrl_types.all;
use work.fpga_filter_pkg.all;

entity fpga_rx_cfg_ctrl is
port(
	clk: in std_logic;

	i: in filter_packet;
	i_vld: in std_logic;

	cfg: out fpga_rx_config_t);
end entity;

architecture arch of fpga_rx_cfg_ctrl is
begin

process
begin
	wait until rising_edge(clk);

	if i_vld then
		case i.address is
		when x"0" => cfg.addr <= i.payload;
		when x"3" => cfg.target <= TARGET_FPGA when i.payload /= 0 else
		                           TARGET_NONE;
		when others => null;
		end case;
	end if;
end process;

end architecture arch;
