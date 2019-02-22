---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description:	replaces virtual tag and channel_id with an available tlp_tag
-- Version: 	0.1
---------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity tx_tag_replacer is
	port(
		clk : in  std_logic;
		rst : in  std_logic;

		tag       : in  std_logic_vector(7 downto 0);
		tag_avail : in  std_logic;
		tag_set   : out std_logic := '0';

		mem_wr     : out std_logic;
		mem_addr   : out std_logic_vector(7 downto 0);
		mem_chn_id : out std_logic_vector(7 downto 0);
		mem_tag    : out std_logic_vector(7 downto 0);

		i     : in  fragment;
		i_vld : in  std_logic;
		i_req : out std_logic := '0';

		o     : out fragment;
		o_vld : out std_logic := '0';
		o_req : in  std_logic
	);
end tx_tag_replacer;

architecture arch of tx_tag_replacer is
	signal i_req_logic : std_logic;
begin

i_req <= i_req_logic or not i_vld;

i_req_logic <= '1' when    (o_req = '1' and (tag_avail = '1' or not is_read_rqst(i)))
						or (i_vld = '1' and i.sof = '1' and (get_type(i) = MSIX_desc)) else '0';
tag_set     <= '1' when o_req = '1' and  tag_avail = '1' and    is_read_rqst(i) and i_vld = '1' else '0';

main: process
	variable temp : common_dw0;
begin
	wait until rising_edge(clk) and o_req = '1';
	temp     := to_common_dw0(get_dword(i, 0));

	o_vld  <= '0';
	mem_wr <= '0';

	o.sof  <= i.sof;
	o.eof  <= i.eof;
	o.keep <= i.keep;

	o.data(127 downto 32) <= i.data(127 downto 32);

	mem_addr   <= tag;
	mem_chn_id <= temp.chn_id;
	mem_tag    <= temp.tag;

	if i_vld = '1' then
		if is_read_rqst(i) then
			if tag_avail = '1' then
				temp.tag := tag;
				o_vld  <= '1';
				mem_wr <= '1';
			end if;
		else
			o_vld <= '1';
		end if;
	end if;
	o.data(31 downto 0) <= to_dword(temp);

	if rst = '1' then
		o_vld  <= '0';
		o      <= default_fragment;
		mem_wr <= '0';
	end if;
end process;

end architecture;
