library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.transceiver_128bit_types.all;
use work.host_types.all;
use work.pcie.all;
use work.host_channel_types.all;
use work.utils.all;

entity dma_writer_packer is
	generic(
		CHANNEL_ID   : natural;
		TRANSFER_DIR : string := "UPSTREAM"
	);
	port (
		clk : in std_logic;
		rst : in std_logic;

		-- input port for DMA transfers (MRd in DOWNSTREAM, MWr in UPSTREAM)
		i_vld     : in  std_logic;
		i_req     : out std_logic;
		i         : in  tlp_header_info_t;
		i_payload : in  dword;
		
		mwr_vld   : in  std_logic;
		mwr_req   : out std_logic;
		mwr       : in  tlp_header_info_t;
		
		-- input from payload fifo
		payload_vld : in  std_logic;
		payload_req : out unsigned(2 downto 0);
		payload     : in  tx_stream;
		payload_cnt : in  unsigned(11 downto 0);
		payload_eot : in  std_logic := '0';
		
		-- output
		o     : out fragment := default_fragment;
		o_eot : out std_logic := '0';
		o_vld : out std_logic := '0';
		o_req : in  std_logic
	);
end entity dma_writer_packer;

architecture RTL of dma_writer_packer is
	
type state_t is (HEADER, MWR_PAYLOAD, LAST_PAYLOAD);
signal state : state_t;

type req_state_t is (HOLD, REQUEST);
signal mwr_req_state, i_req_state : req_state_t := REQUEST;

signal payload_counter     : unsigned(9 downto 0) := (others => '0');
signal payload_req_cnt : unsigned(2 downto 0) := (others => '0');

begin
assert (TRANSFER_DIR = "DOWNSTREAM" or TRANSFER_DIR = "UPSTREAM") report "invalid TRANSFER_DIR generic";

payload_req <= payload_req_cnt when o_req = '1' else "000";

mwr_req <= '1' when mwr_req_state = REQUEST or mwr_vld = '0' else '0';
i_req   <= o_req when   i_req_state = REQUEST or   i_vld = '0' else '0';

generate_packet: process
	variable MWr_length : unsigned(9 downto 0) := (others => '0');
	variable cnt_temp   : unsigned(3 downto 0) := (others => '0');
begin
	wait until rising_edge(clk);

	case state is
		
		when HEADER =>

		o_eot <= '0';

		if o_req = '1' then
			o_vld <= i_vld;
			o     <= make_packet(i, CHANNEL_ID, i_payload);
		end if;

		-- default in case MWr
		mwr_req_state   <= HOLD;
		payload_req_cnt <= "000";

		-- this path is only active if packer is used for FPGA to host transfers
		-- MWr has less priority than MRd, Interrupt or CplD
		if i_vld = '0' and mwr_vld = '1' and o_req = '1' and TRANSFER_DIR = "UPSTREAM" then
			
			-- defaults
			o     <= make_packet(mwr, CHANNEL_ID, i_payload);
			o_vld <= '0';
				
			-- in case of an active EndOfTransfer flag, update length with min(mwr.length, fifo_data_cnt)
			MWr_length := mwr.length;
			if payload_eot = '1' and mwr.length > to_integer(payload_cnt) then
				MWr_length := payload_cnt(9 downto 0);
			end if;

			-- initialize payload counter with MWr_length
			payload_counter <= MWr_length;

			-- overwrite length of MWr with calculated length
			set_length(o, std_logic_vector(MWr_length));
			
			-- start to send MWr if enough data is available in fifo or EndOfTransfer flag is set
			-- assumption: data count coming from previous module is always consistent with input data ->
			-- as soon as condition is met, there is enough data available at input
			if (mwr.length <= to_integer(payload_cnt)) or (payload_eot = '1' and to_integer(payload_cnt) > 0)  then
				-- set states: hold header information from input i (MRd, CplDs, Ints)
				-- a MWr is being built -> request new MWr header information for next MWr
				i_req_state   <= HOLD;
				mwr_req_state <= REQUEST;
				
				o_vld         <= mwr_vld;
				
				-- if MWr length <= 4 -> only one payload packet needs to be generated
				if MWr_length <= 4 then
					-- MWr_length payload data is used -> request new payload accordingly
					state           <= LAST_PAYLOAD;
					payload_req_cnt <= MWr_length(2 downto 0);
				else
					-- couple of full payloads needs to be sent, request 4 dwords until last payload packet
					state           <= MWR_PAYLOAD;
					payload_req_cnt <= "100";
				end if;
				
				o_eot <= payload_eot;
			end if;
		end if;

	when MWR_PAYLOAD =>
		-- header of current MWr is sent, new information already requested ->
		-- hold new MWr header information 
		mwr_req_state <= HOLD;
		
		-- send payload with fully loaded qdwords
		if o_req = '1' then
			o_eot <= '0';
			
			o.data <= payload.payload;
			o.sof  <= '0';
			o.eof  <= '0';
			o.keep <= "1111";

			payload_counter <= payload_counter - 4;
			-- next payload will be the last one
			if payload_counter <= 8 then
				state           <= LAST_PAYLOAD;
				cnt_temp := payload_counter(3 downto 0) - 4;
				payload_req_cnt <= cnt_temp(2 downto 0);
			end if;
		end if;

	when LAST_PAYLOAD =>
		-- header of current MWr is sent, new information already requested ->
		-- hold new MWr header information 
		mwr_req_state <= HOLD;
		
		if o_req = '1' then
			o_eot <= '0';
			
			o.data <= payload.payload;
			o.sof  <= '0';
			o.eof  <= '1';
			o.keep <= cnt2keep(unsigned(payload_counter(2 downto 0)));
			
			state           <= HEADER;
			payload_req_cnt <= "000";
			
			i_req_state <= REQUEST;
		end if;
	end case;
	
	if rst = '1' then
		o_vld <= '0';
		state <= HEADER;
		i_req_state <= REQUEST;
		mwr_req_state <= HOLD;
	end if;
end process;

end architecture RTL;
