----------------------------------------------------------------------------
-- Module: 	Generic Round Robin Arbiter
--
-- Author:	Oguzhan Sezenlik,	University Bonn
--
--	Arbiter selects
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;

entity packet_arbiter is
	generic(
		ports   : natural := 16 -- # of ports
	);
	port(
		-- Control Port:
		clk     : in  std_logic;
		rst     : in  std_logic;
		-- Input Port "d":
		i_req   : out std_logic_vector(ports-1 downto 0) := (others => '1');
		i_vld   : in  std_logic_vector(ports-1 downto 0);
		i       : in  fragment_vector(ports-1 downto 0);
		-- Output Port "o":
		o_req   : in  std_logic;
		o_vld   : out std_logic := '0';
		o       : out fragment := default_fragment
	);
end packet_arbiter;

architecture Behavioral of packet_arbiter is

	signal current_input : integer range 0 to ports-1;

	signal i_req_reg : std_logic_vector(ports-1 downto 0) := (others => '0');

	signal prio_enc_masked, prio_enc_unmasked, vld_masked, prio_enc_mux	: std_logic_vector(ports-1 downto 0) := (others => '0');
	signal one_hot_masked, one_hot_unmasked, one_hot : std_logic_vector(ports-1 downto 0) := (others => '0');

	signal mask: std_logic_vector(ports-2 downto 0) := (others => '0');

	type state_t is (PREVIOUS_WAS_EOF, WAIT_FOR_EOF);
	signal state : state_t := PREVIOUS_WAS_EOF;

	signal current_is_eof : std_logic := '0';

begin

	req_logic: for i in 0 to ports-1 generate
		i_req(i) <= (i_req_reg(i) and o_req) or not i_vld(i);
	end generate;

	vld_masked <= i_vld and (mask & '0');

	-- priority encoder with thermometer encoding, used as the mask.
	-- example: 00010110 => 11111110;
	prio_enc_masked   <= vld_masked or std_logic_vector(unsigned(not vld_masked) +1);
	prio_enc_unmasked <= i_vld      or std_logic_vector(unsigned(not i_vld) +1);

	-- priority encoder with one_hot encoding, used as input for the binary encoder and cont logic.
	-- example: 00010110 => 00000010;
	one_hot_masked   <= vld_masked and std_logic_vector(unsigned(not vld_masked) +1);
	one_hot_unmasked <= i_vld      and std_logic_vector(unsigned(not i_vld) +1);

	prio_enc_mux <= prio_enc_unmasked when unsigned(vld_masked) = 0 else prio_enc_masked;
	one_hot      <= one_hot_unmasked  when unsigned(vld_masked) = 0 else one_hot_masked;

	current_is_eof <= i(current_input).eof and i_vld(current_input);

	fsm: process
	begin
		wait until rising_edge(clk) and o_req = '1';
		case state is
		when WAIT_FOR_EOF =>
			if current_is_eof = '1' then
				state <= PREVIOUS_WAS_EOF;
			end if;
		when PREVIOUS_WAS_EOF =>
			if i_vld(current_input) = '1' and i(current_input).eof = '0' then
				state <= WAIT_FOR_EOF;
			end if;
		end case;
		
		if rst = '1' then
			state <= WAIT_FOR_EOF;
		end if;
	end process;

	proc: process
		variable index, index_masked: integer range 0 to ports-1;
	begin
		wait until rising_edge(clk) and o_req = '1';
		
		if (state = PREVIOUS_WAS_EOF and i_vld(current_input) = '0') or 
		   (current_is_eof = '1') or unsigned(i_req_reg) = 0 then

			-- update mask to blend out already used inputs
			mask <= prio_enc_mux(ports-2 downto 0);

			-- generic priority encoder with binary encoding, used as multiplexer control signal
			index := 0;
			for i in ports-1 downto 0 loop
				if i_vld(i) = '1' then
					index := i;
				end if;
			end loop;

			index_masked := 0;
			for i in ports-1 downto 0 loop
				if vld_masked(i) = '1' then
					index_masked := i;
				end if;
			end loop;

			if unsigned(vld_masked) = 0 then
				current_input <= index;
			else
				current_input <= index_masked;
			end if;
			i_req_reg <= one_hot;

		end if;

		o <= i(current_input);
		o_vld  <= i_vld(current_input) and i_req_reg(current_input);
		
		if rst = '1' then
			i_req_reg <= (others => '0');
			mask <= (others => '0');
			current_input <= 0;
			o <= default_fragment;
			o_vld <= '0';
		end if;
	end process;

end Behavioral;
