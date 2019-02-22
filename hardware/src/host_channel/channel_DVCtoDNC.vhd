--------------------------------------------------------------------------------
-- Entity: channel_DVCtoDNC
--------------------------------------------------------------------------------
-- Copyright ... 2011
-- Filename          : channel_DVCtoDNC.vhd
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

entity channel_DVCtoDNC is
	generic(
		data_bits	: natural    		--! data width of the channel (in bits).
	);
	port(
		clk 	 	: in  std_logic;  	--! input clock

		i_data 		: in  std_logic_vector(data_bits-1 downto 0);
		i_vld  		: in  std_logic;
		i_cont 		: out std_logic;

		o_data 		: out std_logic_vector(data_bits-1 downto 0);
		o_new  		: out std_logic;
		o_cont 		: in  std_logic
	);
end channel_DVCtoDNC;

architecture arch of channel_DVCtoDNC is
	signal new_sig  : std_logic;
begin
	inst_output_ctrl: entity work.output_ctrl
		port map(
			clk    => clk,
			s_cont => i_cont,
			s_vld  => i_vld,
			o_cont => o_cont,
			o_new  => new_sig
		);

	inst_output_buf : entity work.output_buf
		generic map(
			data_bits => data_bits
		)
		port map(
			clk    => clk,
			s_data => i_data,
			o_new  => new_sig,
			o_data => o_data
		);

	o_new  <= new_sig;

end arch;
