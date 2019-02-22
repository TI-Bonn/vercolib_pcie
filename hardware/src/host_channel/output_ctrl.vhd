----------------------------------------------------------------------------------
-- Company: Technische Informatik, Universitaet Bonn
-- Engineer: Matthias Behrndt, Prof. Dr. Joachim K. Anlauf 
-- 
-- Create Date:    21:01:27 10/19/2008 
-- Design Name: 
-- Module Name:    output_ctrl - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 	 Output-Controller
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
--! @file
--! @brief Output controller for designing AccelKit modules


library ieee;
use ieee.std_logic_1164.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library unisim;
--use unisim.vcomponents.all;

--! Output controller for designing AccelKit modules

entity output_ctrl is
   port(
      -- Control Port:
      clk		: in	std_logic;
      -- Submodule Output Port:
      s_cont	: out	std_logic;
      s_vld		: in 	std_logic;
      -- Output Port:
      o_cont	: in	std_logic;
      o_new	   : out	std_logic
	);
end output_ctrl;

architecture behavioral of output_ctrl is
	signal state		 : std_logic := '0';
	signal next_state	 : std_logic;
	signal fsm_signals : std_logic_vector(2 downto 0);
begin
	fsm_signals <= state & o_cont & s_vld;

	fsm_output : process(fsm_signals)
	begin
		case fsm_signals is
			when "000" => next_state <= 'X'; 
			when "001" => next_state <= '1';
			when "010" => next_state <= '0';
			when "011" => next_state <= '0';
			when "100" => next_state <= '1';
			when "101" => next_state <= '1';
			when "110" => next_state <= '0';
			when "111" => next_state <= '0';
			when others=> next_state <= 'X';
		end case;
	end process;
	
	fsm_state : process(clk)
	begin
		if clk'event and clk = '1' then	
			state <= next_state;
		end if;	
	end process;
	
	s_cont	<= (not state) or (not s_vld);
	o_new 	<= '1' when state = '0' and s_vld = '1' else '0';
end behavioral;
