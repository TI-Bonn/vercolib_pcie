library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dbg_types.all;

entity host_tx_counter_dbg is
	port(
		clk : in std_logic;
		rst : in std_logic;

		host_kbuffer_vld : in boolean;
		host_kbuffer_size : in natural;
		host_kbuffer_cnt : out counter_width_t;
		host_kbuffer_total : out counter_width_t;

		host_get_transferred_vld : in boolean;
		host_get_transferred_cnt : out counter_width_t;

		channel_mwr_vld : in boolean;
		channel_mwr_size : in natural;
		channel_mwr_cnt : out counter_width_t;
		channel_mwr_total : out counter_width_t;

		channel_interrupt_vld : in boolean;
		channel_interrupt_cnt : out counter_width_t;

		channel_get_transferred_vld : in boolean;
		channel_get_transferred_cnt : out counter_width_t
	);
end entity host_tx_counter_dbg;

architecture RTL of host_tx_counter_dbg is
begin
	process
	begin
		wait until rising_edge(clk);
		increment_cnt(rst, host_kbuffer_cnt,            host_kbuffer_vld              );
		increment_cnt(rst, host_kbuffer_total,          host_kbuffer_vld,            host_kbuffer_size);
		increment_cnt(rst, host_get_transferred_cnt,    host_get_transferred_vld             );
		increment_cnt(rst, channel_mwr_cnt,             channel_mwr_vld              );
		increment_cnt(rst, channel_mwr_total,           channel_mwr_vld,             channel_mwr_size );
		increment_cnt(rst, channel_interrupt_cnt,       channel_interrupt_vld            );
		increment_cnt(rst, channel_get_transferred_cnt, channel_get_transferred_vld            );
	end process;
end architecture RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie;
use work.host_channel_types.all;
use work.transceiver_128bit_types.all;

use work.dbg_types.all;

entity host_tx_monitor_dbg is
	port(
		clk : in std_logic;
		rst : in std_logic;

		rq_instr_vld : in std_logic;
		rq_instr : in requester_instr_t;

		int_instr_vld : in std_logic;
		int_instr : in interrupt_instr_t;

		writer : in pcie.fragment;
		writer_vld : in std_logic;
		writer_req : in std_logic
	);
end entity host_tx_monitor_dbg;

architecture RTL of host_tx_monitor_dbg is
	attribute mark_debug : string;
	attribute dont_touch : string;
	
	signal host_kbuffer_vld : boolean;
	signal host_kbuffer_size : natural;
	signal host_kbuffer_cnt : counter_width_t;
	signal host_kbuffer_total : counter_width_t;
	signal host_get_transferred_vld : boolean;
	signal host_get_transferred_cnt : counter_width_t;
	signal channel_mwr_vld : boolean;
	signal channel_mwr_size : natural;
	signal channel_mwr_cnt : counter_width_t;
	signal channel_mwr_total : counter_width_t;
	signal channel_interrupt_vld : boolean;
	signal channel_interrupt_cnt : counter_width_t;
	signal channel_get_transferred_vld : boolean;
	signal channel_get_transferred_cnt : counter_width_t;
	
	attribute mark_debug of host_kbuffer_vld              : signal is "true";  attribute dont_touch of host_kbuffer_vld              : signal is "true";
	attribute mark_debug of host_kbuffer_size             : signal is "true";  attribute dont_touch of host_kbuffer_size             : signal is "true";
	attribute mark_debug of host_kbuffer_cnt              : signal is "true";  attribute dont_touch of host_kbuffer_cnt              : signal is "true";
	attribute mark_debug of host_kbuffer_total            : signal is "true";  attribute dont_touch of host_kbuffer_total            : signal is "true";
	-- attribute mark_debug of host_get_transferred_vld      : signal is "true";  attribute dont_touch of host_get_transferred_vld      : signal is "true";
	-- attribute mark_debug of host_get_transferred_cnt      : signal is "true";  attribute dont_touch of host_get_transferred_cnt      : signal is "true";
	attribute mark_debug of channel_mwr_vld               : signal is "true";  attribute dont_touch of channel_mwr_vld               : signal is "true";
	attribute mark_debug of channel_mwr_size              : signal is "true";  attribute dont_touch of channel_mwr_size              : signal is "true";
	attribute mark_debug of channel_mwr_cnt               : signal is "true";  attribute dont_touch of channel_mwr_cnt               : signal is "true";
	attribute mark_debug of channel_mwr_total             : signal is "true";  attribute dont_touch of channel_mwr_total             : signal is "true";
	-- attribute mark_debug of channel_interrupt_vld         : signal is "true";  attribute dont_touch of channel_interrupt_vld         : signal is "true";
	-- attribute mark_debug of channel_interrupt_cnt         : signal is "true";  attribute dont_touch of channel_interrupt_cnt         : signal is "true";
	-- attribute mark_debug of channel_get_transferred_vld   : signal is "true";  attribute dont_touch of channel_get_transferred_vld   : signal is "true";
	-- attribute mark_debug of channel_get_transferred_cnt   : signal is "true";  attribute dont_touch of channel_get_transferred_cnt   : signal is "true";
	
begin

	process
	begin
		wait until rising_edge(clk);
		host_kbuffer_vld            <= true when rq_instr_vld = '1' and (rq_instr.instr = TRANSFER_DMA32 or rq_instr.instr = TRANSFER_DMA64) else false;
		host_get_transferred_vld    <= true when int_instr_vld = '1' and int_instr.instr = GET_TRANSFERRED_BYTES else false;

		channel_mwr_vld             <= true when writer_vld = '1' and writer_req = '1' and (get_type(writer) = MWr32_desc or get_type(writer) = MWr64_desc)  and writer.sof = '1' else false;
		channel_interrupt_vld       <= true when writer_vld = '1' and writer_req = '1' and get_type(writer) = MSIX_desc and writer.sof = '1' else false;
		channel_get_transferred_vld <= true when writer_vld = '1' and writer_req = '1' and get_type(writer) = CplD_desc and writer.sof = '1' else false;
		
		host_kbuffer_size <= to_integer(rq_instr.dma_size);
		channel_mwr_size  <= to_integer(unsigned(to_common_dw0(get_dword(writer, 0)).length));
	end process;
	
	cnt: entity work.host_tx_counter_dbg
		port map(
			clk => clk,
			rst => rst,
			host_kbuffer_vld => host_kbuffer_vld,
			host_kbuffer_size => host_kbuffer_size,
			host_kbuffer_cnt => host_kbuffer_cnt,
			host_kbuffer_total => host_kbuffer_total,
			host_get_transferred_vld => host_get_transferred_vld,
			host_get_transferred_cnt => host_get_transferred_cnt,
			channel_mwr_vld => channel_mwr_vld,
			channel_mwr_size => channel_mwr_size,
			channel_mwr_cnt => channel_mwr_cnt,
			channel_mwr_total => channel_mwr_total,
			channel_interrupt_vld => channel_interrupt_vld,
			channel_interrupt_cnt => channel_interrupt_cnt,
			channel_get_transferred_vld => channel_get_transferred_vld,
			channel_get_transferred_cnt => channel_get_transferred_cnt
		);
end architecture RTL;
