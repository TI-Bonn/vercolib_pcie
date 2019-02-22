-- Package for TLP Record Types Definitions
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>


library ieee;
use ieee.std_logic_1164.all;

use work.host_types.all;

package tlp_types is

	constant fmtType_MWr   : std_logic_vector(6 downto 0) := "1000000";
	constant fmtType_MWr64 : std_logic_vector(6 downto 0) := "1100000";
	constant fmtType_MRd   : std_logic_vector(6 downto 0) := "0000000";
	constant fmtType_MRd64 : std_logic_vector(6 downto 0) := "0100000";
	constant fmtType_CplD  : std_logic_vector(6 downto 0) := "1001010";

	-- First DW
	type tlp_dw0 is record
		length   : std_logic_vector(9 downto 0);
		attr     : std_logic_vector(1 downto 0);
		ep       : std_logic;
		td       : std_logic;
		tc       : std_logic_vector(2 downto 0);
		fmt_type : std_logic_vector(6 downto 0);
	end record;

	-- MWr, MRd types
	-- Second DW
	type tlp_rqst_dw1 is record
		first_byte_enable : std_logic_vector(3 downto 0);
		last_byte_enable  : std_logic_vector(3 downto 0);
		tag               : std_logic_vector(7 downto 0);
		requester_id      : std_logic_vector(15 downto 0);
	end record;

	-- Third DW
	type tlp_rqst_dw2 is record
		address       : std_logic_vector(31 downto 0);
	end record;

	-- Forth DW
	type tlp_rqst_dw3 is record
		lower_addr64  : std_logic_vector(31 downto 0); -- Address[31:0] in 4DW TLP
	end record;

	-- CplD types
	-- PCIe MWr, MRd types
	type tlp_cpld_dw1 is record
		byte_count   : std_logic_vector(11 downto 0);
		bcm          : std_logic;
		status       : std_logic_vector(2 downto 0);
		completer_id : std_logic_vector(15 downto 0);
	end record;

	-- Second DW
	type tlp_cpld_dw2 is record
		lower_address : std_logic_vector(6 downto 0);
		tag           : std_logic_vector(7 downto 0);
		requester_id  : std_logic_vector(15 downto 0);
	end record;

	function dword_to_tlp_dw0      (data : dword) return tlp_dw0;
	function dword_to_tlp_rqst_dw1 (data : dword) return tlp_rqst_dw1;
	function dword_to_tlp_rqst_dw2 (data : dword) return tlp_rqst_dw2;
	function dword_to_tlp_rqst_dw3 (data : dword) return tlp_rqst_dw3;
	function dword_to_tlp_cpld_dw1 (data : dword) return tlp_cpld_dw1;
	function dword_to_tlp_cpld_dw2 (data : dword) return tlp_cpld_dw2;

	function tlp_dw0_to_dword      (data : tlp_dw0     ) return dword;
	function tlp_rqst_dw1_to_dword (data : tlp_rqst_dw1) return dword;
	function tlp_rqst_dw2_to_dword (data : tlp_rqst_dw2) return dword;
	function tlp_rqst_dw3_to_dword (data : tlp_rqst_dw3) return dword;
	function tlp_cpld_dw1_to_dword (data : tlp_cpld_dw1) return dword;
	function tlp_cpld_dw2_to_dword (data : tlp_cpld_dw2) return dword;

	-- TLP Type definitions for 128bit interfaces
	type tlp_packet is
	record
		bar	 : std_logic_vector(  5 downto 0);
		sof  : std_logic;
		eof  : std_logic;
		keep : std_logic_vector(  3 downto 0);
		data : std_logic_vector(127 downto 0);
	end record;

	function init_tlp_packet return tlp_packet;
	function slv_to_tlp_packet(data: std_logic_vector(139 downto 0)) return tlp_packet;
	function tlp_packet_to_slv(data : tlp_packet) return std_logic_vector;

	type tlp_request_header is record
		dw0 : tlp_dw0;
		dw1 : tlp_rqst_dw1;
		dw2 : tlp_rqst_dw2;
		dw3 : dword;
	end record;

	type tlp_completion_header is record
		dw0 : tlp_dw0;
		dw1 : tlp_cpld_dw1;
		dw2 : tlp_cpld_dw2;
		dw3 : dword;
	end record;

	type tlp_data is record
		dw0 : dword;
		dw1 : dword;
		dw2 : dword;
		dw3 : dword;
	end record;

	function slv_to_tlp_request_header(data : std_logic_vector(95 downto 0)) return tlp_request_header;
	function tlp_request_header_to_slv(header : tlp_request_header)	return std_logic_vector;

	function slv_to_tlp_completion_header(data : std_logic_vector(95 downto 0)) return tlp_completion_header;
	function tlp_completion_header_to_slv(header : tlp_completion_header) return std_logic_vector;

	function slv_to_tlp_data(data : std_logic_vector(95 downto 0))	return tlp_data;
	function tlp_data_to_slv(data : tlp_data) return std_logic_vector;
end package tlp_types;

package body tlp_types is

	function dword_to_tlp_dw0 (data : dword) return tlp_dw0 is
		variable dw : tlp_dw0;
	begin
		dw.length    := data(9 downto 0);
		dw.attr      := data(13 downto 12);
		dw.ep        := data(14);
		dw.td        := data(15);
		dw.tc        := data(22 downto 20);
		dw.fmt_type  := data(30 downto 24);
		return dw;
	end dword_to_tlp_dw0;

	function dword_to_tlp_rqst_dw1 (data : dword) return tlp_rqst_dw1 is
		variable dw : tlp_rqst_dw1;
	begin
		dw.first_byte_enable := data(3 downto 0);
		dw.last_byte_enable  := data(7 downto 4);
		dw.tag               := data(15 downto 8);
		dw.requester_id      := data(31 downto 16);
		return dw;
	end dword_to_tlp_rqst_dw1;

	function dword_to_tlp_rqst_dw2 (data: dword) return tlp_rqst_dw2 is
		variable dw : tlp_rqst_dw2;
	begin
		dw.address := data;
		return dw;
	end dword_to_tlp_rqst_dw2;

	function dword_to_tlp_rqst_dw3 (data: dword) return tlp_rqst_dw3 is
		variable dw : tlp_rqst_dw3;
	begin
		dw.lower_addr64 := data;
		return dw;
	end dword_to_tlp_rqst_dw3;

	function dword_to_tlp_cpld_dw1 (data : dword) return tlp_cpld_dw1 is
		variable dw : tlp_cpld_dw1;
	begin
		dw.byte_count   := data(11 downto 0);
		dw.bcm          := data(12);
		dw.status       := data(15 downto 13);
		dw.completer_id := data(31 downto 16);
		return dw;
	end dword_to_tlp_cpld_dw1;

	function dword_to_tlp_cpld_dw2 (data : dword) return tlp_cpld_dw2 is
		variable dw : tlp_cpld_dw2;
	begin
		dw.lower_address := data(6 downto 0);
		dw.tag           := data(15 downto 8);
		dw.requester_id  := data(31 downto 16);
		return dw;
	end dword_to_tlp_cpld_dw2;


	function tlp_dw0_to_dword (data : tlp_dw0) return dword is
		variable dw : dword := (others => '0');
	begin
		 dw(9 downto 0)   := data.length;
		 dw(13 downto 12) := data.attr;
		 dw(14)           := data.ep;
		 dw(15)           := data.td;
		 dw(22 downto 20) := data.tc;
		 dw(30 downto 24) := data.fmt_type;
		return dw;
	end tlp_dw0_to_dword;

	function tlp_rqst_dw1_to_dword (data : tlp_rqst_dw1) return dword is
		variable dw : dword := (others => '0');
	begin
		dw(3 downto 0)  := data.first_byte_enable;
		dw(7 downto 4)  := data.last_byte_enable;
		dw(15 downto 8) := data.tag;
		dw(31 downto 16):= data.requester_id;
		return dw;
	end tlp_rqst_dw1_to_dword;

	function tlp_rqst_dw2_to_dword (data : tlp_rqst_dw2) return dword is
		variable dw : dword := (others => '0');
	begin
		dw := data.address;
		return dw;
	end tlp_rqst_dw2_to_dword;

	function tlp_rqst_dw3_to_dword (data : tlp_rqst_dw3) return dword is
		variable dw : dword := (others => '0');
	begin
		dw := data.lower_addr64;
		return dw;
	end tlp_rqst_dw3_to_dword;

	function tlp_cpld_dw1_to_dword (data : tlp_cpld_dw1) return dword is
		variable dw : dword := (others => '0');
	begin
		dw(11 downto 0) := data.byte_count;
		dw(12)          := data.bcm;
		dw(15 downto 13):= data.status;
		dw(31 downto 16):= data.completer_id;
		return dw;
	end tlp_cpld_dw1_to_dword;

	function tlp_cpld_dw2_to_dword (data : tlp_cpld_dw2) return dword is
		variable dw : dword := (others => '0');
	begin
		dw(6 downto 0) := data.lower_address;
		dw(15 downto 8):= data.tag;
		dw(31 downto 16):= data.requester_id;
		return dw;
	end tlp_cpld_dw2_to_dword;

	function init_tlp_packet return tlp_packet is
		variable data : tlp_packet;
	begin
		data.bar  := (others => '0');
		data.keep := (others => '0');
		data.sof  := '0';
		data.eof  := '0';
		data.data := (others => '0');
		return data;
	end init_tlp_packet;

	function tlp_packet_to_slv(data : tlp_packet) return std_logic_vector is
		variable out_data : std_logic_vector(139 downto 0) := (others => '0');
	begin
		out_data(139 downto 134) := data.bar;
		out_data(133 downto 130) := data.keep;
		out_data(129)            := data.sof;
		out_data(128)            := data.eof;
		out_data(127 downto 0)   := data.data;
		return out_data;
	end tlp_packet_to_slv;

	function slv_to_tlp_packet(data: std_logic_vector(139 downto 0)) return tlp_packet is
		variable out_data : tlp_packet;
	begin
		out_data.bar  := data(139 downto 134);
		out_data.keep := data(133 downto 130);
		out_data.sof  := data(129);
		out_data.eof  := data(128);
		out_data.data := data(127 downto 0);
		return out_data;
	end slv_to_tlp_packet;

	function slv_to_tlp_request_header(data : std_logic_vector(95 downto 0)) return tlp_request_header is
		variable header : tlp_request_header;
	begin
		header.dw0 := dword_to_tlp_dw0(data(31 downto 0));
		header.dw1 := dword_to_tlp_rqst_dw1(data(63 downto 32));
		header.dw2 := dword_to_tlp_rqst_dw2(data(95 downto 64));
		return header;
	end slv_to_tlp_request_header;

	function slv_to_tlp_completion_header(data : std_logic_vector(95 downto 0)) return tlp_completion_header is
		variable header : tlp_completion_header;
	begin
		header.dw0 := dword_to_tlp_dw0(data(31 downto 0));
		header.dw1 := dword_to_tlp_cpld_dw1(data(63 downto 32));
		header.dw2 := dword_to_tlp_cpld_dw2(data(95 downto 64));
		return header;
	end slv_to_tlp_completion_header;

	function slv_to_tlp_data(data : std_logic_vector(95 downto 0))	return tlp_data is
		variable out_data : tlp_data;
	begin
		out_data.dw0 := data(31 downto 0);
		out_data.dw1 := data(63 downto 32);
		out_data.dw2 := data(95 downto 64);
		return out_data;
	end slv_to_tlp_data;


	function tlp_completion_header_to_slv(header : tlp_completion_header)	return std_logic_vector is
		variable data : std_logic_vector(95 downto 0);
	begin
		data(31 downto 0)   := tlp_dw0_to_dword(header.dw0);
		data(63 downto 32)  := tlp_cpld_dw1_to_dword(header.dw1);
		data(95 downto 64)  := tlp_cpld_dw2_to_dword(header.dw2);
		return data;
	end tlp_completion_header_to_slv;

	function tlp_request_header_to_slv(header : tlp_request_header)	return std_logic_vector is
		variable data : std_logic_vector(95 downto 0);
	begin
		data(31 downto 0)   := tlp_dw0_to_dword(header.dw0);
		data(63 downto 32)  := tlp_rqst_dw1_to_dword(header.dw1);
		data(95 downto 64)  := tlp_rqst_dw2_to_dword(header.dw2);
		return data;
	end tlp_request_header_to_slv;

	function tlp_data_to_slv(data : tlp_data) return std_logic_vector is
		variable out_data : std_logic_vector(95 downto 0) := (others => '0');
	begin
		out_data(31 downto 0)   := data.dw0;
		out_data(63 downto 32)  := data.dw1;
		out_data(95 downto 64)  := data.dw2;
		return out_data;
	end tlp_data_to_slv;

end tlp_types;

