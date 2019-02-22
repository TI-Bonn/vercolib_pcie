library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;
use work.host_channel_types.all;

entity dma_decoder is
	generic(
		CHANNEL_ID : natural := 1
	);
	port(
		-- control signals
		rst_in  : in  std_logic;
		rst_out : out std_logic;  -- pipelined syncronous reset signal
		clk     : in std_logic;
		
		-- input port
		i_vld : in  std_logic := '0';
		i_req : out std_logic;
		i     : in  fragment;
		
		-- output ports for memory completions
		cpl_vld : out std_logic;
		cpl     : out fragment;
		
		-- output for decoded instructions
		-- to requester
		rq_instr_vld  : out std_logic := '0';
		rq_instr      : out requester_instr_t;
		
		-- to interrupt_handler
		int_instr_vld : out std_logic := '0';
		int_instr     : out interrupt_instr_t
	);
end entity dma_decoder;

architecture RTL of dma_decoder is
	signal rq_payload : std_logic_vector(31 downto 0);
	signal rq_addr    : unsigned(3 downto 0);
	signal rq_tag     : unsigned(7 downto 0);
	signal rq_type    : request_t;
	signal rq_vld     : std_logic;
begin
	
filter: entity work.dma_decoder_filter
	generic map(
		CHANNEL_ID => CHANNEL_ID
	)
	port map(
		rst_in     => rst_in,
		rst_out    => rst_out,
		clk        => clk,
		i_vld      => i_vld,
		i_req      => i_req,
		i          => i,
		cpl_vld    => cpl_vld,
		cpl        => cpl,
		rq_vld     => rq_vld,
		rq_type    => rq_type,
		rq_tag     => rq_tag,
		rq_payload => rq_payload,
		rq_addr    => rq_addr
	);

instructor: entity work.dma_decoder_instructor
	generic map(
		CHANNEL_ID => CHANNEL_ID
	)
	port map(
		rst           => rst_in,
		clk           => clk,
		rq_vld        => rq_vld,
		rq_type       => rq_type,
		rq_tag        => rq_tag,
		rq_payload    => rq_payload,
		rq_addr       => rq_addr,
		rq_instr_vld  => rq_instr_vld,
		rq_instr      => rq_instr,
		int_instr_vld => int_instr_vld,
		int_instr     => int_instr 
	);

end architecture RTL;
