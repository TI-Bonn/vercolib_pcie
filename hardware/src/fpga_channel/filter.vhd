-- Generic Channel Filter
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fpga_filter_pkg is
	type filter_packet is record
		address: unsigned( 3 downto 0);
		payload: unsigned(31 downto 0);
	end record;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


use work.pcie.all;
use work.fpga_filter_pkg.all;
use work.transceiver_128bit_types.all;

entity fpga_tx_filter is
generic(id: positive := 2);
port(
	clk: in std_logic;

	i_pkt: in  fragment;
	i_vld: in  std_logic;
	i_req: out std_logic := '0';

	o_pkt: out filter_packet := (
		address => (others => '0'),
		payload => (others => '0'));
	o_vld: out std_logic := '0';
	o_req: in  std_logic);
end entity;

architecture arch of fpga_tx_filter is
	impure function id_is_ok return boolean is
		variable rqst: rqst32 := init_rqst32;
		variable addr: unsigned(6 - 1 downto 0);
	begin
		rqst := get_rqst32(i_pkt.data);
		addr := unsigned(rqst.dw2.address(5+6 downto 6));
		return addr = id;
	end id_is_ok;

	impure function type_is_ok return boolean is
		variable t: descriptor_t;
	begin
		t := get_type(i_pkt);
		return t = MWr32_desc or t = MRd32_desc;
	end type_is_ok;
begin

i_req <= o_req;

main: process is
begin
	wait until rising_edge(clk) and o_req = '1';

	o_vld <= '0';
	if i_pkt.sof = '1' and type_is_ok and id_is_ok then
		o_vld <= i_vld;
	end if;

	o_pkt.address <= unsigned(get_rqst32(i_pkt.data).dw2.address(5 downto 2));
	if get_type(i_pkt) = MRd32_desc then
		o_pkt.payload <= resize(unsigned(get_rqst32(i_pkt.data).dw0.tag), 32);
	else
		o_pkt.payload <= unsigned(get_dword(i_pkt, 3));
	end if;

end process;


end architecture;
