---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:
-- Description: decodes host instructions from parsed memory requests
-- Version: 	0.1
---------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.transceiver_128bit_types.all;
use work.host_channel_types.all;

entity dma_decoder_instructor is
	generic(
		CHANNEL_ID : natural := 1
	);
	port (
		-- control signals
		rst     : in std_logic;
		clk     : in std_logic;

		-- input for parsed memory requests
		-- never blocks input
		rq_vld     : in std_logic;
		rq_type    : in request_t;
		rq_tag     : in unsigned(7 downto 0);
		rq_payload : in std_logic_vector(31 downto 0);
		rq_addr    : in unsigned(3 downto 0);

		-- output for decoded instructions
		-- to requester
		rq_instr_vld : out std_logic := '0';
		rq_instr     : out requester_instr_t;

		-- to interrupt_handler
		int_instr_vld : out std_logic := '0';
		int_instr     : out interrupt_instr_t
	);
end entity dma_decoder_instructor;

architecture RTL of dma_decoder_instructor is

constant CHANNEL_ID_SLV : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(CHANNEL_ID, 8));

signal instruction : instruction_t;
signal dma_addr    : unsigned(63 downto 0) := (others => '0');
signal dma_size    : unsigned(31 downto 0) := (others => '0');
signal cpl_tag     : unsigned( 7 downto 0) := (others => '0');
signal cpl_lo_addr : std_logic_vector(6 downto 0) := (others => '0');

signal instr_vld   : std_logic := '0';

begin

rq_instr_vld  <= instr_vld;
int_instr_vld <= instr_vld;

rq_instr.instr    <= instruction;
rq_instr.dma_addr <= dma_addr;
rq_instr.dma_size <= dma_size;

int_instr.instr       <= instruction;
int_instr.dma_size    <= dma_size;
int_instr.cpl_tag     <= cpl_tag;
int_instr.cpl_lo_addr <= cpl_lo_addr;

decode: process
begin
	wait until rising_edge(clk);

	instr_vld <= '0';

	if rq_vld = '1' then
		case rq_type is
		when MWr =>

			case rq_addr is
			when ADDR_LO_REG =>
				dma_addr(31 downto 0) <= unsigned(rq_payload);
				instruction <= TRANSFER_DMA32;
			when ADDR_HI_REG =>
				dma_addr(63 downto 32) <= unsigned(rq_payload);
				if unsigned(rq_payload) /= 0 then  -- if upper 32 bits of dma buffer address is 0 -> remain in 32-bit mode
					instruction <= TRANSFER_DMA64;
				end if;
			when BUFFER_SIZE =>
				dma_size  <= unsigned(rq_payload);
				instr_vld <= '1';
			when others => null;
			end case;

		when MRd =>

			case rq_addr is
			when TRANSFERRED_REG =>
				instruction <= GET_TRANSFERRED_BYTES;
				cpl_tag     <= rq_tag;
				instr_vld   <= '1';
				-- lower address for memory completion consists of
				-- LSB of CHANNEL_ID and targeted BAR address
				cpl_lo_addr <= CHANNEL_ID_SLV(0) & std_logic_vector(rq_addr) & "00";
			when CHANNEL_INFO_REG =>
				instruction <= GET_CHANNEL_INFO;
				cpl_tag     <= rq_tag;
				instr_vld   <= '1';
				cpl_lo_addr <= CHANNEL_ID_SLV(0) & std_logic_vector(rq_addr) & "00";
			when others => null;
			end case;
		end case;
	end if;

	if rst = '1' then
		instr_vld <= '0';
	end if;
end process;

end architecture RTL;
