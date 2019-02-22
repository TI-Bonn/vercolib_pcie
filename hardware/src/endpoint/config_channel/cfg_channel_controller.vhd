---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description:	Control-unit, which handles HOST-FPGA information communication
-- Version: 	0.1
---------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils.all;
use work.transceiver_128bit_types.all;
use work.cfg_channel_types.all;

entity cfg_channel_controller is
	port(
		clk      : in  std_ulogic;

		rst_host_channel : out std_ulogic := '0';
		rst_fpga_channel : out std_ulogic := '0';
		rst_endpoint     : out std_ulogic := '0';

		-- decoder input ports
		op_code  : in  op_code_t;
		op_addr  : in  cfg_reg_addr_t := 0;
		op_data  : in  std_ulogic_vector(31 downto 0) := (others => '0');
		op_vld   : in  std_ulogic := '0';
		op_tag   : in  std_ulogic_vector( 7 downto 0);
		op_ready : out std_ulogic := '0';              -- enables cfg_decoder input ports

		-- memory input/output ports
		mem_addr     : out cfg_reg_addr_t := 0;
		mem_wr_data  : out std_ulogic_vector(31 downto 0) := (others => '0');
		mem_wr_en    : out std_ulogic := '0';
		mem_rd_data  : in  std_ulogic_vector(31 downto 0) := (others => '0');
		mem_rd_en    : out std_ulogic := '0';

		-- completer output ports
		cpld_payload : out std_ulogic_vector(31 downto 0);
		cpld_lo_addr : out std_ulogic_vector( 6 downto 0);
		cpld_tag     : out std_ulogic_vector( 7 downto 0);
		cpld_vld     : out std_ulogic := '0';
		cpld_done    : in  std_ulogic
	);
end cfg_channel_controller;

architecture arch of cfg_channel_controller is

	type state_t is (RESET, IDLE, READ_MEM_AND_SEND_CPLD, EXEC_INSTR);
	signal state : state_t := IDLE;

	constant rst_cc : positive := 10;
	signal rst_counter : integer range 0 to rst_cc := rst_cc;
	signal host_instruction : std_ulogic_vector(31 downto 0);

begin

cpld_tag     <= op_tag;
cpld_lo_addr <= '0' & std_logic_vector(to_unsigned(op_addr, 4)) & "00";  -- this is channel 0
cpld_payload <= mem_rd_data;

mem_addr    <= op_addr;
mem_wr_data <= op_data;
mem_wr_en   <= '1' when op_code = WR_REG or op_code = INSTR else '0';
mem_rd_en   <= '1' when op_code = RD_REG else '0';

-- disable output register of decoder if host wants to read a register while
-- FSM is busy with a previous read instruction.
-- Writing a register is always possible
op_ready <= '1' when state = IDLE or op_code = WR_REG  else '0';

main: process
begin
	wait until rising_edge(clk);
	host_instruction <= op_data;

	case state is
	when IDLE =>
		if op_vld = '1' then
			case op_code is
			when RD_REG =>
				state <= READ_MEM_AND_SEND_CPLD;
				cpld_vld <= '1';
			when INSTR =>
				state <= EXEC_INSTR;
			when others => null;
			end case;
		end if;

	-- fsm freezes current state of "op" input signal
	-- until completer finishes with responding to host
	when READ_MEM_AND_SEND_CPLD =>
		if cpld_done = '1' then
			state    <= IDLE;
			cpld_vld <= '0';
		end if;

	-- execute host instruction
	when EXEC_INSTR =>
		if host_instruction(RESET_TRANSCEIVER) = '1' then
			rst_endpoint     <= '1';
			rst_host_channel <= '1';
			rst_fpga_channel <= '1';
			state <= RESET;
		end if;
		if host_instruction(RESET_HOST_CHANNEL) = '1' then
			rst_host_channel <= '1';
			state <= RESET;
		end if;
		if host_instruction(RESET_FPGA_CHANNEL) = '1' then
			rst_fpga_channel <= '1';
			state <= RESET;
		end if;
	when RESET =>
		rst_counter <= rst_counter - 1;
		cpld_vld <= '0';
		
		if rst_counter = 0 then
			state <= IDLE;
			rst_counter <= rst_cc;
			
			-- defaults:
			rst_endpoint     <= '0';
			rst_host_channel <= '0';
			rst_fpga_channel <= '0';
		end if;
	end case;
end process;

end architecture;
