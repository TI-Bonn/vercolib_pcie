library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie;
use work.transceiver_128bit_types.all;

entity type_tb is
end type_tb;

architecture arch of type_tb is


	subtype raw_header is std_logic_vector(128 - 1 downto 0);

	signal rqst32_raw: raw_header := (others => '0');
	signal rqst32_pkt: pcie.fragment := pcie.default_fragment;

	signal rqst64_raw: raw_header := (others => '0');
	signal rqst64_pkt: pcie.fragment := pcie.default_fragment;

	signal cpld_raw: raw_header := (others => '0');
	signal cpld_pkt: pcie.fragment := pcie.default_fragment;

	constant dw1Base : natural := 32;
	constant dw2Base : natural := 64;
	constant dw3Base : natural := 96;

	constant length:  natural := 1;
	constant tag:     natural := 5;
	constant chn_id:  natural := 0;
	constant req_id:  natural := 7;
	constant f_be:    natural := 4;
	constant l_be:    natural := 3;
	constant addrlo:  natural := 55;
	constant addrhi:  natural := 44;
	constant bc:      natural := 100;
	constant lowaddr: natural := 4;

	function as_int(data: std_logic_vector) return integer is
	begin
		return to_integer(unsigned(data));
	end as_int;

	procedure set_int(ret: out std_logic_vector; data: in integer) is
	begin
		ret := std_logic_vector(to_unsigned(data, ret'length));
	end set_int;

	function make_raw_rqst32 return std_logic_vector is
		variable ret: std_logic_vector(127 downto 0) := (others => '0');
	begin
		ret(3 downto 0) := MRd32_desc;
		set_int(ret(15 downto  6), length);
		set_int(ret(23 downto 16), tag);
		set_int(ret(31 downto 24), chn_id);

		set_int(ret(15 + dw1Base downto      dw1Base), req_id);
		set_int(ret(19 + dw1Base downto 16 + dw1Base), f_be);
		set_int(ret(23 + dw1Base downto 20 + dw1Base), l_be);

		set_int(ret(95 downto 64), addrlo);
		return ret;
	end make_raw_rqst32;

	function make_raw_rqst64 return std_logic_vector is
		variable ret: std_logic_vector(127 downto 0) := (others => '0');
	begin
		ret := make_raw_rqst32;
		ret(3 downto 0) := MRd64_desc;
		set_int(ret(127 downto 96), addrhi);
		return ret;
	end make_raw_rqst64;

	function make_raw_cpld return std_logic_vector is
		variable ret: std_logic_vector(127 downto 0) := (others => '0');
	begin
		ret := (others => '0');
		ret( 3 downto  0) := CplD_desc;
		set_int(ret(15 downto  6), length);
		set_int(ret(23 downto 16), tag);
		set_int(ret(31 downto 24), chn_id);

		set_int(ret(15 + dw1Base downto      dw1Base), req_id);
		set_int(ret(23 + dw1Base downto 16 + dw1Base), bc);

		set_int(ret( 6 + dw2Base downto dw2Base), lowaddr);
		return ret;
	end make_raw_cpld;

	function assert_common_header(dw: common_dw0; desc: descriptor_t) return boolean is
	begin
		assert dw.desc = desc
			report "Desc wrong" severity failure;
		assert as_int(dw.length) = length
			report "Length wrong" severity failure;
		assert as_int(dw.tag) = tag
			report "Tag wrongin" severity failure;
		assert as_int(dw.chn_id) = chn_id
			report "Chn_ID wrong" severity failure;
		return true;
	end assert_common_header;

	function assert_rqst_dw1(dw: rqst_dw1) return boolean is
	begin
		assert as_int(dw.requester_id) = req_id
			report "Requester ID wrong in rqst" severity failure;
		assert as_int(dw.first_be) = f_be
			report "First Byte Enable wrong in rqst" severity failure;
		assert as_int(dw.last_be) = l_be
			report "Last Byte Enable wrong in rqst" severity failure;
		return true;
	end assert_rqst_dw1;

	function assert_rqst32(pkt: pcie.fragment) return boolean is
		variable rqst: rqst32 := get_rqst32(pkt.data);
	begin
		assert pkt.keep = "0111"
			report "Keep is not set correctly in rqst32"
			severity failure;

		assert pkt.sof = '1'
			report "SOF is not set correctly in rqst32"
			severity failure;

		assert pkt.eof = '1'
			report "EOF is not set correctly in rqst32"
			severity failure;

		if not assert_common_header(rqst.dw0, MRd32_desc) then
			return false;
		end if;

		if not assert_rqst_dw1(rqst.dw1) then
			return false;
		end if;


		assert as_int(rqst.dw2.address) = addrlo
			report "Low Addr DW wrong in rqst32"
			severity error;

		return true;
	end assert_rqst32;

	function assert_rqst64(pkt: pcie.fragment) return boolean is
		variable rqst: rqst64 := get_rqst64(pkt.data);
	begin
		assert pkt.keep = "1111"
			report "Keep is not set correctly in rqst64"
			severity failure;

		assert pkt.sof = '1'
			report "SOF is not set correctly in rqst64"
			severity failure;

		assert pkt.eof = '1'
			report "EOF is not set correctly in rqst64"
			severity failure;

		if not assert_common_header(rqst.dw0, MRd64_desc) then
			return false;
		end if;

		if not assert_rqst_dw1(rqst.dw1) then
			return false;
		end if;

		assert as_int(rqst.dw2.address_hi) = addrlo
			report "Low Addr DW wrong in rqst64"
			severity failure;

		assert as_int(rqst.dw3.address_lo) = addrhi
			report "High Addr DW wrong in rqst64"
			severity failure;

		return true;
	end assert_rqst64;

	function assert_cpld(pkt: pcie.fragment) return boolean is
		variable cpl: cpld := get_cpld(pkt.data);
	begin
		assert pkt.keep = "0111"
			report "Keep is not set correctly in cpld"
			severity failure;

		assert pkt.sof = '1'
			report "SOF is not set correctly in cpld"
			severity failure;

		assert pkt.eof = '1'
			report "EOF is not set correctly in cpld"
			severity failure;

		if not assert_common_header(cpl.dw0, CplD_desc) then
			return false;
		end if;

		assert as_int(cpl.dw1.completer_id) = req_id
			report "Completer ID wrong in cpld"
			severity failure;
		assert as_int(cpl.dw1.byte_count) = bc
			report "Byte Count wrong in cpld"
			severity failure;

		assert as_int(cpl.dw2.lower_addr) = lowaddr
			report "Lower Address wrong in cpld"
			severity failure;

		return true;

	end assert_cpld;

begin

	main: process is
	begin
		rqst32_raw <= make_raw_rqst32;
		rqst64_raw <= make_raw_rqst64;
		cpld_raw <= make_raw_cpld;

		wait for 5 ns;

		set_rqst32_header(rqst32_pkt, get_rqst32(rqst32_raw));
		set_rqst64_header(rqst64_pkt, get_rqst64(rqst64_raw));
		set_cpld_header(cpld_pkt, get_cpld(cpld_raw));

		wait for 5 ns;

		assert assert_rqst32(rqst32_pkt) severity failure;
		assert assert_rqst64(rqst64_pkt) severity failure;
		assert assert_cpld(cpld_pkt) severity failure;

		wait for 5 ns;

		assert rqst32_pkt.data = rqst32_raw
			report "Rqst32 is not the same after conversion"
			severity failure;

		assert rqst64_pkt.data = rqst64_raw
			report "Rqst64 is not the same after conversion"
			severity failure;

		assert cpld_pkt.data = cpld_raw
			report "CplD is not the same after conversion"
			severity failure;

		wait for 5 ns;

		assert false report "Simulation finished" severity failure;
	end process;
end architecture;
