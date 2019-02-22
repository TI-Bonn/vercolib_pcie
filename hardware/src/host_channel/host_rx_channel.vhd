library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.pcie.all;
use work.host_channel_types.all;

entity host_rx_channel is
	generic(
		config : transceiver_configuration;
		id     : positive
	);
	port(
		clk         : in  std_logic;
		rst         : in  std_logic;
		from_ep     : in  fragment;
		from_ep_vld : in  std_ulogic;
		from_ep_req : out std_ulogic := '1';
		to_ep       : out fragment := default_fragment;
		to_ep_vld   : out std_ulogic := '0';
		to_ep_req   : in  std_ulogic;
		o           : out rx_stream := default_rx_stream;
		o_vld       : out std_ulogic := '0';
		o_req       : in  std_ulogic
	);
end entity host_rx_channel;

architecture STRUCT of host_rx_channel is
	-- attribute mark_debug : string;
	
	signal rst_channel : std_logic;                           
	                                                          
	signal rq_instr_vld : std_logic;                          
	signal rq_instr : requester_instr_t;                      
                                                              
	signal int_instr_vld : std_logic;                         
	signal int_instr : interrupt_instr_t;                     
                                                              
	signal cpl : fragment;                                      
	signal cpl_vld : std_logic;                               
                                                              
	signal int_writer_vld : std_logic;                        
	signal int_writer_req : std_logic;                        
	signal int_writer : tlp_header_info_t;                    
	signal int_writer_payload : std_logic_vector(31 downto 0);
                                                              
	signal req_writer_vld : std_logic;                        
	signal req_writer_req : std_logic;                        
	signal req_writer : tlp_header_info_t;                    
                                                              
	signal tag : std_logic_vector(4 downto 0);       
	signal tag_vld : std_logic;                               
	signal tag_req : std_logic;                               
	signal pipe : fragment;                                     
	signal pipe_vld : std_logic;                              
	signal pipe_req : std_logic;                              
	
begin
	
--debug: entity work.host_rx_monitor_dbg
--	port map(
--		clk            => clk,
--		rst            => rst,
--		rq_instr_vld   => rq_instr_vld,
--		rq_instr       => rq_instr,
--		int_instr_vld  => int_instr_vld,
--		int_instr      => int_instr,
--		cpl            => cpl,
--		cpl_vld        => cpl_vld,
--		writer_vld     => pipe_vld,
--		writer_req     => pipe_req,
--		writer         => pipe
--	);
	
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
		cpl_vld       => cpl_vld,
		cpl           => cpl,
		rq_instr_vld  => rq_instr_vld,
		rq_instr      => rq_instr,
		int_instr_vld => int_instr_vld,
		int_instr     => int_instr
	);
	
requester: entity work.dma_requester
	generic map(
		MAX_REQUEST_SIZE => config.max_request_bytes,
		TAG_BITS         => 5,
		TRANSFER_DIR     => "DOWNSTREAM"
	)
	port map(
		rst        => rst_channel,
		clk        => clk,
		instr_vld  => rq_instr_vld,
		instr_req  => open,
		instr      => rq_instr,
		tag_vld    => tag_vld,
		tag_req    => tag_req,
		tag        => tag,
		writer_vld => req_writer_vld,
		writer_req => req_writer_req,
		writer     => req_writer
	);
	
interrupt_handler: entity work.rx_dma_interrupt_handler
	generic map(CHANNEL_ID => id)
	port map(
		clk            => clk,
		rst            => rst_channel,
		ctrl_rst       => open,
		instr_vld      => int_instr_vld,
		instr          => int_instr,
		cpl_vld        => cpl_vld,
		cpl            => cpl,
		writer_vld     => int_writer_vld,
		writer_req     => int_writer_req,
		writer         => int_writer,
		writer_payload => int_writer_payload
	);
	
writer: entity work.rx_dma_writer
	generic map(
		CHANNEL_ID   => id
	)
	port map(
		clk           => clk,
		rst           => rst_channel,
		int_vld       => int_writer_vld,
		int_req       => int_writer_req,
		int           => int_writer,
		int_payload   => int_writer_payload,
		transfer_vld  => req_writer_vld,
		transfer_req  => req_writer_req,
		transfer      => req_writer,
		o             => pipe, --ep,
		o_vld         => pipe_vld, --ep_vld,
		o_req         => pipe_req --ep_req
	);
	
out_req_pipe: entity work.pipe_register
	port map(
		clk   => clk,
		i     => pipe,
		i_vld => pipe_vld,
		i_req => pipe_req,
		o     => to_ep,
		o_vld => to_ep_vld,
		o_req => to_ep_req
	);	
	
dma_buffer: entity work.rx_dma_buffer
	generic map(
		tag_bits => 5,
		MRS      => config.max_request_bytes
	)
	port map(
		clk      => clk,
		rst      => rst_channel,
		i_vld    => cpl_vld,
		i_req    => open,
		i_data   => cpl,
		o_vld    => o_vld,
		o_req    => o_req,
		o_data   => o,
		tag_vld  => tag_vld,
		tag_req  => tag_req,
		tag_data => tag
	);

end architecture STRUCT;
