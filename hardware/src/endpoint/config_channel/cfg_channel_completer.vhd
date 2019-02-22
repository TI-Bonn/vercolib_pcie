---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description:	Generates Memory Completions (CplD)
-- Version: 	0.1
---------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity cfg_channel_completer is
	port(
		clk          : in  std_ulogic;
		rst          : in  std_ulogic;

		-- cpld info input ports
		cpld_tag     : in  std_ulogic_vector( 7 downto 0);
		cpld_payload : in  std_ulogic_vector(31 downto 0);
		cpld_lo_addr : in  std_ulogic_vector( 6 downto 0);
		cpld_vld     : in  std_ulogic;
		cpld_done    : out std_ulogic := '0';

		-- output ports
		o            : out fragment := default_fragment;
		o_vld        : out std_ulogic := '0';
		o_req        : in  std_ulogic
	);
end cfg_channel_completer;

architecture arch of cfg_channel_completer is

type state_t is (RESET_CTRL, WAIT_FOR_CTRL);
signal state : state_t := WAIT_FOR_CTRL;

begin

main: process
begin
	wait until rising_edge(clk);
	if o_req = '1' then
		o_vld <= '0';
	end if;

	case state is
	when WAIT_FOR_CTRL =>
		if o_req = '1' and cpld_vld = '1' then
			o_vld <= '1';

			set_cpld_header(o, make_cpld(
				length => 1, chn_id => 0, byte_count => 4,
				tag => to_integer(unsigned(cpld_tag)), lower_addr => cpld_lo_addr
			));
			set_dw(o, 3, cpld_payload);

			-- reset controller, while sending completion
			cpld_done <= '1';
			state     <= RESET_CTRL;
		end if;

	-- wait controller to reset one clock cycle
	when RESET_CTRL =>
		cpld_done <= '0';
		if o_req = '1' then
			state <= WAIT_FOR_CTRL;
		end if;
	end case;

	if rst = '1' then
		cpld_done <= '0';
		state <= WAIT_FOR_CTRL;
		o_vld <= '0';
		o <= default_fragment;
	end if;

end process;

end architecture;
