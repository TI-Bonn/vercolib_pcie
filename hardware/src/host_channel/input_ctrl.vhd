
library ieee;
use ieee.std_logic_1164.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library unisim;
--use unisim.vcomponents.all;

entity input_ctrl is
	port( 
      -- Control Port:
      clk		   : in	std_logic;
      -- Input Port:
      i_cont	   : out	std_logic;
      i_new	      : in 	std_logic;
            -- Submodule Port:
      s_using_inp : in 	std_logic;
      s_vld       : out	std_logic
	);
end input_ctrl;

architecture behavioral of input_ctrl is
	signal state		 : std_logic := '0';
	signal next_state	 : std_logic;
	signal fsm_signals : std_logic_vector(2 downto 0);
begin
	fsm_signals <= state & i_new & s_using_inp;

	fsm_output: process(fsm_signals)
	begin
		case fsm_signals is
			when "000" => next_state <= '0';
			when "001" => next_state <= 'X';			
			when "010" => next_state <= '1';
			when "011" => next_state <= '0';
			when "100" => next_state <= '1';
			when "101" => next_state <= '0';
			when "110" => next_state <= 'X';
			when "111" => next_state <= 'X';
			when others => next_state <= 'X';
		end case;	
	end process;

	i_cont  	<= not next_state;
	s_vld 	<= state or i_new;
	
	fsm_state : process(clk)
	begin
		if clk'event and clk = '1' then
			state <= next_state;
		end if;
	end process;	
	
	
end behavioral;
