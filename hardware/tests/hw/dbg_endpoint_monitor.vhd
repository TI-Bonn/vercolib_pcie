library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dbg_types.all;

entity endpoint_counter_dbg is
	port(
		clk : in std_logic;
		rst : in std_logic;

		msix_vld : in boolean;
		msix_cnt : out counter_width_t
	);
end entity endpoint_counter_dbg;

architecture RTL of endpoint_counter_dbg is
begin
	process
	begin
		wait until rising_edge(clk);
		increment_cnt(rst, msix_cnt, msix_vld);
	end process;
end architecture RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie;
use work.dbg_types;

entity endpoint_monitor_dbg is
	port(
		clk : in std_logic;
		rst : in std_logic;

		msix_tlpmux_data : in pcie.fragment;
		msix_tlpmux_vld  : in std_logic;
		msix_tlpmux_req  : in std_logic
	);
end entity endpoint_monitor_dbg;

architecture RTL of endpoint_monitor_dbg is
	attribute mark_debug : string;
	attribute dont_touch : string;

	signal msix_vld : boolean;
	signal msix_cnt : dbg_types.counter_width_t;
	
	attribute dont_touch of msix_vld : signal is "true";
	attribute dont_touch of msix_cnt : signal is "true";
	attribute dont_touch of msix_tlpmux_data : signal is "true";

	attribute mark_debug of msix_vld : signal is "true";
	attribute mark_debug of msix_cnt : signal is "true";
	attribute mark_debug of msix_tlpmux_data : signal is "true";

begin

	process
	begin
		wait until rising_edge(clk);
		msix_vld <= true when msix_tlpmux_vld = '1' and msix_tlpmux_req = '1' else false;
	end process;
	
	cnt: entity work.endpoint_counter_dbg
		port map(
			clk      => clk,
			rst      => rst,
			msix_vld => msix_vld,
			msix_cnt => msix_cnt
		);
end architecture RTL;
