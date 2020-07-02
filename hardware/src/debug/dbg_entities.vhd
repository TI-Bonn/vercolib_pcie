library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dbg_dma_interrupt_handler is
	port (
		state                     : in std_ulogic_vector(1 downto 0);
		transferred_dwords        : in unsigned(29 downto 0);
		stored_transferred_dwords : in unsigned(29 downto 0)
	);
end entity;

architecture dbg of dbg_dma_interrupt_handler is
	signal dbg_interrupt_handler_state   : std_ulogic_vector(1 downto 0);
	signal dbg_transferred_dwords        : unsigned(29 downto 0);
	signal dbg_stored_transferred_dwords : unsigned(29 downto 0);

	attribute mark_debug : string;
	attribute mark_debug of dbg_interrupt_handler_state   : signal is "true";
	attribute mark_debug of dbg_transferred_dwords        : signal is "true";
	attribute mark_debug of dbg_stored_transferred_dwords : signal is "true";
begin
	dbg_interrupt_handler_state   <= state;
	dbg_transferred_dwords        <= transferred_dwords;
	dbg_stored_transferred_dwords <= stored_transferred_dwords;
end architecture;


library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dbg_dma_requester is
	generic(
		MRS_DWORDS_WIDTH  : in natural
	);
	port (
		state         : in std_ulogic_vector(1 downto 0);
		transfer_size : in unsigned(29 downto 0);
		MRd_size      : in unsigned(MRS_DWORDS_WIDTH-1 downto 0)
	);
end;

architecture dbg of dbg_dma_requester is
	signal dbg_state         : std_ulogic_vector(1 downto 0);
	signal dbg_transfer_size : unsigned(29 downto 0);
	signal dbg_MRd_size      : unsigned(MRS_DWORDS_WIDTH-1 downto 0);

	attribute mark_debug : string;
	attribute mark_debug of dbg_state          : signal is "true";
	attribute mark_debug of dbg_transfer_size  : signal is "true";
	attribute mark_debug of dbg_MRd_size       : signal is "true";
begin
	dbg_state         <= state;
	dbg_transfer_size <= transfer_size;
	dbg_MRd_size      <= MRd_size;
end;


library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.pcie.tx_stream;
use work.pcie.fragment;
entity dbg_dma_writer_packer is
	port (
		clk             : in std_ulogic;
		rst             : in std_ulogic;
		in_payload      : in tx_stream;
		in_payload_vld  : in std_ulogic;
		in_payload_req  : in unsigned(2 downto 0);
		out_packet      : in fragment;
		out_packet_vld  : in std_ulogic;
		out_packet_req  : in std_ulogic;

		state           : in std_ulogic_vector(1 downto 0);
		payload_counter : in unsigned(9 downto 0);
		payload_req_cnt : in unsigned(2 downto 0);
		o_eot           : in std_ulogic
	);
end;

use work.host_channel_types.keep2cnt;
architecture dbg of dbg_dma_writer_packer is
	signal dbg_state           : std_ulogic_vector(1 downto 0);
	signal dbg_payload_counter : unsigned(9 downto 0);
	signal dbg_payload_req_cnt : unsigned(2 downto 0);
	signal dbg_o_eot           : std_ulogic;
	signal dbg_in_payload_dw   : natural := 0;
	signal dbg_out_payload_dw  : natural := 0;

	attribute mark_debug : string;
	attribute mark_debug of dbg_state           : signal is "true";
	attribute mark_debug of dbg_payload_counter : signal is "true";
	attribute mark_debug of dbg_payload_req_cnt : signal is "true";
	attribute mark_debug of dbg_o_eot           : signal is "true";
	attribute mark_debug of dbg_in_payload_dw   : signal is "true";
	attribute mark_debug of dbg_out_payload_dw  : signal is "true";
begin
	dbg_state           <= state;
	dbg_payload_counter <= payload_counter;
	dbg_payload_req_cnt <= payload_req_cnt;
	dbg_o_eot           <= o_eot;

	process
	begin
		wait until rising_edge(clk);

		if (in_payload_vld and (or in_payload_req)) = '1' then
			if(in_payload_req >= in_payload.cnt) then
				dbg_in_payload_dw <= dbg_in_payload_dw + to_integer(in_payload.cnt);
			else
				dbg_in_payload_dw <= dbg_in_payload_dw + to_integer(in_payload_req);
			end if;
		end if;

		if (out_packet_vld and out_packet_req and (not out_packet.sof)) = '1' then
			dbg_out_payload_dw <= dbg_out_payload_dw + to_integer(keep2cnt(out_packet.keep));
		end if;

	end process;
end;


library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dbg_tx_dma_fifo is
	port (
		fifo_state      : in std_ulogic_vector(1 downto 0);
		rst_state       : in std_ulogic;
		data_cnt        : in unsigned(11 downto 0);
		end_of_transfer : in std_ulogic;
		i_req           : in std_ulogic;
		i_vld           : in std_ulogic
	);
end;

architecture dbg of dbg_tx_dma_fifo is
	signal dbg_fifo_state      : std_ulogic_vector(1 downto 0);
	signal dbg_rst_state       : std_ulogic;
	signal dbg_data_cnt        : unsigned(11 downto 0);
	signal dbg_end_of_transfer : std_ulogic;
	signal dbg_i_req           : std_ulogic;
	signal dbg_i_vld           : std_ulogic;

	attribute mark_debug : string;
	attribute mark_debug of dbg_fifo_state      : signal is "true";
	attribute mark_debug of dbg_rst_state       : signal is "true";
	attribute mark_debug of dbg_data_cnt        : signal is "true";
	attribute mark_debug of dbg_end_of_transfer : signal is "true";
	attribute mark_debug of dbg_i_req           : signal is "true";
	attribute mark_debug of dbg_i_vld           : signal is "true";
begin
	dbg_fifo_state      <= fifo_state;
	dbg_rst_state       <= rst_state;
	dbg_data_cnt        <= data_cnt;
	dbg_end_of_transfer <= end_of_transfer;
	dbg_i_req           <= i_req;
	dbg_i_vld           <= i_vld;
end;

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.pcie.tx_stream;
entity dbg_tx_dma_writer_buffer is
	port (
		clk           : in std_ulogic;
		rst           : in std_ulogic;
		input_vld     : in std_ulogic;
		input         : in tx_stream;
		input_req     : in std_ulogic;
		output_vld    : in std_ulogic;
		output_req    : in unsigned(2 downto 0);
		buf_cnt       : in unsigned(1 downto 0);
		buf_eot       : in std_ulogic;
		enough_in_buf : in std_ulogic;
		buf_ptr       : in unsigned(1 downto 0);
		count         : in unsigned(11 downto 0);
		eot           : in std_ulogic
	);
end;

architecture dbg of dbg_tx_dma_writer_buffer is
	signal dbg_buf_cnt       : unsigned(1 downto 0);
	signal dbg_buf_eot       : std_logic;
	signal dbg_enough_in_buf : std_logic;
	signal dbg_buf_ptr       : unsigned(1 downto 0);
	signal dbg_count         : unsigned(11 downto 0);
	signal dbg_eot           : std_ulogic;
	signal dbg_input_count   : natural := 0;
	signal dbg_output_count  : natural := 0;

	attribute mark_debug : string;
	attribute mark_debug of dbg_buf_cnt       : signal is "true";
	attribute mark_debug of dbg_buf_eot       : signal is "true";
	attribute mark_debug of dbg_enough_in_buf : signal is "true";
	attribute mark_debug of dbg_buf_ptr       : signal is "true";
	attribute mark_debug of dbg_count         : signal is "true";
	attribute mark_debug of dbg_eot           : signal is "true";
	attribute mark_debug of dbg_input_count   : signal is "true";
	attribute mark_debug of dbg_output_count  : signal is "true";
begin
	dbg_buf_cnt        <= buf_cnt;
	dbg_buf_eot        <= buf_eot;
	dbg_enough_in_buf  <= enough_in_buf;
	dbg_buf_ptr        <= buf_ptr;
	dbg_count          <= count;
	dbg_eot            <= eot;

	process
	begin
		wait until rising_edge(clk);
		if (input_vld and input_req) = '1' then
			dbg_input_count <= dbg_input_count + to_integer(input.cnt);
		end if;
		if (output_vld and (or output_req)) = '1' then
			dbg_output_count <= dbg_output_count + to_integer(output_req);
		end if;
	end process;
end;
