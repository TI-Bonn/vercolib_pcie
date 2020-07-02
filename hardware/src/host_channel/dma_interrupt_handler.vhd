-- Author: Oguzhan Sezenlik

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.transceiver_128bit_types.all;
use work.host_channel_types.all;
use work.utils.all;

use work.channel_types.channel_info_t;
use work.channel_types.new_host_channel_info;
use work.channel_types.to_dw;
use work.channel_types.from_string;

entity dma_interrupt_handler is
	generic(
		debug : boolean := false;

		CHANNEL_ID: natural;

		-- NOTE: We currently need to direction of this channel only
		-- to tell the host what kind of channel we are.
		-- This probably shouldn't be done in the interrupt handler in the first place.
		-- However, this is for now the only place where we actually generate completions
		-- for read requests from the host, so for now it lives here.
		direction: string
	);
	port (
		clk : in std_logic;
		rst : in std_logic;

		-- signal to reset requester
		-- in case of an interrupt this signal is active exactly for one clock cycle
		ctrl_rst : out std_logic := '0';

		-- input port from host_channel_decoder
		-- no req signal needed: never blocks input data stream:
		-- ensured by driver-FPGA protocol, otherwise its undefined behaviour
		instr_vld : in std_logic;
		instr     : in interrupt_instr_t;

		-- input ports for data stream to be observed, only length field in header is relevant.
		-- no req signal needed: never interferes with observed data stream.
		transfer_vld    : in std_logic;
		transfer_length : in unsigned(9 downto 0);
		transfer_eot    : in std_logic := '0';
		transfer_eof    : in std_logic := '0';

		-- output port "writer" to writer
		writer_vld     : out std_logic := '0';
		writer_req     : in  std_logic;
		writer         : out tlp_header_info_t;
		writer_payload : out std_logic_vector(31 downto 0)
	);
end entity dma_interrupt_handler;

architecture RTL of dma_interrupt_handler is

	type state_t is (WAIT_FOR_INSTR, WAIT_FOR_DMA_TRANSFER_DONE, TRIG_INTERRUPT, WAIT_FOR_EOF);
	signal state : state_t := WAIT_FOR_INSTR;

	constant channel_info: channel_info_t := new_host_channel_info(
		id => CHANNEL_ID,
		dir => from_string(direction)
	);

	signal transferred_dwords : unsigned(29 downto 0) := (others => '0');
	signal stored_transferred_dwords : unsigned(29 downto 0) := (others => '0');
begin

writer.length      <= to_unsigned(1, 10);
writer.tag         <= instr.cpl_tag;
writer.cpl_lo_addr <= instr.cpl_lo_addr;

observe: process
begin
	wait until rising_edge(clk);
	ctrl_rst <= '0';

	if writer_req = '1' then
		writer_vld <= '0';
	end if;

	case state is
	when WAIT_FOR_INSTR =>

		if instr_vld = '1' then
			case instr.instr is
			when TRANSFER_DMA32 | TRANSFER_DMA64 =>
				state <= WAIT_FOR_DMA_TRANSFER_DONE;
			when GET_TRANSFERRED_BYTES =>
				writer_vld  <= '1';
				writer.desc <= CplD_desc;
				writer_payload <= std_logic_vector(stored_transferred_dwords) & "00";
			when GET_CHANNEL_INFO =>
				writer_vld <= '1';
				writer.desc <= CplD_desc;
				writer_payload <= to_dw(channel_info);
			end case;
		end if;

	when WAIT_FOR_DMA_TRANSFER_DONE =>

		-- trigger interrupt if dma transfer is finished
		if instr.dma_size = (transferred_dwords & "00") then
			state <= WAIT_FOR_EOF;
		end if;

	when WAIT_FOR_EOF =>
		if transfer_eof = '1' then
			state <= TRIG_INTERRUPT;

			-- reset tx_channel
			ctrl_rst <= '1';
		end if;

	when TRIG_INTERRUPT =>
		ctrl_rst <= '0';

		-- save current transferred dword count for writer
		-- and reset internal data counter
		transferred_dwords <= (others => '0');
		stored_transferred_dwords <= transferred_dwords;

		-- generate a msix packet (interrupt)
		writer_vld  <= '1';
		writer.desc <= MSIX_desc;

		state    <= WAIT_FOR_INSTR;
	end case;

	-- observe data stream and count transferred dwords
	if transfer_vld = '1' then
		transferred_dwords <= transferred_dwords + transfer_length;

		-- only in tx_upstream_channel:
		-- trigger an interrupt if user core is finished with transferring data
		if transfer_eot = '1' then
			state <= WAIT_FOR_EOF;
		end if;
	end if;

	if rst = '1' then
		state <= WAIT_FOR_INSTR;
		transferred_dwords <= (others => '0');
		writer_vld <= '0';
	end if;
end process;

dbg: if debug generate
	signal dbg_state : std_ulogic_vector(1 downto 0);
begin
	dbg_state <= "00" when state = WAIT_FOR_INSTR else
	             "01" when state = WAIT_FOR_DMA_TRANSFER_DONE else
	             "10" when state = TRIG_INTERRUPT else
	             "11" when state = WAIT_FOR_EOF else
				 "00";

	dbg_mon: entity work.dbg_dma_interrupt_handler
	port map(
		state                     => dbg_state,
		transferred_dwords        => transferred_dwords,
		stored_transferred_dwords => stored_transferred_dwords
	);
end generate;

end architecture RTL;
