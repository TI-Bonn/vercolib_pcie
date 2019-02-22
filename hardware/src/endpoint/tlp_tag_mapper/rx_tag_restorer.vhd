---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description:	restores virtual tag and channel_id of memory completions
-- Version: 	0.1
---------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity rx_tag_restorer is
	port(
		clk : in  std_logic;
		rst : in  std_logic;
		
		tag     : out std_logic_vector(7 downto 0);
		tag_rst : out std_logic;
		
		mem_addr   : out std_logic_vector(7 downto 0);
		mem_chn_id : in  std_logic_vector(7 downto 0);
		mem_tag    : in  std_logic_vector(7 downto 0);
		
		i     : in  fragment;
		i_vld : in  std_logic;
		i_req : out std_logic := '0';
		
		o     : out fragment;
		o_vld : out std_logic := '0';
		o_req : in  std_logic
	);
end rx_tag_restorer;

architecture arch of rx_tag_restorer is

	signal buf : fragment := default_fragment;
	signal buf_vld : std_logic := '0';
	
begin
	
i_req <= o_req;

-- prepare original virtual tag and channel_id from memory for the next clock cycle
mem_addr <= to_common_dw0(get_dword(i, 0)).tag;

main: process
	variable buf_temp_dw0 : common_dw0;
	variable buf_temp_dw1 : cpld_dw1;
begin
	wait until rising_edge(clk) and o_req = '1';
	buf_temp_dw0 := to_common_dw0(get_dword(buf, 0));
	buf_temp_dw1 := to_cpld_dw1  (get_dword(buf, 1));
	
	-- defaults
	tag_rst <= '0';
	o_vld   <= '0';

	-- buffer incoming packet, might have to wait for memory for one clock cycle
	buf_vld <= i_vld;
	buf     <= i;
	
	-- if buffered packet is a completion, restore original channel_id and virtual tag
	o_vld <= buf_vld;
	o     <= buf;
	if buf_temp_dw0.desc = CplD_desc and buf.sof = '1' then
		-- reset tag if packet is the last completion of a MRd
		if buf_temp_dw0.length = buf_temp_dw1.byte_count(11 downto 2) then
			tag     <= buf_temp_dw0.tag;
			tag_rst <= '1';
		end if;
		
		buf_temp_dw0.chn_id := mem_chn_id;
		buf_temp_dw0.tag    := mem_tag;
		
		o.data(31 downto 0) <= to_dword(buf_temp_dw0);
	end if;

	if rst = '1' then
		tag_rst <= '0';
		buf_vld <= '0';
		buf     <= default_fragment;
		o_vld   <= '0';
		o       <= default_fragment;
	end if;
end process;

end architecture;
