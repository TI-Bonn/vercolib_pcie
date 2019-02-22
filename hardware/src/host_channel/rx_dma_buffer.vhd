
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.pcie.all;
use work.host_channel_types.all;
use work.utils.all;

entity rx_dma_buffer is
	generic(
		tag_bits          : natural  := 5;  -- PCIe-Tag bit range,
		MRS               : positive := 512 -- Maximal Request Size
	);
	port(
		rst      : in  std_logic;
		
		clk      : in  std_logic;

		i_vld    : in  std_logic;
		i_req    : out std_logic;
		i_data   : in  fragment;

		o_vld    : out std_logic := '0';
		o_req    : in  std_logic;
		--o_data   : out std_logic_vector(129 downto 0) := (others => '0');
		o_data   : out rx_stream := default_rx_stream;

		tag_vld  : out std_logic := '0';
		tag_req  : in  std_logic;
		tag_data : out std_logic_vector(tag_bits-1 downto 0) := (others => '0')
	);
end rx_dma_buffer;

architecture behavioral of rx_dma_buffer is
	


-- Definitions:
--AXI-Word: 128 bit word coming from the PCIe-Endpoint
--DWORD:    32 bit word. PCIe-Bus protocol is organized in DWORDs
--MemLine:  Memory Line. One MemLine is equivalent to a AXI-Word
--
-- Data input is a packet with a 2 DWORD header (see transceiver_types package)
-- and a payload with maximal MPS bytes (see PCIe base specification),
-- organized as 4 DWORDs in a 128 bit AXI-Word.
--
-- Memory is organized as 4 equal memory blocks, each corresponds to one DWORD in a AXI-Word.
-- See diagram below for a more detailed specification:
--
--                               DWORDs
--     AXI-Word        |  3  |  2  |  1  |  0  |
--
--                      +---+ +---+ +---+ +---+
--     MemLinesPerTag-1 |   | |   | |   | |   | MemLines-1
--                      +---+ +---+ +---+ +---+
--                      :   : :   : :   : :   :
--                      :   : :   : :   : :   :
--                      +---+ +---+ +---+ +---+
--                    0 |   | |   | |   | |   |
--                      +---+ +---+ +---+ +---+
--                      :   : :   : :   : :   :
--                      :   : :   : :   : :   :
--                      +---+ +---+ +---+ +---+
--     MemLinesPerTag-1 |   | |   | |   | |   |
--                      +---+ +---+ +---+ +---+
--                      :   : :   : :   : :   :
--                      :   : :   : :   : :   :
--                      +---+ +---+ +---+ +---+
--                    0 |   | |   | |   | |   | 0
--                      +---+ +---+ +---+ +---+
--     Mem                1     2     3     0 (= 4)
--
-- memory address format:                       | tag [tag_bits] | [repr(MemLinesPerTag)_bits] |
-- Example: tag_bits = 2, MemLinesPerTag = 32   | 2 bits         | 5 bits                      |

---------------------------------------------------------
-- Helper functions, signals and constant declerations --
---------------------------------------------------------
	-- constant are defined in DWORDs, see diagram above
	constant MemLinesPerTag : positive := MRS/(4*4); -- PCIe-Max_Request_Size [Bytes] / (4 [DWORDs] * 4 [AXI-Words])
	constant MemLines       : positive := MemLinesPerTag*(2**tag_bits);
	constant byteCountBits  : positive := repr(MRS); -- necessary byte_count bits, depends on maximal request size

	-- signal declerations
	signal tlp_tag        : unsigned(tag_bits-1 downto 0) := (others => '0');
	signal tlp_length     : unsigned(9 downto 0) := (others => '0');
	--signal tlp_lower_addr : unsigned(6 downto 0) := (others => '0');
	signal tlp_byte_count : unsigned(11 downto 0) := (others => '0');

------------------------
-- signals for memory --
------------------------
	type   RAM_t is array (0 to MemLines-1) of unsigned(31 downto 0);
	signal Mem0, Mem1, Mem2, Mem3: RAM_t := (others => (others => '0'));

	-- write side
	signal dword0,  dword1,  dword2,  dword3  : unsigned(31 downto 0) := (others => '0');
	signal wr_ptr0, wr_ptr1, wr_ptr2, wr_ptr3 : unsigned(tag_bits+byteCountBits-5-1 downto 0)  := (others => '0');
	signal wr_en0,  wr_en1,  wr_en2,  wr_en3  : std_logic := '0';

	-- read side
	signal rd_ptr : unsigned(tag_bits+byteCountBits-5-1 downto 0) := (others => '0');

	-- signals for data output
	signal Mem0_out, Mem1_out, Mem2_out, Mem3_out : unsigned(31 downto 0) := (others => '0');

----------
-- FSMs --
----------
	-- signals and flags for write side
	type   wr_state_t  is (HEADER_S, WRITE_S);
	signal wr_state    : wr_state_t := HEADER_S;

	signal wr_tag      : unsigned(tag_bits-1 downto 0) := (others => '0');
	signal last_cpld   : std_logic := '0';

	signal tag_in_process : std_logic_vector(0 to 2**tag_bits-1) := (others => '0');

	-- signals and flags for read side
	type   rd_state_t  is (INIT_S, READ_S, FIRST_S);
	signal rd_state      : rd_state_t := INIT_S;
	signal rd_tag        : unsigned(tag_bits-1 downto 0) := (others => '0');

	signal dword_count   : unsigned(1 downto 0) := (others => '0');
	signal dw_cnt_out    : unsigned(1 downto 0);

	-- signals and flags for tag-generate side
	signal tag_ptr       : unsigned(tag_bits-1 downto 0) := (others => '0');

	-- signals for data exchange between write FSM and read FSM
	type   rd_init_t     is array (0 to 2**tag_bits-1) of unsigned(byteCountBits-3-1 downto 0); -- range byteCountBits - 2 (DW granularity -> 2 bits LSB not required)
	signal rd_init_mem   : rd_init_t := (others => (others => '0'));                            -- byte_count memory to notify read FSM how to initialize read address pointer
	signal rd_init_in    : unsigned(byteCountBits-3-1 downto 0) := (others => '0');             -- rd_init_mem output register

	signal tag_readable    : std_logic_vector(0 to 2**tag_bits-1) := (others => '0'); -- memory to notify read FSM which transfers are finished
	signal rd_tag_is_ready : std_logic := '0';                                        -- flag used to check if current read tag is ready to read
	signal rqst_complete   : std_logic := '0';                                        -- flag to notify read FSM that a transfer finished

	-- signals for data exchange between read FSM and tag-generate FSM side
	signal tag_available : std_logic_vector(0 to 2**tag_bits-1) := (others => '1'); -- memory to notify tag-generate side which tags are available
	signal release_tag   : std_logic := '0';                                        -- flag to notify tag-generate side that a tag is released and can be used to request data
	signal rd_tag_ptr    : unsigned(tag_bits-1 downto 0);                           -- read to tag-generate pointer for tag_available

	attribute ram_style : string;
	attribute ram_style of Mem0 : signal is "block";
	attribute ram_style of Mem1 : signal is "block";
	attribute ram_style of Mem2 : signal is "block";
	attribute ram_style of Mem3 : signal is "block";
begin

	-- DMA-downstream-Channel only requests data from main memory if DMA-buffer is not full,
	-- hence data is always requested from endpoint
	i_req <= '1';

	-- assign input to internal signals for better code readability
	tlp_tag        <= unsigned(get_cpld(i_data.data).dw0.tag(tag_bits-1 downto 0));
	tlp_byte_count <= unsigned(get_cpld(i_data.data).dw1.byte_count);      
	--tlp_lower_addr <= unsigned(to_cpld_header(i_data.data).dw1.lower_address); -- we need this line to support byte granularity
	tlp_length     <= unsigned(i_data.data(15 downto 6));

	dword0 <= unsigned(i_data.data(31 downto 0));
	dword1 <= unsigned(i_data.data(63 downto 32));
	dword2 <= unsigned(i_data.data(95 downto 64));
	dword3 <= unsigned(i_data.data(127 downto 96));

	-- write valid payloads of CPLD into memory, i.e. sof = '0', active sof means header
	wr_en0 <= i_vld and not i_data.sof and i_data.keep(0);
	wr_en1 <= i_vld and not i_data.sof and i_data.keep(1);
	wr_en2 <= i_vld and not i_data.sof and i_data.keep(2);
	wr_en3 <= i_vld and not i_data.sof and i_data.keep(3);


	write_proc: process(clk)
		variable wr_ptr0_temp, wr_ptr1_temp, wr_ptr2_temp, wr_ptr3_temp : unsigned(byteCountBits-3 downto 0) := (others => '0');
	begin
		if rising_edge(clk) then

			-- save data into memory, decrement write address pointer
			if wr_en0 = '1' then
				Mem0(to_integer(wr_ptr0)) <= dword0;
				wr_ptr0                   <= wr_ptr0 - 1;
			end if;

			if wr_en1 = '1' then
				Mem1(to_integer(wr_ptr1)) <= dword1;
				wr_ptr1                   <= wr_ptr1 - 1;
			end if;

			if wr_en2 = '1' then
				Mem2(to_integer(wr_ptr2)) <= dword2;
				wr_ptr2                   <= wr_ptr2 - 1;
			end if;

			if wr_en3 = '1' then
				Mem3(to_integer(wr_ptr3)) <= dword3;
				wr_ptr3                   <= wr_ptr3 - 1;
			end if;

			-- defaults
			rqst_complete <= '0';

			-- write FSM
			case wr_state is
			-- save useful completion header information into registers for later use
			when HEADER_S =>

				-- TLP tag is used as higher bits in write address pointer.
				-- Selects the correct memory range in respect of TLP tags.
				wr_tag <= tlp_tag(tag_bits-1 downto 0);

				-- initial position of write address pointer of Mem0 to Mem3 depends on byte_count,
				-- subtracted by a constant.
				wr_ptr0_temp := tlp_byte_count(byteCountBits-1 downto 2) - 4;
				wr_ptr1_temp := tlp_byte_count(byteCountBits-1 downto 2) - 3;
				wr_ptr2_temp := tlp_byte_count(byteCountBits-1 downto 2) - 2;
				wr_ptr3_temp := tlp_byte_count(byteCountBits-1 downto 2) - 1;

				-- initialize address counter: 	address format is 	|tag|(byte_count + 3)(11 downto 4)|
				wr_ptr0 <= tlp_tag & wr_ptr0_temp(byteCountBits-3-1 downto 2);
				wr_ptr1 <= tlp_tag & wr_ptr1_temp(byteCountBits-3-1 downto 2);
				wr_ptr2 <= tlp_tag & wr_ptr2_temp(byteCountBits-3-1 downto 2);
				wr_ptr3 <= tlp_tag & wr_ptr3_temp(byteCountBits-3-1 downto 2);

				-- determine if this CplD is the last one,
				-- check: length == byte_count/4
				if tlp_length(byteCountBits-3 downto 0) = tlp_byte_count(byteCountBits-1 downto 2) then
					last_cpld <= '1';
				else
					last_cpld <= '0';
				end if;

				-- store byte_count to initialize read address pointer
				rd_init_in <= wr_ptr3_temp(byteCountBits-3-1 downto 0); -- tlp_byte_count(byteCountBits-1-1 downto 2) - 1;

				if i_vld = '1' then
					wr_state   <= WRITE_S;
				end if;

			when WRITE_S =>

				-- when the last 128 bytes of a CplD packet is received:
				if i_data.eof = '1' then

					-- go to initial state 'HEADER'
					wr_state  <= HEADER_S;

					-- notify read-FSM and reset last_cpld flag
					last_cpld     <= '0';
					rqst_complete <= last_cpld;

					tag_in_process(to_integer(wr_tag)) <= not last_cpld;
				end if;

				-- check if this cpld is the first with this tag,
				-- necessary to write correct byte_count into rd_init_mem to notify read side
				if tag_in_process(to_integer(wr_tag)) = '0' then
					rd_init_mem(to_integer(wr_tag)) <= rd_init_in;
				end if;

			end case;
			
			if rst = '1' then
				wr_ptr0 <= (others => '0');
				wr_ptr1 <= (others => '0');
				wr_ptr2 <= (others => '0');
				wr_ptr3 <= (others => '0');
				
				wr_state  <= HEADER_S;
				
				last_cpld     <= '0';
				rqst_complete <= '0';
				
				tag_in_process <= (others => '0');
				rd_init_mem    <= (others => (others => '0'));
			end if;
		end if;
	end process;

	wr_to_rd_proc: process(clk)
	begin
		if rising_edge(clk) then
			-- notify read-FSM if request is finished
			if rqst_complete = '1' then
				tag_readable(to_integer(wr_tag)) <= '1';
			end if;
			-- data of read request with rd_tag is being read -> reset flag
			if release_tag = '1' then
				tag_readable(to_integer(rd_tag_ptr)) <= '0';
			end if;
			
			if rst = '1' then
				tag_readable <= (others => '0');
			end if;
		end if;
	end process;

	read_proc: process(clk)
	begin
		if rising_edge(clk) then

			-- check if current rd_tag is completely received by write-FSM
			rd_tag_is_ready <= tag_readable(to_integer(rd_tag));

			-- read-FSM
			case rd_state is

			when INIT_S =>

				if o_req = '1' then
					o_vld <= '0';
				end if;

				release_tag <= '0';

				rd_tag_ptr  <= rd_tag;
				rd_ptr      <= rd_tag & rd_init_mem(to_integer(rd_tag))(byteCountBits-3-1 downto 2);

				-- output status bits = byte_count(3 downto 2)
				dword_count <= rd_init_mem(to_integer(rd_tag))(1 downto 0);

				if rd_tag_is_ready = '1' then
					-- initialize read address pointer with current tag & byte_count(byteCountBits-1 downto 4) provided by write-FSM
					rd_tag   <= rd_tag + 1;
					rd_state <= FIRST_S;

					-- reset flag
					rd_tag_is_ready <= '0';
				end if;

			when FIRST_S =>

				if o_req = '1' then
					dw_cnt_out <= dword_count;

					-- if start address is 0, only one word to output -> goto initial state and release current tag
					if rd_ptr(byteCountBits-5-1 downto 0) = 0 then
						rd_state    <= INIT_S;
						release_tag <= '1';
					else
						rd_state <= READ_S;
					end if;
				end if;

			when READ_S =>

				if o_req = '1' then

					-- dword count is always 4, unless it's the first word i a transfer (tag)
					dw_cnt_out <= "11";

					-- output last word and go to initial state
					if rd_ptr(byteCountBits-5-1 downto 0) = 0 then
						rd_state    <= INIT_S;
						release_tag <= '1';
					end if;
				end if;

			end case;

			-- store word in output register
			if o_req = '1' and (rd_state = READ_S or rd_state = FIRST_S) then
				o_vld <= '1';

				Mem0_out <= Mem0(to_integer(rd_ptr));
				Mem1_out <= Mem1(to_integer(rd_ptr));
				Mem2_out <= Mem2(to_integer(rd_ptr));
				Mem3_out <= Mem3(to_integer(rd_ptr));

				rd_ptr   <= rd_ptr - 1;
			end if;
			
			if rst = '1' then
				rd_state        <= INIT_S;
				release_tag     <= '0';
				rd_tag_is_ready <= '0';
				
				o_vld  <= '0';
				rd_ptr <= (others => '0');
			end if;

		end if;
	end process;

	o_data.cnt     <= (resize(dw_cnt_out, 3) + 1);
	o_data.payload <= std_ulogic_vector(
		unsigned'(Mem3_out & Mem2_out & Mem1_out & Mem0_out)
	);

	rd_to_tag_proc: process(clk)
	begin
		if rising_edge(clk) then
			-- notify tag-FSM if request is finished
			if release_tag = '1' then
				tag_available(to_integer(rd_tag_ptr)) <= '1';
			end if;
			-- data of read request with rd_tag is being read -> reset flag
			if tag_req = '1' and tag_available(to_integer(tag_ptr)) = '1'  then
				tag_available(to_integer(tag_ptr)) <= '0';
			end if;
			
			if rst = '1' then
				tag_available <= (others => '1');
			end if;
		end if;
	end process;

	tag_proc: process(clk)
	begin
		if rising_edge(clk) then
			if tag_req = '1' then
				tag_vld <= '0';

				-- if tag is available request data from request generator
				if tag_available(to_integer(tag_ptr)) = '1' then
					tag_vld  <= '1';
					tag_data <= std_logic_vector(tag_ptr);

					tag_ptr  <= tag_ptr + 1;
				end if;
			end if;

			if rst = '1' then
				tag_vld  <= '0';
				tag_data <= (others => '0');
				tag_ptr  <= (others => '0');
			end if;
		end if;
	end process;

end behavioral;



--architecture behavioral of DS_DMA_Buffer is
--
--signal tag_cnt : unsigned(tag_bits-1 downto 0) := (others => '0');
--signal data_cnt : unsigned(31 downto 0) := (others => '0');
--
--begin
--
--process(clk)
--begin
--
--    if rising_edge(clk) then
--
--        if tag_req = '1' then
--            tag_vld  <= '1';
--            tag_cnt  <= tag_cnt + 1;
--            tag_data <= std_logic_vector(tag_cnt);
--        end if;
--
--        i_req <= '1';
--
--        o_vld <= '0';
--        if i_vld = '1' then
--            data_cnt <= data_cnt + 1;
--
--            o_vld <= '1';
--            o_data(31 downto 0) <= std_logic_vector(data_cnt);
--        end if;
--
--        if o_req = '1' and unsigned(i_data.data) = 2**126 then
--        	o_data(127 downto 0) <= i_data.data;
--       	end if;
--
--    end if;
--
--end process;
--
--
--end architecture;
