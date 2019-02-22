-- Build cplds for send channel
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

package fpga_tx_write_cpld_types is
	type state_t is (INIT, SEND);

	type cpld_info_t is record
		state: state_t;
	end record;
	constant init_cpld_info: cpld_info_t := (state => INIT);
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie.all;
use work.host_types.all;
use work.transceiver_128bit_types.all;

use work.fpga_tx_write_cpld_types.all;
use work.sender_cfg_ctrl_types.all;

entity fpga_tx_write_cpld is
generic(
	id: natural := 2);
port(
	clk:  in  std_logic;
	cfg:  in  fpga_tx_config_t;

	data: in u32;

	o:     out fragment;
	o_vld: out std_logic;
	o_req: in  std_logic);
end entity;

architecture arch of fpga_tx_write_cpld is

	impure function build_lower_addr return std_logic_vector is
		variable ret: std_logic_vector(6 downto 0) := (others => '0');
	begin
		ret(6) := to_unsigned(id, 32)(0);
		ret(5 downto 2) := std_logic_vector(cfg.cpld_offs(3 downto 0));
		return ret;
	end build_lower_addr;

	signal info: cpld_info_t := init_cpld_info;
begin

process
begin
	wait until rising_edge(clk);

	if o_req = '1' then
		o_vld <= '0';
		reset(o);
	end if;

	case info.state is
	when INIT =>
		if cfg.trigger_cpld then
			info.state <= SEND;
		end if;
	when SEND =>
		if o_req = '1' then
			o_vld <= '1';
			set_cpld_header(o, make_cpld(
				length => 1, chn_id => id, byte_count => 4,
				tag => to_integer(cfg.cpld_tag), lower_addr => build_lower_addr
			));
			set_dw(o, 3, std_logic_vector(data));
			o.eof <= '1';
			info.state <= INIT;
		end if;
	end case;
end process;

end architecture;
