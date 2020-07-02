-- Author: Oguzhan Sezenlik

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dbg_types.all;

entity host_tx_counter_dbg is
	port(
		clk : in std_logic;
		rst : in std_logic;

		host_kbuffer_vld              : in  boolean         := false;
		host_kbuffer_size             : in  natural         := 0;
		host_kbuffer_cnt              : out counter_width_t := (others => '0');
		host_kbuffer_total            : out counter_width_t := (others => '0');
		host_get_transferred_vld      : in  boolean         := false;
		host_get_transferred_cnt      : out counter_width_t := (others => '0');
		channel_mwr_vld               : in  boolean         := false;
		channel_mwr_size              : in  counter_width_t := (others => '0');
		channel_mwr_cnt               : out counter_width_t := (others => '0');
		channel_mwr_total             : out counter_width_t := (others => '0');
		channel_interrupt_vld         : in  boolean         := false;
		channel_interrupt_cnt         : out counter_width_t := (others => '0');
		channel_get_transferred_vld   : in  boolean         := false;
		channel_get_transferred_size  : in  natural         := 0;
		channel_get_transferred_cnt   : out counter_width_t := (others => '0');
		channel_get_transferred_total : out counter_width_t := (others => '0');
		fifo_vld                      : in  boolean         := false;
		fifo_size                     : in  counter_width_t := (others => '0');
		fifo_cnt                      : out counter_width_t := (others => '0');
		fifo_total                    : out counter_width_t := (others => '0');
		fifo_eos_vld                  : in  boolean         := false;
		fifo_eos_cnt                  : out counter_width_t := (others => '0');
		user_design_vld               : in  boolean         := false;
		user_design_size              : in  counter_width_t := (others => '0');
		user_design_cnt               : out counter_width_t := (others => '0');
		user_design_total             : out counter_width_t := (others => '0');
		user_design_eos_vld           : in  boolean         := false;
		user_design_eos_cnt           : out counter_width_t := (others => '0')
	);
end entity host_tx_counter_dbg;

architecture RTL of host_tx_counter_dbg is
	signal nat_mwr_size, nat_fifo_size, nat_user_design_size: natural;
begin
	nat_mwr_size         <= to_integer(channel_mwr_size);
	nat_fifo_size        <= to_integer(fifo_size);
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
			channel_mwr_cnt,
			channel_mwr_vld
		);
		increment_cnt(rst,
			channel_mwr_total,
			channel_mwr_vld,
			nat_mwr_size
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
			fifo_cnt,
			fifo_vld
		);
		increment_cnt(rst,
			fifo_total,
			fifo_vld,
			nat_fifo_size
		);
		increment_cnt(rst,
			fifo_eos_cnt,
			fifo_eos_vld
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
			user_design_eos_cnt,
			user_design_eos_vld
		);
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
		rq_instr     : in requester_instr_t;

		int_instr_vld : in std_logic;
		int_instr     : in interrupt_instr_t;

		writer_vld : in std_logic;
		writer_req : in std_logic;
		writer     : in pcie.fragment;

		fifo_vld      : in std_logic;
		fifo_req      : in std_logic;
		fifo          : in pcie.tx_stream;
		fifo_data_cnt : in unsigned(11 downto 0);

		user_vld : in std_logic;
		user_req : in std_logic;
		user     : in pcie.tx_stream
	);
end entity host_tx_monitor_dbg;

architecture RTL of host_tx_monitor_dbg is
	attribute mark_debug : string;
	attribute dont_touch : string;

	signal host_kbuffer_vld              : boolean         := false;
	signal host_kbuffer_size             : natural         := 0;
	signal host_kbuffer_cnt              : counter_width_t := (others => '0');
	signal host_kbuffer_total            : counter_width_t := (others => '0');
	signal host_get_transferred_vld      : boolean         := false;
	signal host_get_transferred_cnt      : counter_width_t := (others => '0');
	signal channel_mwr_vld               : boolean         := false;
	signal channel_mwr_size              : counter_width_t := (others => '0');
	signal channel_mwr_cnt               : counter_width_t := (others => '0');
	signal channel_mwr_total             : counter_width_t := (others => '0');
	signal channel_interrupt_vld         : boolean         := false;
	signal channel_interrupt_cnt         : counter_width_t := (others => '0');
	signal channel_get_transferred_vld   : boolean         := false;
	signal channel_get_transferred_size  : natural         := 0;
	signal channel_get_transferred_cnt   : counter_width_t := (others => '0');
	signal channel_get_transferred_total : counter_width_t := (others => '0');
	signal fifo_cnt_vld                  : boolean         := false;
	signal fifo_size                     : counter_width_t := (others => '0');
	signal fifo_cnt                      : counter_width_t := (others => '0');
	signal fifo_total                    : counter_width_t := (others => '0');
	signal fifo_eos_vld                  : boolean         := false;
	signal fifo_eos_cnt                  : counter_width_t := (others => '0');
	signal user_design_vld               : boolean         := false;
	signal user_design_size              : counter_width_t := (others => '0');
	signal user_design_cnt               : counter_width_t := (others => '0');
	signal user_design_total             : counter_width_t := (others => '0');
	signal user_design_eos_vld           : boolean         := false;
	signal user_design_eos_cnt           : counter_width_t := (others => '0');

	signal lost_word_in_fifo             : boolean         := false;
	signal expected_fifo_data            : std_ulogic_vector(63 downto 0) := (others => '0');

	attribute dont_touch of host_kbuffer_vld              : signal is "true";
	attribute dont_touch of host_kbuffer_size             : signal is "true";
	attribute dont_touch of host_kbuffer_cnt              : signal is "true";
	attribute dont_touch of host_kbuffer_total            : signal is "true";
	attribute dont_touch of host_get_transferred_vld      : signal is "true";
	attribute dont_touch of host_get_transferred_cnt      : signal is "true";
	attribute dont_touch of channel_mwr_vld               : signal is "true";
	attribute dont_touch of channel_mwr_size              : signal is "true";
	attribute dont_touch of channel_mwr_cnt               : signal is "true";
	attribute dont_touch of channel_mwr_total             : signal is "true";
	attribute dont_touch of channel_interrupt_vld         : signal is "true";
	attribute dont_touch of channel_interrupt_cnt         : signal is "true";
	attribute dont_touch of channel_get_transferred_vld   : signal is "true";
	attribute dont_touch of channel_get_transferred_size  : signal is "true";
	attribute dont_touch of channel_get_transferred_cnt   : signal is "true";
	attribute dont_touch of channel_get_transferred_total : signal is "true";
	attribute dont_touch of fifo_vld                      : signal is "true";
	attribute dont_touch of fifo_size                     : signal is "true";
	attribute dont_touch of fifo_cnt                      : signal is "true";
	attribute dont_touch of fifo_eos_vld                  : signal is "true";
	attribute dont_touch of fifo_eos_cnt                  : signal is "true";
	attribute dont_touch of fifo_data_cnt                 : signal is "true";
	attribute dont_touch of user_design_vld               : signal is "true";
	attribute dont_touch of user_design_size              : signal is "true";
	attribute dont_touch of user_design_cnt               : signal is "true";
	attribute dont_touch of user_design_eos_vld           : signal is "true";
	attribute dont_touch of user_design_eos_cnt           : signal is "true";
	attribute dont_touch of lost_word_in_fifo             : signal is "true";
	attribute dont_touch of expected_fifo_data            : signal is "true";

	attribute mark_debug of host_kbuffer_vld              : signal is "true";
	attribute mark_debug of host_kbuffer_size             : signal is "true";
	attribute mark_debug of host_kbuffer_cnt              : signal is "true";
	attribute mark_debug of host_kbuffer_total            : signal is "true";
	attribute mark_debug of host_get_transferred_vld      : signal is "true";
	attribute mark_debug of host_get_transferred_cnt      : signal is "true";
	attribute mark_debug of channel_mwr_vld               : signal is "true";
	attribute mark_debug of channel_mwr_size              : signal is "true";
	attribute mark_debug of channel_mwr_cnt               : signal is "true";
	attribute mark_debug of channel_mwr_total             : signal is "true";
	attribute mark_debug of channel_interrupt_vld         : signal is "true";
	attribute mark_debug of channel_interrupt_cnt         : signal is "true";
	attribute mark_debug of channel_get_transferred_vld   : signal is "true";
	attribute mark_debug of channel_get_transferred_size  : signal is "true";
	attribute mark_debug of channel_get_transferred_cnt   : signal is "true";
	attribute mark_debug of channel_get_transferred_total : signal is "true";
	attribute mark_debug of fifo_vld                      : signal is "true";
	attribute mark_debug of fifo_size                     : signal is "true";
	attribute mark_debug of fifo_cnt                      : signal is "true";
	attribute mark_debug of fifo_total                    : signal is "true";
	attribute mark_debug of fifo_eos_vld                  : signal is "true";
	attribute mark_debug of fifo_eos_cnt                  : signal is "true";
	attribute mark_debug of fifo_data_cnt                 : signal is "true";
	attribute mark_debug of user_design_vld               : signal is "true";
	attribute mark_debug of user_design_size              : signal is "true";
	attribute mark_debug of user_design_cnt               : signal is "true";
	attribute mark_debug of user_design_total             : signal is "true";
	attribute mark_debug of user_design_eos_vld           : signal is "true";
	attribute mark_debug of user_design_eos_cnt           : signal is "true";
	attribute mark_debug of lost_word_in_fifo             : signal is "true";
	attribute mark_debug of expected_fifo_data            : signal is "true";

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

		channel_mwr_vld             <= true when
											writer_vld = '1' and
											writer_req = '1' and
											(get_type(writer) = MWr32_desc or
											 get_type(writer) = MWr64_desc)
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

		fifo_cnt_vld                <= true when fifo_vld and fifo_req
										else false;

		fifo_eos_vld                <= true when
		 									fifo_vld and fifo_req and
											fifo.end_of_stream
										else false;

		user_design_vld             <= true when user_vld and user_req
										else false;

		user_design_eos_vld         <= true when
		 									user_vld and user_req and
											user.end_of_stream
										else false;

		host_kbuffer_size <= to_integer(rq_instr.dma_size);
		channel_mwr_size  <= resize(unsigned(to_common_dw0(get_dword(writer, 0)).length), channel_mwr_size'length);

		channel_get_transferred_size <= to_integer(unsigned(writer.data(127 downto 96)));

		user_design_size  <= resize(user.cnt, user_design_size'length);
		fifo_size  <= resize(fifo.cnt, fifo_size'length);

		if (fifo_vld and fifo_req) = '1' then
			expected_fifo_data <= std_ulogic_vector(
				unsigned(expected_fifo_data) + to_unsigned(1, expected_fifo_data'length)
		    );
			if fifo.payload(expected_fifo_data'high downto 0) /= expected_fifo_data then
				lost_word_in_fifo <= true;
			end if;
		end if;
		if rst = '1' then
			expected_fifo_data <= (others => '0');
		end if;

	end process;

	cnt: entity work.host_tx_counter_dbg
		port map(
			clk => clk,
			rst => rst,
			host_kbuffer_vld              => host_kbuffer_vld,
			host_kbuffer_size             => host_kbuffer_size,
			host_kbuffer_cnt              => host_kbuffer_cnt,
			host_kbuffer_total            => host_kbuffer_total,
			host_get_transferred_vld      => host_get_transferred_vld,
			host_get_transferred_cnt      => host_get_transferred_cnt,
			channel_mwr_vld               => channel_mwr_vld,
			channel_mwr_size              => channel_mwr_size,
			channel_mwr_cnt               => channel_mwr_cnt,
			channel_mwr_total             => channel_mwr_total,
			channel_interrupt_vld         => channel_interrupt_vld,
			channel_interrupt_cnt         => channel_interrupt_cnt,
			channel_get_transferred_vld   => channel_get_transferred_vld,
			channel_get_transferred_size  => channel_get_transferred_size,
			channel_get_transferred_cnt   => channel_get_transferred_cnt,
			channel_get_transferred_total => channel_get_transferred_total,
			fifo_vld                      => fifo_cnt_vld,
			fifo_size                     => fifo_size,
			fifo_cnt                      => fifo_cnt,
			fifo_total                    => fifo_total,
			fifo_eos_vld                  => fifo_eos_vld,
			fifo_eos_cnt                  => fifo_eos_cnt,
			user_design_vld               => user_design_vld,
			user_design_size              => user_design_size,
			user_design_cnt               => user_design_cnt,
			user_design_total             => user_design_total,
			user_design_eos_vld           => user_design_eos_vld,
			user_design_eos_cnt           => user_design_eos_cnt
		);
end architecture RTL;
