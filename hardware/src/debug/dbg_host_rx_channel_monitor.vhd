-- Author: Oguzhan Sezenlik

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dbg_types.counter_width_t;
use work.dbg_types.increment_cnt;

entity host_rx_counter_dbg is
	port(
		clk : in std_logic;
		rst : in std_logic;

		host_kbuffer_vld              : in  boolean         := false;
		host_kbuffer_size             : in  natural         := 0;
		host_kbuffer_cnt              : out counter_width_t := (others => '0');
		host_kbuffer_total            : out counter_width_t := (others => '0');
		host_get_transferred_vld      : in  boolean         := false;
		host_get_transferred_cnt      : out counter_width_t := (others => '0');
		root_cpl_vld                  : in  boolean         := false;
		root_cpl_size                 : in  counter_width_t := (others => '0');
		root_cpl_cnt                  : out counter_width_t := (others => '0');
		root_cpl_total                : out counter_width_t := (others => '0');
		channel_mrd_vld               : in  boolean         := false;
		channel_mrd_size              : in  counter_width_t := (others => '0');
		channel_mrd_cnt               : out counter_width_t := (others => '0');
		channel_mrd_total             : out counter_width_t := (others => '0');
		channel_interrupt_vld         : in  boolean         := false;
		channel_interrupt_cnt         : out counter_width_t := (others => '0');
		channel_get_transferred_vld   : in  boolean         := false;
		channel_get_transferred_size  : in  natural         := 0;
		channel_get_transferred_cnt   : out counter_width_t := (others => '0');
		channel_get_transferred_total : out counter_width_t := (others => '0');
		user_design_vld               : in  boolean         := false;
		user_design_size              : in  counter_width_t := (others => '0');
		user_design_cnt               : out counter_width_t := (others => '0');
		user_design_total             : out counter_width_t := (others => '0');
		buffer_tag_vld                : in  boolean         := false;
		buffer_tag_cnt                : out counter_width_t := (others => '0')
	);
end entity host_rx_counter_dbg;

architecture RTL of host_rx_counter_dbg is
	signal nat_cpl_size, nat_mrd_size, nat_user_design_size: natural;
begin
	nat_cpl_size <= to_integer(root_cpl_size);
	nat_mrd_size <= to_integer(channel_mrd_size);
	nat_user_design_size <= to_integer(user_design_size);
	process
	begin
		wait until rising_edge(clk);
		increment_cnt(rst,
			host_kbuffer_cnt,
			host_kbuffer_vld
		);
		increment_cnt(rst,
			host_kbuffer_total,
			host_kbuffer_vld,
			host_kbuffer_size
		);
		increment_cnt(rst,
			host_get_transferred_cnt,
			host_get_transferred_vld
		);
		increment_cnt(rst,
			root_cpl_cnt,
			root_cpl_vld
		);
		increment_cnt(rst,
			root_cpl_total,
			root_cpl_vld,
			nat_cpl_size
		);
		increment_cnt(rst,
			channel_mrd_cnt,
			channel_mrd_vld
		);
		increment_cnt(rst,
			channel_mrd_total,
			channel_mrd_vld,
			nat_mrd_size
		);
		increment_cnt(rst,
			channel_interrupt_cnt,
			channel_interrupt_vld
		);
		increment_cnt(rst,
			channel_get_transferred_cnt,
			channel_get_transferred_vld
		);
		increment_cnt(rst,
			channel_get_transferred_total,
			channel_get_transferred_vld,
			channel_get_transferred_size
		);
		increment_cnt(rst,
			user_design_cnt,
			user_design_vld
		);
		increment_cnt(rst,
			user_design_total,
			user_design_vld,
			nat_user_design_size
		);
		increment_cnt(rst,
			buffer_tag_cnt,
			buffer_tag_vld
		);
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
		rq_instr     : in requester_instr_t;

		int_instr_vld : in std_logic;
		int_instr     : in interrupt_instr_t;

		cpl     : in pcie.fragment;
		cpl_vld : in std_logic;

		writer_vld : in std_logic;
		writer_req : in std_logic;
		writer     : in pcie.fragment;

		user_vld : in std_logic;
		user_req : in std_logic;
		user     : in pcie.rx_stream;

		tag_vld  : in std_logic;
		tag_req  : in std_logic
	);
end entity host_rx_monitor_dbg;

architecture RTL of host_rx_monitor_dbg is
	attribute mark_debug : string;
	attribute dont_touch : string;


	signal host_kbuffer_vld              : boolean         := false;
	signal host_kbuffer_size             : natural         := 0;
	signal host_kbuffer_cnt              : counter_width_t := (others => '0');
	signal host_kbuffer_total            : counter_width_t := (others => '0');
	signal host_get_transferred_vld      : boolean         := false;
	signal host_get_transferred_cnt      : counter_width_t := (others => '0');
	signal root_cpl_vld                  : boolean         := false;
	signal root_cpl_size                 : counter_width_t := (others => '0');
	signal root_cpl_cnt                  : counter_width_t := (others => '0');
	signal root_cpl_total                : counter_width_t := (others => '0');
	signal channel_mrd_vld               : boolean         := false;
	signal channel_mrd_size              : counter_width_t := (others => '0');
	signal channel_mrd_cnt               : counter_width_t := (others => '0');
	signal channel_mrd_total             : counter_width_t := (others => '0');
	signal channel_interrupt_vld         : boolean         := false;
	signal channel_interrupt_cnt         : counter_width_t := (others => '0');
	signal channel_get_transferred_vld   : boolean         := false;
	signal channel_get_transferred_size  : natural         := 0;
	signal channel_get_transferred_cnt   : counter_width_t := (others => '0');
	signal channel_get_transferred_total : counter_width_t := (others => '0');
	signal user_design_vld               : boolean         := false;
	signal user_design_size              : counter_width_t := (others => '0');
	signal user_design_cnt               : counter_width_t := (others => '0');
	signal user_design_total             : counter_width_t := (others => '0');
	signal buffer_tag_vld                : boolean         := false;
	signal buffer_tag_cnt                : counter_width_t := (others => '0');

	attribute dont_touch of host_kbuffer_vld              : signal is "true";
	attribute dont_touch of host_kbuffer_size             : signal is "true";
	attribute dont_touch of host_kbuffer_cnt              : signal is "true";
	attribute dont_touch of host_kbuffer_total            : signal is "true";
	attribute dont_touch of host_get_transferred_vld      : signal is "true";
	attribute dont_touch of host_get_transferred_cnt      : signal is "true";
	attribute dont_touch of root_cpl_vld                  : signal is "true";
	attribute dont_touch of root_cpl_size                 : signal is "true";
	attribute dont_touch of root_cpl_cnt                  : signal is "true";
	attribute dont_touch of root_cpl_total                : signal is "true";
	attribute dont_touch of channel_mrd_vld               : signal is "true";
	attribute dont_touch of channel_mrd_size              : signal is "true";
	attribute dont_touch of channel_mrd_cnt               : signal is "true";
	attribute dont_touch of channel_mrd_total             : signal is "true";
	attribute dont_touch of channel_interrupt_vld         : signal is "true";
	attribute dont_touch of channel_interrupt_cnt         : signal is "true";
	attribute dont_touch of channel_get_transferred_vld   : signal is "true";
	attribute dont_touch of channel_get_transferred_size  : signal is "true";
	attribute dont_touch of channel_get_transferred_cnt   : signal is "true";
	attribute dont_touch of channel_get_transferred_total : signal is "true";
	attribute dont_touch of user_design_vld               : signal is "true";
	attribute dont_touch of user_design_size              : signal is "true";
	attribute dont_touch of user_design_cnt               : signal is "true";
	attribute dont_touch of user_design_total             : signal is "true";
	attribute dont_touch of buffer_tag_vld                : signal is "true";
	attribute dont_touch of buffer_tag_cnt                : signal is "true";

	attribute mark_debug of host_kbuffer_vld              : signal is "true";
	attribute mark_debug of host_kbuffer_size             : signal is "true";
	attribute mark_debug of host_kbuffer_cnt              : signal is "true";
	attribute mark_debug of host_kbuffer_total            : signal is "true";
	attribute mark_debug of host_get_transferred_vld      : signal is "true";
	attribute mark_debug of host_get_transferred_cnt      : signal is "true";
	attribute mark_debug of root_cpl_vld                  : signal is "true";
	attribute mark_debug of root_cpl_size                 : signal is "true";
	attribute mark_debug of root_cpl_cnt                  : signal is "true";
	attribute mark_debug of root_cpl_total                : signal is "true";
	attribute mark_debug of channel_mrd_vld               : signal is "true";
	attribute mark_debug of channel_mrd_size              : signal is "true";
	attribute mark_debug of channel_mrd_cnt               : signal is "true";
	attribute mark_debug of channel_mrd_total             : signal is "true";
	attribute mark_debug of channel_interrupt_vld         : signal is "true";
	attribute mark_debug of channel_interrupt_cnt         : signal is "true";
	attribute mark_debug of channel_get_transferred_vld   : signal is "true";
	attribute mark_debug of channel_get_transferred_size  : signal is "true";
	attribute mark_debug of channel_get_transferred_cnt   : signal is "true";
	attribute mark_debug of channel_get_transferred_total : signal is "true";
	attribute mark_debug of user_design_vld               : signal is "true";
	attribute mark_debug of user_design_size              : signal is "true";
	attribute mark_debug of user_design_cnt               : signal is "true";
	attribute mark_debug of user_design_total             : signal is "true";
	attribute mark_debug of buffer_tag_vld                : signal is "true";
	attribute mark_debug of buffer_tag_cnt                : signal is "true";

begin

	process
	begin
		wait until rising_edge(clk);
		host_kbuffer_vld            <= true when
											rq_instr_vld = '1' and
											(rq_instr.instr = TRANSFER_DMA32 or
											 rq_instr.instr = TRANSFER_DMA64)
									   else false;

		host_get_transferred_vld    <= true when
											int_instr_vld = '1' and
											int_instr.instr = GET_TRANSFERRED_BYTES
									   else false;

		root_cpl_vld                <= true when
											cpl_vld = '1' and cpl.sof = '1'
									   else false;

		channel_mrd_vld             <= true when
											writer_vld = '1' and
											writer_req = '1' and
											(get_type(writer) = MRd32_desc or
											 get_type(writer) = MRd64_desc)
											and writer.sof = '1'
									   else false;

		channel_interrupt_vld       <= true when
											writer_vld = '1' and
											writer_req = '1' and
											get_type(writer) = MSIX_desc
											and writer.sof = '1'
									   else false;

		channel_get_transferred_vld <= true when
											writer_vld = '1' and
											writer_req = '1' and
											get_type(writer) = CplD_desc and
											writer.data(69 downto 66) = "0100"
											and writer.sof = '1'
									   else false;

		buffer_tag_vld              <= true when tag_vld and tag_req
									   else false;

		user_design_vld             <= true when user_vld and user_req
									   else false;

		host_kbuffer_size <= to_integer(rq_instr.dma_size);
		root_cpl_size     <= resize(unsigned(to_common_dw0(get_dword(cpl, 0)).length), root_cpl_size'length);
		channel_mrd_size  <= resize(unsigned(to_common_dw0(get_dword(writer, 0)).length), channel_mrd_size'length);

		channel_get_transferred_size <= to_integer(unsigned(writer.data(127 downto 96)));

		user_design_size  <= resize(user.cnt, user_design_size'length);

	end process;

	cnt: entity work.host_rx_counter_dbg
		port map(
			clk => clk,
			rst => rst,
			host_kbuffer_vld              => host_kbuffer_vld,
			host_kbuffer_size             => host_kbuffer_size,
			host_kbuffer_cnt              => host_kbuffer_cnt,
			host_kbuffer_total            => host_kbuffer_total,
			host_get_transferred_vld      => host_get_transferred_vld,
			host_get_transferred_cnt      => host_get_transferred_cnt,
			root_cpl_vld                  => root_cpl_vld,
			root_cpl_size                 => root_cpl_size,
			root_cpl_cnt                  => root_cpl_cnt,
			root_cpl_total                => root_cpl_total,
			channel_mrd_vld               => channel_mrd_vld,
			channel_mrd_size              => channel_mrd_size,
			channel_mrd_cnt               => channel_mrd_cnt,
			channel_mrd_total             => channel_mrd_total,
			channel_interrupt_vld         => channel_interrupt_vld,
			channel_interrupt_cnt         => channel_interrupt_cnt,
			channel_get_transferred_vld   => channel_get_transferred_vld,
			channel_get_transferred_size  => channel_get_transferred_size,
			channel_get_transferred_cnt   => channel_get_transferred_cnt,
			channel_get_transferred_total => channel_get_transferred_total,
			user_design_vld               => user_design_vld,
			user_design_size              => user_design_size,
			user_design_cnt               => user_design_cnt,
			user_design_total             => user_design_total,
			buffer_tag_vld                => buffer_tag_vld,
			buffer_tag_cnt                => buffer_tag_cnt
		);
end architecture RTL;
