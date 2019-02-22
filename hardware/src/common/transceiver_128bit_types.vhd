-- Package for transceiver type definitions
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.host_types.dword;
use work.pcie.fragment;
use work.pcie.default_fragment;
use work.pcie.fragment_vector;

package transceiver_128bit_types is
	subtype  descriptor_t is std_logic_vector(3 downto 0);
	constant MWr32_desc  : descriptor_t := "0000";
	constant MWr64_desc  : descriptor_t := "1000";
	constant MRd32_desc  : descriptor_t := "0001";
	constant MRd64_desc  : descriptor_t := "1001";
	constant CplD_desc   : descriptor_t := "0010";
	constant MSIX_desc   : descriptor_t := "1100";

	type common_dw0 is record
		desc   : descriptor_t;
		length : std_logic_vector(9 downto 0);
		tag    : std_logic_vector(7 downto 0);
		chn_id : std_logic_vector(7 downto 0);
	end record;

	type rqst_dw1 is record
		requester_id : std_logic_vector(15 downto 0);
		first_be     : std_logic_vector( 3 downto 0);
		last_be      : std_logic_vector( 3 downto 0);
	end record;

	subtype tlp_addr_lo is std_logic_vector(31 downto 0);
	type rqst32_dw2 is record
		address : tlp_addr_lo;
	end record;

	type rqst64_dw2 is record
		address_hi : dword;
	end record;

	type rqst64_dw3 is record
		address_lo : tlp_addr_lo;
	end record;

	type cpld_dw1 is record
		completer_id : std_logic_vector(15 downto 0);
		byte_count   : std_logic_vector(11 downto 0);
	end record;

	type cpld_dw2 is record
		lower_addr : std_logic_vector(6 downto 0);
	end record;


	function init_common_dw0 return common_dw0;
	function init_rqst_dw1 return rqst_dw1;
	function init_rqst32_dw2 return rqst32_dw2;
	function init_rqst64_dw2 return rqst64_dw2;
	function init_rqst64_dw3 return rqst64_dw3;
	function init_cpld_dw1 return cpld_dw1;
	function init_cpld_dw2 return cpld_dw2;

	function to_common_dw0(data: dword) return common_dw0;
	function to_rqst_dw1(data: dword) return rqst_dw1;
	function to_rqst32_dw2(data: dword) return rqst32_dw2;
	function to_rqst64_dw2(data: dword) return rqst64_dw2;
	function to_rqst64_dw3(data: dword) return rqst64_dw3;
	function to_cpld_dw1(data: dword) return cpld_dw1;
	function to_cpld_dw2(data: dword) return cpld_dw2;

	function to_dword(data: common_dw0) return dword;
	function to_dword(data: rqst_dw1) return dword;
	function to_dword(data: rqst32_dw2) return dword;
	function to_dword(data: rqst64_dw2) return dword;
	function to_dword(data: rqst64_dw3) return dword;
	function to_dword(data: cpld_dw1) return dword;
	function to_dword(data: cpld_dw2) return dword;



	type rqst32 is record
		dw0 : common_dw0;
		dw1 : rqst_dw1;
		dw2 : rqst32_dw2;
	end record;

	type rqst64 is record
		dw0 : common_dw0;
		dw1 : rqst_dw1;
		dw2 : rqst64_dw2;
		dw3 : rqst64_dw3;
	end record;

	type cpld is record
		dw0 : common_dw0;
		dw1 : cpld_dw1;
		dw2 : cpld_dw2;
	end record;

	function slv_to_packet(data: std_logic_vector) return fragment;
	function packet_to_slv(data: fragment) return std_logic_vector;

	function init_rqst32 return rqst32;
	function init_rqst64 return rqst64;
	function init_cpld   return cpld;

	procedure set_rqst32_header(signal data: out std_logic_vector; rqst: in rqst32);
	procedure set_rqst64_header(signal data: out std_logic_vector; rqst: in rqst64);
	procedure set_cpld_header(signal data: out std_logic_vector; cpl: in cpld);

	procedure set_rqst32_header(signal pkt: out fragment; header: in rqst32);
	procedure set_rqst64_header(signal pkt: out fragment; header: in rqst64);
	procedure set_cpld_header(signal pkt: out fragment; header: in cpld);

	procedure set_dw(signal pkt: out fragment; idx: natural; data: dword);

	procedure reset(signal pkt: out fragment);

	function get_rqst32(data: std_logic_vector) return rqst32;
	function get_rqst64(data: std_logic_vector) return rqst64;
	function get_cpld(data: std_logic_vector) return cpld;

	function is_header(pkt: fragment) return boolean;
	function is_last(pkt:fragment) return boolean;

	function get_type(pkt: fragment) return descriptor_t;
	function get_dword(pkt: fragment; dw_idx: natural) return dword;

	function is_read_rqst(pkt: fragment) return boolean;
	function is_write_rqst(pkt: fragment) return boolean;
	function is_32bit_rqst(pkt: fragment) return boolean;
	function is_64bit_rqst(pkt: fragment) return boolean;

	function make_wr_rqst32(
		length, chn_id: natural;
		address: dword
	) return rqst32;

	function make_wr_rqst64(
		length, chn_id:   natural;
		addr_lo, addr_hi: dword
	) return rqst64;

	function make_rd_rqst32(
		length, chn_id, tag: natural;
		address: dword
	) return rqst32;

	function make_rd_rqst64(
		length, chn_id, tag: natural;
		addr_lo, addr_hi: dword
	) return rqst64;

	function make_cpld(
		length, chn_id, tag, byte_count: natural;
		lower_addr: std_logic_vector
	) return cpld;

	procedure set_length(signal pkt: out fragment; variable len: in std_logic_vector(9 downto 0));

end transceiver_128bit_types;

package body transceiver_128bit_types is

	function init_common_dw0 return common_dw0 is
		variable data : common_dw0;
	begin
		data.desc   := MRd32_desc;
		data.length := (others => '0');
		data.tag    := (others => '0');
		data.chn_id := (others => '0');
		return data;
	end init_common_dw0;

	function init_rqst_dw1 return rqst_dw1 is
		variable data : rqst_dw1;
	begin
		data.first_be := (others => '0');
		data.last_be  := (others => '0');
		data.requester_id      := (others => '0');
		return data;
	end init_rqst_dw1;

	function init_rqst32_dw2 return rqst32_dw2 is
		variable data : rqst32_dw2;
	begin
		data.address := (others => '0');
		return data;
	end init_rqst32_dw2;

	function init_rqst64_dw2 return rqst64_dw2 is
		variable data : rqst64_dw2;
	begin
		data.address_hi := (others => '0');
		return data;
	end init_rqst64_dw2;

	function init_rqst64_dw3 return rqst64_dw3 is
		variable data : rqst64_dw3;
	begin
		data.address_lo := (others => '0');
		return data;
	end init_rqst64_dw3;


	function init_cpld_dw1 return cpld_dw1 is
		variable data :  cpld_dw1;
	begin
		data.completer_id := (others => '0');
		data.byte_count   := (others => '0');
		return data;
	end init_cpld_dw1;

	function init_cpld_dw2 return cpld_dw2 is
		variable data : cpld_dw2;
	begin
		data.lower_addr := (others => '0');
		return data;
	end init_cpld_dw2;



	function to_common_dw0(data: dword) return common_dw0 is
		variable ret : common_dw0 := init_common_dw0;
	begin
		ret.desc   := data( 3 downto  0);
		ret.length := data(15 downto  6);
		ret.tag    := data(23 downto 16);
		ret.chn_id := data(31 downto 24);
		return ret;
	end to_common_dw0;

	function to_rqst_dw1(data: dword) return rqst_dw1 is
		variable ret : rqst_dw1;
	begin
		ret.requester_id := data(15 downto  0);
		ret.first_be     := data(19 downto 16);
		ret.last_be      := data(23 downto 20);
		return ret;
	end to_rqst_dw1;

	function to_rqst32_dw2(data: dword) return rqst32_dw2 is
		variable ret: rqst32_dw2;
	begin
		ret.address := data(31 downto 0);
		return ret;
	end to_rqst32_dw2;

	function to_rqst64_dw2(data: dword) return rqst64_dw2 is
		variable ret: rqst64_dw2;
	begin
		ret.address_hi := data(31 downto 0);
		return ret;
	end to_rqst64_dw2;

	function to_rqst64_dw3(data: dword) return rqst64_dw3 is
		variable ret: rqst64_dw3;
	begin
		ret.address_lo := data(31 downto 0);
		return ret;
	end to_rqst64_dw3;

	function to_cpld_dw1(data: dword) return cpld_dw1 is
		variable ret : cpld_dw1;
	begin
		ret.completer_id := data(15 downto  0);
		ret.byte_count   := data(27 downto 16);
		return ret;
	end to_cpld_dw1;

	function to_cpld_dw2(data: dword) return cpld_dw2 is
		variable ret: cpld_dw2 := init_cpld_dw2;
	begin
		ret.lower_addr := data( 6 downto  0);
		return ret;
	end to_cpld_dw2;

	function to_dword(data: common_dw0) return dword is
		variable ret : dword := (others => '0');
	begin
		ret( 3 downto  0) := data.desc;
		ret(15 downto  6) := data.length;
		ret(23 downto 16) := data.tag;
		ret(31 downto 24) := data.chn_id;
		return ret;
	end to_dword;

	function to_dword(data: rqst_dw1) return dword is
		variable ret : dword := (others => '0');
	begin
		ret(15 downto  0) := data.requester_id;
		ret(19 downto 16) := data.first_be;
		ret(23 downto 20) := data.last_be;
		return ret;
	end to_dword;

	function to_dword(data: rqst32_dw2) return dword is
		variable ret: dword := (others => '0');
	begin
		ret(31 downto 0) := data.address;
		return ret;
	end to_dword;

	function to_dword(data: rqst64_dw2) return dword is
		variable ret: dword := (others => '0');
	begin
		ret(31 downto 0) := data.address_hi;
		return ret;
	end to_dword;

	function to_dword(data: rqst64_dw3) return dword is
		variable ret: dword := (others => '0');
	begin
		ret := data.address_lo;
		return ret;
	end to_dword;

	function to_dword(data: cpld_dw1) return dword is
		variable ret : dword;
	begin
		ret := (others => '0');
		ret(15 downto  0) := data.completer_id;
		ret(27 downto 16) := data.byte_count;
		return ret;
	end to_dword;

	function to_dword(data: cpld_dw2) return dword is
		variable ret : dword;
	begin
		ret := (others => '0');
		ret(6 downto 0)  := data.lower_addr;
		return ret;
	end to_dword;

	function slv_to_packet(data : std_logic_vector) return fragment is
		variable ret : fragment;
	begin
		ret      := default_fragment;
		ret.keep := data(133 downto 130);
		ret.sof  := data(129);
		ret.eof  := data(128);
		ret.data := data(127 downto 0);
		return ret;
	end slv_to_packet;

	function packet_to_slv(data : fragment) return std_logic_vector is
		variable ret : std_logic_vector(133 downto 0);
	begin
		ret               	:= (others => '0');
		ret(127 downto 0) 	:= data.data;
		ret(128)          	:= data.eof;
		ret(129)          	:= data.sof;
		ret(133 downto 130) := data.keep;
		return ret;
	end packet_to_slv;


	function init_rqst32 return rqst32 is
		variable data : rqst32;
	begin
		data.dw0 := init_common_dw0;
		data.dw1 := init_rqst_dw1;
		data.dw2 := init_rqst32_dw2;
		return data;
	end init_rqst32;

	function init_rqst64 return rqst64 is
		variable data : rqst64;
	begin
		data.dw0 := init_common_dw0;
		data.dw1 := init_rqst_dw1;
		data.dw2 := init_rqst64_dw2;
		data.dw3 := init_rqst64_dw3;
		return data;
	end init_rqst64;

	function init_cpld return cpld is
		variable data : cpld;
	begin
		data.dw0 := init_common_dw0;
		data.dw1 := init_cpld_dw1;
		data.dw2 := init_cpld_dw2;
		return data;
	end init_cpld;

	procedure set_rqst32_header(signal data: out std_logic_vector; rqst: in rqst32) is
	begin
		assert rqst.dw0.desc = MRd32_desc or rqst.dw0.desc = MWr32_desc
			report "Tried to set rqst32 header with non-rqst32 type"
			severity failure;

		data(31 downto  0) <= to_dword(rqst.dw0);
		data(63 downto 32) <= to_dword(rqst.dw1);
		data(95 downto 64) <= to_dword(rqst.dw2);
	end set_rqst32_header;

	procedure set_rqst64_header(signal data: out std_logic_vector; rqst: in rqst64) is
	begin
		assert rqst.dw0.desc = MRd64_desc or rqst.dw0.desc = MWr64_desc
			report "Tried to  set rqst64 header with non-rqst64 type"
			severity failure;

		data( 31 downto  0) <= to_dword(rqst.dw0);
		data( 63 downto 32) <= to_dword(rqst.dw1);
		data( 95 downto 64) <= to_dword(rqst.dw2);
		data(127 downto 96) <= to_dword(rqst.dw3);
	end set_rqst64_header;

	procedure set_cpld_header(signal data: out std_logic_vector; cpl: in cpld) is
	begin
		assert cpl.dw0.desc = CplD_desc
			report "Tried to set cpld header with non-cpld type"
			severity failure;

		data(31 downto  0) <= to_dword(cpl.dw0);
		data(63 downto 32) <= to_dword(cpl.dw1);
		data(95 downto 64) <= to_dword(cpl.dw2);
	end set_cpld_header;

	procedure set_rqst32_header(signal pkt: out fragment; header: in rqst32) is
	begin
		pkt.sof  <= '1';
		if to_integer(unsigned(header.dw0.length)) = 1 or -- Data is dw3 of packet
		   header.dw0.desc = MRd32_desc then -- No data in read requests
			pkt.eof <= '1';
		else
			pkt.eof <= '0';
		end if;

		pkt.keep(2 downto 0) <= "111";

		set_rqst32_header(pkt.data, header);
	end set_rqst32_header;

	procedure set_rqst64_header(signal pkt: out fragment; header: in rqst64) is
	begin
		pkt.sof <= '1';

		if header.dw0.desc = MRd64_desc then -- No data in read requests
			pkt.eof <= '1';
		else -- No write requests without data!
			pkt.eof <= '0';
		end if;
		pkt.keep <= (others => '1');

		set_rqst64_header(pkt.data, header);

	end set_rqst64_header;

	procedure set_cpld_header(signal pkt: out fragment; header: in cpld) is
	begin
		pkt.sof <= '1';
		pkt.keep(2 downto 0) <= (others => '1');

		if to_integer(unsigned(header.dw0.length)) <= 1 then
			pkt.eof <= '1';
		else
			pkt.eof <= '0';
		end if;

		set_cpld_header(pkt.data, header);
	end set_cpld_header;

	procedure set_dw(signal pkt: out fragment; idx: natural; data: dword) is
	begin
		assert idx <= 3
			report "Called set_dw with out of bounds idx: " & natural'image(idx)
			severity failure;

		pkt.keep(idx) <= '1';
		pkt.data(((idx + 1) * 32) - 1 downto (idx * 32)) <= data;
	end set_dw;

	procedure reset(signal pkt: out fragment) is
	begin
		pkt.eof <= '0';
		pkt.sof <= '0';
		pkt.keep <= (others => '0');
		pkt.data <= (others => '0');
	end reset;

	function get_rqst32(data: std_logic_vector) return rqst32 is
		variable ret: rqst32 := init_rqst32;
	begin
		ret.dw0 := to_common_dw0(data(31 downto  0));
		ret.dw1 := to_rqst_dw1(  data(63 downto 32));
		ret.dw2 := to_rqst32_dw2(data(95 downto 64));
		return ret;
	end get_rqst32;

	function get_rqst64(data: std_logic_vector) return rqst64 is
		variable ret: rqst64 := init_rqst64;
	begin
		ret.dw0 := to_common_dw0(data( 31 downto  0));
		ret.dw1 := to_rqst_dw1(  data( 63 downto 32));
		ret.dw2 := to_rqst64_dw2(data( 95 downto 64));
		ret.dw3 := to_rqst64_dw3(data(127 downto 96));
		return ret;
	end get_rqst64;

	function get_cpld(data: std_logic_vector) return cpld is
		variable ret: cpld := init_cpld;
	begin
		ret.dw0 := to_common_dw0(data(31 downto  0));
		ret.dw1 := to_cpld_dw1(  data(63 downto 32));
		ret.dw2 := to_cpld_dw2(  data(95 downto 64));
		return ret;
	end get_cpld;

	function is_header(pkt: fragment) return boolean is
	begin
		return pkt.sof = '1';
	end is_header;

	function is_last(pkt: fragment) return boolean is
	begin
		return pkt.eof = '1';
	end is_last;

	function get_type(pkt: fragment) return descriptor_t is
	begin
		return to_common_dw0(pkt.data(31 downto 0)).desc;
	end get_type;

	function get_dword(pkt: fragment; dw_idx: natural) return dword is
	begin
		assert dw_idx <= 3 report "get_dword called with idx > 3"
			severity failure;
		return pkt.data((dw_idx + 1) * 32 - 1 downto dw_idx * 32);
	end get_dword;

	function is_read_rqst(pkt: fragment) return boolean is
	begin
		return (get_type(pkt) = MRd32_desc or get_type(pkt) = MRd64_desc);
	end is_read_rqst;

	function is_write_rqst(pkt: fragment) return boolean is
	begin
		return (get_type(pkt) = MWr32_desc or get_type(pkt) = MWr64_desc);
	end is_write_rqst;

	function is_32bit_rqst(pkt: fragment) return boolean is
	begin
		return (get_type(pkt) = MWr32_desc or get_type(pkt) = MRd32_desc);
	end is_32bit_rqst;

	function is_64bit_rqst(pkt: fragment) return boolean is
	begin
		return (get_type(pkt) = MWr64_desc or get_type(pkt) = MRd64_desc);
	end is_64bit_rqst;

	function make_wr_rqst32(
		length, chn_id: natural;
		address: dword
	) return rqst32 is
		variable ret: rqst32 := init_rqst32;
	begin
		assert length >= 1 report "Length for write requests has to be non-zero"
			severity failure;
		ret.dw0.desc   := MWr32_desc;
		ret.dw0.length := std_logic_vector(to_unsigned(length, ret.dw0.length'length));
		ret.dw0.chn_id := std_logic_vector(to_unsigned(chn_id, ret.dw0.chn_id'length));

		-- TODO(sebastian): We will need to calculate byte enables more exact, when
		-- we start supporting byte-wise transmissions.
		ret.dw1.first_be := (others => '1');
		if length = 1 then
			ret.dw1.last_be := (others => '0');
		else
			ret.dw1.last_be := (others => '1');
		end if;

		ret.dw2.address := address;
		return ret;
	end make_wr_rqst32;

	function make_wr_rqst64(
		length, chn_id: natural;
		addr_lo, addr_hi: dword
	) return rqst64 is
		variable ret: rqst64 := init_rqst64;
	begin
		assert length >= 1 report "Length for write requests has to be non-zero"
			severity failure;

		ret.dw0.desc   := MWr64_desc;
		ret.dw0.length := std_logic_vector(to_unsigned(length, ret.dw0.length'length));
		ret.dw0.chn_id := std_logic_vector(to_unsigned(chn_id, ret.dw0.chn_id'length));

		-- TODO(sebastian): We will need to calculate byte enables more exact, when
		-- we start supporting byte-wise transmissions.
		ret.dw1.first_be := (others => '1');
		if length = 1 then
			ret.dw1.last_be := (others => '0');
		else
			ret.dw1.last_be := (others => '1');
		end if;

		ret.dw2.address_hi := addr_hi;
		ret.dw3.address_lo := addr_lo;
		return ret;
	end make_wr_rqst64;

	function make_rd_rqst32(
		length, chn_id, tag: natural;
		address: dword
	) return rqst32 is
		variable ret: rqst32 := init_rqst32;
	begin
		ret.dw0.desc   := MRd32_desc;
		ret.dw0.length := std_logic_vector(to_unsigned(length, ret.dw0.length'length));
		ret.dw0.tag    := std_logic_vector(to_unsigned(tag, ret.dw0.tag'length));
		ret.dw0.chn_id := std_logic_vector(to_unsigned(chn_id, ret.dw0.chn_id'length));

		ret.dw1.first_be := (others => '1');
		if length = 1 then
			ret.dw1.last_be := (others => '0');
		else
			ret.dw1.last_be := (others => '1');
		end if;

		ret.dw2.address := address;
		return ret;
	end make_rd_rqst32;


	function make_rd_rqst64(
		length, chn_id, tag: natural;
		addr_lo, addr_hi: dword
	) return rqst64 is
		variable ret: rqst64 := init_rqst64;
	begin
		ret.dw0.desc   := MRd32_desc;
		ret.dw0.length := std_logic_vector(to_unsigned(length, ret.dw0.length'length));
		ret.dw0.tag    := std_logic_vector(to_unsigned(tag, ret.dw0.tag'length));
		ret.dw0.chn_id := std_logic_vector(to_unsigned(chn_id, ret.dw0.chn_id'length));

		ret.dw1.first_be := (others => '1');
		if length = 1 then
			ret.dw1.last_be := (others => '0');
		else
			ret.dw1.last_be := (others => '1');
		end if;

		ret.dw2.address_hi := addr_hi;
		ret.dw3.address_lo := addr_lo;

		return ret;
	end make_rd_rqst64;

	function make_cpld(
		length, chn_id, tag, byte_count: natural;
		lower_addr: std_logic_vector
	) return cpld is
		variable ret: cpld := init_cpld;
	begin
		assert lower_addr'length = 7 report "Size of lower addr is wrong!" severity failure;
		ret.dw0.desc   := CplD_desc;
		ret.dw0.length := std_logic_vector(to_unsigned(length, ret.dw0.length'length));
		ret.dw0.tag    := std_logic_vector(to_unsigned(tag, ret.dw0.tag'length));
		ret.dw0.chn_id := std_logic_vector(to_unsigned(chn_id, ret.dw0.chn_id'length));

		ret.dw1.byte_count := std_logic_vector(to_unsigned(byte_count, ret.dw1.byte_count'length));
		ret.dw2.lower_addr := lower_addr;
		return ret;
	end make_cpld;
	
	procedure set_length(
		signal   pkt : out fragment; 
		variable len : in std_logic_vector(9 downto 0)
	) is
	begin
		pkt.data(15 downto 6) <= len;
	end set_length;


end transceiver_128bit_types;
