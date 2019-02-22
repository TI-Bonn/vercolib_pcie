----------------------------------------------------------------------------------
-- Company: Technische Informatik, Universitaet Bonn
-- Engineer: Prof. Dr. Joachim K. Anlauf 
-- 
-- Create Date:    21:01:27 10/19/2008 
-- Design Name: 
-- Module Name:    output_buf - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 	 Output-Buffer
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
--! @file
--! @brief output buffer for designing AccelKit modules

library ieee;
use ieee.std_logic_1164.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library unisim;
--use unisim.vcomponents.all;

--! output buffer for designing AccelKit modules

entity output_buf is
   generic(
     -- Bit Widths:
      data_bits: natural
   );
   port(
      -- Control Port:
      clk		: in	std_logic;
      -- Submodule Output Port:
      s_data	: in 	std_logic_vector(data_bits-1 downto 0);
      -- Output Control Port:
      o_new    : in std_logic;
      -- Output Port:
      o_data  	: out	std_logic_vector(data_bits-1 downto 0)
   );
end output_buf;

architecture behavioral of output_buf is
   signal data_reg	 : std_logic_vector(data_bits-1 downto 0);
begin
	o_data 	<= s_data when o_new = '1' else data_reg;
		
	regs: process(clk)
	begin
		if clk'event and clk = '1' then
			if (o_new = '1') then
				-- save the new value in register
				data_reg <= s_data;
			end if;
		end if;
	end process;
end behavioral;
