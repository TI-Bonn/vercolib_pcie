library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.transceiver_128bit_types.all;
use work.host_channel_types.all;
use work.utils.all;

entity dma_requester is
	generic(
		MAX_REQUEST_SIZE : positive := 512;
		TAG_BITS         : positive := 8;
		TRANSFER_DIR     : string := "DOWNSTREAM"
	);
	port(
		rst     : in  std_logic;
		clk     : in  std_logic;

		-- input for instructions from rq_decoder or sg_buffer
		instr_vld : in  std_logic := '0';
		instr_req : out std_logic;
		instr     : in  requester_instr_t;

		-- input port "tag" from rx_dma_buffer
		tag_vld : in  std_logic;
		tag_req : out std_logic := '0';
		tag     : in  std_logic_vector(TAG_BITS-1 downto 0);

		-- output port "writer" to writer
		writer_vld : out std_logic := '0';
		writer_req : in  std_logic;
		writer     : out tlp_header_info_t
	);
end dma_requester;

architecture arch of dma_requester is

constant MRS_DWORDS       : positive := MAX_REQUEST_SIZE/4;
constant MRS_DWORDS_WIDTH : positive := repr(MRS_DWORDS);

type req_state_t is (REQUEST, HOLD);
signal tag_req_state   : req_state_t := HOLD;
signal instr_req_state : req_state_t := REQUEST;

type state_t is (GET_BUFFER_AND_CALC_FIRST_MRQ,
				 CHECK_IF_MRQ_IS_LAST_AND_SEND,
				 CALC_NEXT_MRQ);
signal state : state_t;

signal MRd_addr64 : unsigned(63 downto 0);
signal MRd_size : unsigned(MRS_DWORDS_WIDTH-1 downto 0);
signal transfer_size : unsigned(29 downto 0);

begin

assert (TRANSFER_DIR = "DOWNSTREAM" or TRANSFER_DIR = "UPSTREAM") report "invalid TRANSFER_DIR generic";

writer.mrq_address <= std_logic_vector(MRd_addr64);
writer.length(9 downto MRS_DWORDS_WIDTH)   <= (others => '0');
writer.length(MRS_DWORDS_WIDTH-1 downto 0) <= MRd_size;

tag_req   <= '1' when tag_req_state   = REQUEST or tag_vld   = '0' else '0';
instr_req <= '1' when instr_req_state = REQUEST or instr_vld = '0' else '0';

main: process
	
begin
	wait until rising_edge(clk);

	case state is
	when GET_BUFFER_AND_CALC_FIRST_MRQ =>
		
		tag_req_state   <= HOLD;
		instr_req_state <= HOLD;

		if writer_req = '1' then
			instr_req_state <= REQUEST;
			
			-- only TRANSFER instructions are relevant for this FSM
			case instr.instr is
			when TRANSFER_DMA32 =>
				writer.desc <= MRd32_desc when TRANSFER_DIR = "DOWNSTREAM" else 
			                   MWr32_desc when TRANSFER_DIR = "UPSTREAM";
			when TRANSFER_DMA64 =>
				writer.desc <= MRd64_desc when TRANSFER_DIR = "DOWNSTREAM" else 
			                   MWr64_desc when TRANSFER_DIR = "UPSTREAM";
			when others =>
			end case;

			-- generate first MRd:
			-- save address
			MRd_addr64    <= instr.dma_addr;
			-- align first MRd to the size of MRS -> no need to check for memory page boundaries of 4KB
			MRd_size      <= to_unsigned(MRS_DWORDS, MRS_DWORDS_WIDTH) - ('0' & instr.dma_addr(MRS_DWORDS_WIDTH downto 2));
			-- save size of dma buffer in DWORDS
			transfer_size <= instr.dma_size(31 downto 2); 

			writer_vld <= '0';
			
			-- do something only if instruction is TRANSFER
			if instr_vld = '1' and (instr.instr = TRANSFER_DMA32 or instr.instr = TRANSFER_DMA64) then
				state           <= CHECK_IF_MRQ_IS_LAST_AND_SEND;
			end if;
		end if;
		
	when CHECK_IF_MRQ_IS_LAST_AND_SEND =>

		if writer_req = '1' and tag_vld = '1' then
			state         <= CALC_NEXT_MRQ;
			tag_req_state <= REQUEST;
			-- send MRd
			writer_vld <= '1';
			writer.tag(7 downto TAG_BITS) <= (others => '0');
			writer.tag(TAG_BITS-1 downto 0) <= unsigned(tag);

			-- check if prepared MRd is the last one
			-- if so, update length and get next dma buffer
			if transfer_size <= to_integer(MRd_size) then
				state    <= GET_BUFFER_AND_CALC_FIRST_MRQ;
				MRd_size <= transfer_size(MRS_DWORDS_WIDTH-1 downto 0);
			end if;
		end if;

	when CALC_NEXT_MRQ =>
		tag_req_state <= HOLD;

		if writer_req = '1' then
			state         <= CHECK_IF_MRQ_IS_LAST_AND_SEND;

			writer_vld    <= '0';

			-- calculate address and length of next MRd
			transfer_size <= transfer_size - to_integer(MRd_size);
			MRd_addr64    <= MRd_addr64 + to_integer(MRd_size(MRS_DWORDS_WIDTH-1 downto 0) & "00");  -- addresses are in bytes
			MRd_size      <= to_unsigned(MRS_DWORDS, MRS_DWORDS_WIDTH);
		end if;

	end case;

	if rst = '1' then
		writer_vld      <= '0';

		instr_req_state <= HOLD;
		tag_req_state   <= HOLD;
		state           <= GET_BUFFER_AND_CALC_FIRST_MRQ;
	end if;
end process;

end architecture;

