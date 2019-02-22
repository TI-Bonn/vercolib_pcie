--------------------------------------------------------------------------------
-- Entity: channel_DNCtoDVC
--------------------------------------------------------------------------------
-- Copyright ... 2011
-- Filename          : channel_DNCtoDVC.vhd
-- Creation date     : 2011-09-07
-- Author(s)         : dornbusc
-- Version           : 1.00
-- Description       : <short description>
--------------------------------------------------------------------------------
-- File History:
-- Date         Version  Author   Comment
-- 2011-09-07   1.00     dornbusc     Creation of File
--------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

entity channel_DNCtoDVC is
	generic(
        data_bits	: natural    		--! data width of the channel (in bits).
    );
	port  (
		clk 		: in  std_logic;	--! input clock
		
		i_data   	: in  std_logic_vector(data_bits-1 downto 0);
        i_new   	: in  std_logic;
        i_cont   	: out std_logic;

        o_data  	: out std_logic_vector(data_bits-1 downto 0);
        o_vld   	: out std_logic;
        o_cont  	: in  std_logic
	);
end channel_DNCtoDVC;

architecture arch of channel_DNCtoDVC is
    signal using_inp_sig : std_logic;
    signal o_vld_sig     : std_logic;
begin
    using_inp_sig <= (o_vld_sig and o_cont);
	o_vld         <= o_vld_sig;

    inst_input_ctrl : entity work.input_ctrl
        port map(
            clk         => clk,
            i_cont      => i_cont,
            i_new       => i_new,
            s_using_inp => using_inp_sig,
            s_vld       => o_vld_sig
        );

    o_data <= i_data;
            
end arch;

