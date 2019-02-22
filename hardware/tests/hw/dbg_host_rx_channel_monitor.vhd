library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dbg_types.counter_width_t;
use work.dbg_types.increment_cnt;

entity host_rx_counter_dbg is
	port(
		clk : in std_logic;
		rst : in std_logic;

		host_kbuffer_vld : in boolean;
		host_kbuffer_size : in natural;
		host_kbuffer_cnt : out counter_width_t;
		host_kbuffer_total : out counter_width_t;

		host_get_transferred_vld : in boolean;
		host_get_transferred_cnt : out counter_width_t;

		root_cpl_vld : in boolean;
		root_cpl_size : in natural;
		root_cpl_cnt : out counter_width_t;
		root_cpl_total : out counter_width_t;

		channel_mrd_vld : in boolean;
		channel_mrd_size : in natural;
		channel_mrd_cnt : out counter_width_t;
		channel_mrd_total : out counter_width_t;

		channel_interrupt_vld : in boolean;
		channel_interrupt_cnt : out counter_width_t;

		channel_get_transferred_vld : in boolean;
		channel_get_transferred_cnt : out counter_width_t
	);
end entity host_rx_counter_dbg;

architecture RTL of host_rx_counter_dbg is
begin
	process
	begin
		wait until rising_edge(clk);
		increment_cnt(rst, host_kbuffer_cnt,            host_kbuffer_vld              );
		increment_cnt(rst, host_kbuffer_total,          host_kbuffer_vld,            host_kbuffer_size);
		increment_cnt(rst, host_get_transferred_cnt,    host_get_transferred_vld             );
		increment_cnt(rst, root_cpl_cnt,                root_cpl_vld             );
		increment_cnt(rst, root_cpl_total,              root_cpl_vld,                root_cpl_size    );
		increment_cnt(rst, channel_mrd_cnt,             channel_mrd_vld              );
		increment_cnt(rst, channel_mrd_total,           channel_mrd_vld,             channel_mrd_size );
		increment_cnt(rst, channel_interrupt_cnt,       channel_interrupt_vld             );
		increment_cnt(rst, channel_get_transferred_cnt, channel_get_transferred_vld            );
	end process;

end architecture RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie;
use work.host_channel_types.all;
use work.transceiver_128bit_types.all;

use work.dbg_types.counter_width_t;

entity host_rx_monitor_dbg is
	port(
		clk : in std_logic;
		rst : in std_logic;

		rq_instr_vld : in std_logic;
		rq_instr : in requester_instr_t;

		int_instr_vld : in std_logic;
		int_instr : in interrupt_instr_t;

		cpl : in pcie.fragment;
		cpl_vld : in std_logic;

		writer_vld : in std_logic;
		writer_req : in std_logic;
		writer : in pcie.fragment
	);
end entity host_rx_monitor_dbg;

architecture RTL of host_rx_monitor_dbg is
	attribute mark_debug : string;
	attribute dont_touch : string;
	
	signal host_kbuffer_vld : boolean;
	signal host_kbuffer_size : natural;
	signal host_kbuffer_cnt : counter_width_t;
	signal host_kbuffer_total : counter_width_t;
	signal host_get_transferred_vld : boolean;
	signal host_get_transferred_cnt : counter_width_t;
	signal root_cpl_vld : boolean;
	signal root_cpl_size : natural;
	signal root_cpl_cnt : counter_width_t;
	signal root_cpl_total : counter_width_t;
	signal channel_mrd_vld : boolean;
	signal channel_mrd_size : natural;
	signal channel_mrd_cnt : counter_width_t;
	signal channel_mrd_total : counter_width_t;
	signal channel_interrupt_vld : boolean;
	signal channel_interrupt_cnt : counter_width_t;
	signal channel_get_transferred_vld : boolean;
	signal channel_get_transferred_cnt : counter_width_t;
	
	attribute mark_debug of host_kbuffer_vld              : signal is "true";   attribute dont_touch of host_kbuffer_vld              : signal is "true"; 
	attribute mark_debug of host_kbuffer_size             : signal is "true";   attribute dont_touch of host_kbuffer_size             : signal is "true"; 
	attribute mark_debug of host_kbuffer_cnt              : signal is "true";   attribute dont_touch of host_kbuffer_cnt              : signal is "true"; 
	attribute mark_debug of host_kbuffer_total            : signal is "true";   attribute dont_touch of host_kbuffer_total            : signal is "true"; 
	-- attribute mark_debug of host_get_transferred_vld      : signal is "true";   attribute dont_touch of host_get_transferred_vld      : signal is "true"; 
	-- attribute mark_debug of host_get_transferred_cnt      : signal is "true";   attribute dont_touch of host_get_transferred_cnt      : signal is "true"; 
	attribute mark_debug of root_cpl_vld                  : signal is "true";   attribute dont_touch of root_cpl_vld                  : signal is "true"; 
	attribute mark_debug of root_cpl_size                 : signal is "true";   attribute dont_touch of root_cpl_size                 : signal is "true"; 
	attribute mark_debug of root_cpl_cnt                  : signal is "true";   attribute dont_touch of root_cpl_cnt                  : signal is "true"; 
	attribute mark_debug of root_cpl_total                : signal is "true";   attribute dont_touch of root_cpl_total                : signal is "true"; 
	-- attribute mark_debug of channel_mrd_vld               : signal is "true";   attribute dont_touch of channel_mrd_vld               : signal is "true"; 
	-- attribute mark_debug of channel_mrd_size              : signal is "true";   attribute dont_touch of channel_mrd_size              : signal is "true"; 
	-- attribute mark_debug of channel_mrd_cnt               : signal is "true";   attribute dont_touch of channel_mrd_cnt               : signal is "true"; 
	-- attribute mark_debug of channel_mrd_total             : signal is "true";   attribute dont_touch of channel_mrd_total             : signal is "true"; 
	-- attribute mark_debug of channel_interrupt_vld         : signal is "true";   attribute dont_touch of channel_interrupt_vld         : signal is "true"; 
	-- attribute mark_debug of channel_interrupt_cnt         : signal is "true";   attribute dont_touch of channel_interrupt_cnt         : signal is "true"; 
	-- attribute mark_debug of channel_get_transferred_vld   : signal is "true";   attribute dont_touch of channel_get_transferred_vld   : signal is "true"; 
	-- attribute mark_debug of channel_get_transferred_cnt   : signal is "true";   attribute dont_touch of channel_get_transferred_cnt   : signal is "true"; 
	
begin

	process
	begin
		wait until rising_edge(clk);
		host_kbuffer_vld            <= true when rq_instr_vld = '1' and (rq_instr.instr = TRANSFER_DMA32 or rq_instr.instr = TRANSFER_DMA64) else false;
		host_get_transferred_vld    <= true when int_instr_vld = '1' and int_instr.instr = GET_TRANSFERRED_BYTES else false;
		root_cpl_vld                <= true when cpl_vld = '1' and cpl.sof = '1' else false;
		
		channel_mrd_vld             <= true when writer_vld = '1' and writer_req = '1' and (get_type(writer) = MRd32_desc or get_type(writer) = MRd64_desc) and writer.sof = '1' else false;
		channel_interrupt_vld       <= true when writer_vld = '1' and writer_req = '1' and get_type(writer) = MSIX_desc and writer.sof = '1' else false;
		channel_get_transferred_vld <= true when writer_vld = '1' and writer_req = '1' and get_type(writer) = CplD_desc and writer.sof = '1' else false;
		
		host_kbuffer_size <= to_integer(rq_instr.dma_size);
		root_cpl_size     <= to_integer(unsigned(to_common_dw0(get_dword(cpl, 0)).length));
		channel_mrd_size  <= to_integer(unsigned(to_common_dw0(get_dword(writer, 0)).length));
	end process;
	
	cnt: entity work.host_rx_counter_dbg
		port map(
			clk => clk,
			rst => rst,
			host_kbuffer_vld => host_kbuffer_vld,
			host_kbuffer_size => host_kbuffer_size,
			host_kbuffer_cnt => host_kbuffer_cnt,
			host_kbuffer_total => host_kbuffer_total,
			host_get_transferred_vld => host_get_transferred_vld,
			host_get_transferred_cnt => host_get_transferred_cnt,
			root_cpl_vld => root_cpl_vld,
			root_cpl_size => root_cpl_size,
			root_cpl_cnt => root_cpl_cnt,
			root_cpl_total => root_cpl_total,
			channel_mrd_vld => channel_mrd_vld,
			channel_mrd_size => channel_mrd_size,
			channel_mrd_cnt => channel_mrd_cnt,
			channel_mrd_total => channel_mrd_total,
			channel_interrupt_vld => channel_interrupt_vld,
			channel_interrupt_cnt => channel_interrupt_cnt,
			channel_get_transferred_vld => channel_get_transferred_vld,
			channel_get_transferred_cnt => channel_get_transferred_cnt
		);
end architecture RTL;
