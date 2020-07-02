library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.host_types.all;
use work.transceiver_128bit_types.all;
use work.pcie.all;
use work.host_channel_types.all;

entity host_tx_channel is
	generic(
		debug  : boolean := false;
		config : transceiver_configuration;
		id     : positive
	);
	port(
		clk         : in  std_logic;
		rst         : in  std_logic;
		i_vld       : in  std_logic;
		i_req       : out std_logic;
		i           : in  tx_stream;
		from_ep_vld : in  std_logic;
		from_ep_req : out std_logic;
		from_ep     : in  fragment;
		to_ep_vld   : out std_logic;
		to_ep_req   : in  std_logic;
		to_ep       : out fragment
	);
end entity host_tx_channel;

architecture RTL of host_tx_channel is
	signal rst_channel : std_logic;
	signal rq_instr_vld : std_logic;
	signal rq_instr : requester_instr_t;
	signal int_instr : interrupt_instr_t;
	signal int_instr_vld : std_logic;
	signal req_writer_vld : std_logic := '0';
	signal req_writer_req : std_logic;
	signal req_writer : tlp_header_info_t;
	signal int_writer_vld : std_logic := '0';
	signal int_writer_req : std_logic;
	signal int_writer : tlp_header_info_t;
	signal int_writer_payload : dword;
	signal mwr_eot : std_logic;
	signal mwr : fragment;
	signal mwr_req : std_logic;
	signal mwr_vld : std_logic := '0';
	signal fifo_vld : std_logic;
	signal fifo_req : std_logic;
	signal fifo_data : tx_stream;
	signal fifo_eot : std_logic;
	signal fifo_data_cnt : unsigned(11 downto 0);

	signal shift : fragment;
	signal shift_vld : std_logic;
	signal shift_req : std_logic;

	signal tx_rst, ctrl_rst: std_logic := '0';
begin

	dbg: if debug generate
		mon: entity work.host_tx_monitor_dbg
		port map(
			clk            => clk,
			rst            => rst,
			rq_instr_vld   => rq_instr_vld,
			rq_instr       => rq_instr,
			int_instr_vld  => int_instr_vld,
			int_instr      => int_instr,
			writer_vld     => mwr_vld,
			writer_req     => mwr_req,
			writer         => mwr,
			fifo_vld       => fifo_vld,
			fifo_req       => fifo_req,
			fifo           => fifo_data,
			fifo_data_cnt  => fifo_data_cnt,
			user_vld       => i_vld,
			user_req       => i_req,
			user           => i
		);
	end generate;

tx_rst <= rst_channel or ctrl_rst;

decoder: entity work.dma_decoder
	generic map(
		CHANNEL_ID => id
	)
	port map(
		rst_in        => rst,
		rst_out       => rst_channel,
		clk           => clk,
		i_vld         => from_ep_vld,
		i_req         => from_ep_req,
		i             => from_ep,
		cpl_vld       => open,
		cpl           => open,
		rq_instr_vld  => rq_instr_vld,
		rq_instr      => rq_instr,
		int_instr_vld => int_instr_vld,
		int_instr     => int_instr
	);

requester: entity work.dma_requester
	generic map(
		debug            => debug,
		MAX_REQUEST_SIZE => config.max_payload_bytes,
		TAG_BITS         => 5,
		TRANSFER_DIR     => "UPSTREAM"
	)
	port map(
		rst        => tx_rst,
		clk        => clk,
		instr_vld  => rq_instr_vld,
		instr_req  => open,
		instr      => rq_instr,
		tag_vld    => '1',
		tag_req    => open,
		tag        => "00000",
		writer_vld => req_writer_vld,
		writer_req => req_writer_req,
		writer     => req_writer
	);

interrupt_handler: entity work.tx_dma_interrupt_handler
	generic map(
		debug      => debug,
		CHANNEL_ID => id
	)
	port map(
		clk            => clk,
		rst            => rst_channel,
		ctrl_rst       => ctrl_rst,
		instr_vld      => int_instr_vld,
		instr          => int_instr,
		mwr_vld        => mwr_vld,
		mwr_req        => mwr_req,
		mwr            => mwr,
		mwr_eot        => mwr_eot,
		writer_vld     => int_writer_vld,
		writer_req     => int_writer_req,
		writer         => int_writer,
		writer_payload => int_writer_payload
	);

writer: entity work.tx_dma_writer
	generic map(
		debug        => debug,
		CHANNEL_ID   => id
	)
	port map(
		clk           => clk,
		rst           => tx_rst,
		int_vld       => int_writer_vld,
		int_req       => int_writer_req,
		int           => int_writer,
		int_payload   => int_writer_payload,
		transfer_vld  => req_writer_vld,
		transfer_req  => req_writer_req,
		transfer      => req_writer,
		payload_vld   => fifo_vld,
		payload_req   => fifo_req,
		payload       => fifo_data,
		payload_cnt   => fifo_data_cnt,
		payload_eot   => fifo_eot,
		o             => mwr,
		o_eot         => mwr_eot,
		o_vld         => mwr_vld,
		o_req         => mwr_req
	);

fifo: entity work.tx_dma_fifo
	generic map(
		debug  => debug
	)
	port map(
		rst             => tx_rst,
		rst_dbg         => rst_channel,
		clk             => clk,
		i_vld           => i_vld,
		i_req           => i_req,
		i               => i,
		o_vld           => fifo_vld,
		o_req           => fifo_req,
		o               => fifo_data,
		end_of_transfer => fifo_eot,
		data_count      => fifo_data_cnt
	);

out_req_pipe: entity work.pipe_register
	port map(
		clk   => clk,
		i     => mwr,
		i_vld => mwr_vld,
		i_req => mwr_req,
		o     => shift,
		o_vld => shift_vld,
		o_req => shift_req
	);

mwr_shifter: entity work.tx_mwr32_shifter_128
	port map(
		clk   => clk,
		i     => shift,
		i_vld => shift_vld,
		i_req => shift_req,
		o     => to_ep,
		o_vld => to_ep_vld,
		o_req => to_ep_req
	);

end architecture RTL;
