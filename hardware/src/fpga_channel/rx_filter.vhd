-- Filter incoming packets for cfg and data
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.fpga_filter_pkg.all;

entity fpga_rx_filter is
generic(id: natural);
port(
	clk: in std_logic;

	i:     in  fragment;
	i_vld: in  std_logic;
	i_req: out std_logic := '1';

	cfg: out filter_packet := ((others => '0'),(others => '0'));
	cfg_vld: out std_logic := '0';

	data:     out fragment := default_fragment;
	data_vld: out std_logic := '0';
	data_req: in  std_logic);
end entity;

architecture arch of fpga_rx_filter is
	signal data_active: boolean := false;

	impure function id_is_ok return boolean is
		variable rqst: rqst32 := init_rqst32;
		variable addr: unsigned(6 - 1 downto 0);
	begin
		rqst := get_rqst32(i.data);
		addr := unsigned(rqst.dw2.address(5+6 downto 6));
		return addr = id;
	end id_is_ok;

	impure function type_is_ok return boolean is
		variable t: descriptor_t;
	begin
		t := get_type(i);
		return t = MWr32_desc or t = MRd32_desc;
	end type_is_ok;

	impure function is_data_offset return boolean is
		variable rqst: rqst32 := init_rqst32;
		variable offs: unsigned(3 downto 0) := (others => '0');
	begin
		rqst := get_rqst32(i.data);
		offs := unsigned(rqst.dw2.address(5 downto 2));
		return offs = "1111";
	end is_data_offset;
begin

i_req <= data_req;

process
	variable ok_for_data: boolean := false;
begin
	wait until rising_edge(clk) and data_req = '1';

	data.data <= i.data;
	data.keep <= i.keep;
	data.eof  <= i.eof;
	data.sof  <= i.sof;

	cfg.address <= unsigned(get_rqst32(i.data).dw2.address(5 downto 2));
	cfg.payload <= unsigned(get_dword(i,3));


	cfg_vld  <= i_vld when is_header(i) and is_last(i) and
	                       id_is_ok and type_is_ok and not is_data_offset else
	            '0';

	ok_for_data := is_header(i) and id_is_ok and type_is_ok and is_data_offset;

	data_vld <= i_vld when data_active or ok_for_data else
	            '0';

	data_active <= false when i_vld and i.eof else
	               true  when i_vld = '1' and ok_for_data else
	               data_active;

end process;

end architecture arch;

