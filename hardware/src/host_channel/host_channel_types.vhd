-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description: types used in rx_host_channel modules
-- Version: 	0.1
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.host_types.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;

package host_channel_types is

	type MWr_payload_t is array (0 to 3) of dword;

	subtype reg_addr_t is unsigned(3 downto 0);
	constant ADDR_LO_REG      : reg_addr_t := x"0";
	constant ADDR_HI_REG      : reg_addr_t := x"1";
	constant BUFFER_SIZE      : reg_addr_t := x"2";
	constant TRANSFERRED_REG  : reg_addr_t := x"4";
	constant CHANNEL_INFO_REG : reg_addr_t := x"5";

	type request_t     is (MWr, MRd);
	type instruction_t is (TRANSFER_DMA32, TRANSFER_DMA64, GET_TRANSFERRED_BYTES, GET_CHANNEL_INFO);
	
	type tlp_header_info_t is record
		desc        : descriptor_t;
		length      : unsigned(9 downto 0);
		tag         : unsigned(7 downto 0);
		mrq_address : std_logic_vector(63 downto 0);
		cpl_lo_addr : std_logic_vector(6 downto 0);
	end record;
	function init_tlp_header_info return tlp_header_info_t;
	
	type requester_instr_t is record
		instr       : instruction_t;
		dma_addr    : unsigned(63 downto 0);
		dma_size    : unsigned(31 downto 0);	
	end record;
	
	type interrupt_instr_t is record
		instr       : instruction_t;
		dma_size    : unsigned(31 downto 0);
		cpl_tag     : unsigned(7 downto 0);
		cpl_lo_addr : std_logic_vector(6 downto 0);
	end record;
	

	function make_packet(header_info: tlp_header_info_t; chn_id: natural; payload: dword) return fragment;
	
	function cnt2keep(cnt : unsigned(2 downto 0)) return std_logic_vector;
	function keep2cnt(keep : std_logic_vector(3 downto 0)) return unsigned;

end package host_channel_types;

package body host_channel_types is

function make_packet(header_info: tlp_header_info_t; chn_id: natural; payload: dword) return fragment is
	variable ret: fragment := default_fragment;
	variable dw0: common_dw0 := init_common_dw0;
	variable dw1_cpld: cpld_dw1 := init_cpld_dw1;
	variable dw2_cpld: cpld_dw2 := init_cpld_dw2;
	variable dw1_rqst: rqst_dw1 := init_rqst_dw1;
begin
	dw0.desc   := header_info.desc;
	dw0.length := std_logic_vector(header_info.length);
	dw0.tag    := std_logic_vector(header_info.tag);
	dw0.chn_id := std_logic_vector(to_unsigned(chn_id, dw0.chn_id'length));
	
	dw1_rqst.first_be := (others => '1');
	if header_info.length = 1 then
		dw1_rqst.last_be := (others => '0');
	else
		dw1_rqst.last_be := (others => '1');
	end if;
	
	dw1_cpld.byte_count := std_logic_vector(header_info.length & "00");
	dw2_cpld.lower_addr := header_info.cpl_lo_addr;

	-- set sof, eof and data fields according to descriptor
	ret.sof := '1';
	if header_info.desc = MWr32_desc or header_info.desc = MWr64_desc then
		ret.eof := '0';
	else
		ret.eof := '1';
	end if;
	if header_info.desc = MWr32_desc or header_info.desc = MRd32_desc then
		ret.keep := "0111";
	else
		ret.keep := "1111";
	end if;
	
	ret.data(31 downto 0) := to_dword(dw0);
	case header_info.desc is
	when MRd32_desc | MWr32_desc =>
		ret.data( 63 downto 32) := to_dword(dw1_rqst);
		ret.data(127 downto 64) := payload & header_info.mrq_address(31 downto 0);
	when MRd64_desc | MWr64_desc =>
		ret.data(127 downto 32) := header_info.mrq_address(31 downto 0) & 
		                           header_info.mrq_address(63 downto 32) & 
		                           to_dword(dw1_rqst);
	when CplD_desc =>
		ret.data( 63 downto 32) := to_dword(dw1_cpld);
		ret.data( 95 downto 64) := to_dword(dw2_cpld);
		ret.data(127 downto 96) := payload;
	when others => null;
	end case;
	
	-- TODO: change after refactoring MSIX-table module
	if header_info.desc = MSIX_desc then
		ret.data(127 downto 104) := (others => '0');
		ret.data(103 downto  96) := dw0.chn_id;
	end if;
	
	--if header_info.desc = MRd32_desc or header_info.desc = MRd64_desc then
	--	ret.data(23 downto 21) := dw0.chn_id(2 downto 0);
	--end if;

	return ret;
end make_packet;

function cnt2keep(cnt : unsigned(2 downto 0)) return std_logic_vector is
begin
	case cnt is
		when "001" => return "0001";
		when "010" => return "0011";
		when "011" => return "0111";
		when "100" => return "1111";
		when others => return "0000";
	end case;
end function;

function keep2cnt(keep : std_logic_vector(3 downto 0)) return unsigned is
begin					
	case keep is
		when "0001" => return "001";
		when "0011" => return "010";
		when "0111" => return "011";
		when "1111" => return "100";
		when others => return "000";
	end case;
end function;


function init_tlp_header_info return tlp_header_info_t is
	variable ret : tlp_header_info_t;
begin
	ret.desc        := "0000";
	ret.length      := (others => '0');
	ret.mrq_address := (others => '0');
	ret.tag         := (others => '0');
	ret.cpl_lo_addr := (others => '0');
	return ret;
end init_tlp_header_info;

end package body host_channel_types;

