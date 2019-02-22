---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
-- Company:		University Bonn

-- Date:		03/17/2016
-- Description:
-- Version: 	0.1
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils.all;
use work.tlp_types.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;

entity MSIX_table is
	generic(
		interrupts  : positive range 1 to 2048 := 4
	);
	port(
		clk      : in  std_logic;
		rst      : in  std_logic;

		cfg      : in  fragment;
		cfg_vld  : in  std_logic;
		cfg_req  : out std_logic;

		i        : in  fragment;
		i_vld    : in  std_logic;
		i_req    : out std_logic := '1';

		o        : out fragment := default_fragment;
		o_vld    : out std_logic := '0';
		o_req    : in  std_logic
	);
end MSIX_table;

architecture arch of MSIX_table is

constant mem_addr_bits    : natural := repr(interrupts);
constant mem_addr_bits_DW : natural := mem_addr_bits+2;
--constant MPS_cnt_bits  : natural := repr(MWr_MPS);
--constant MPS_DW	       : integer := MWr_MPS/4;

type state_t    is (IDLE, MEM_WRITE, SEND_MSIX_HEADER, MSIX_PENDING, MEM_READ);
signal state    : state_t := IDLE;

-- msi-x message vector table and pba
-- table format:	address            DW2|           DW1|           DW0
--					----------------------------------------------------
--						  0   message data| upper address| lower address
--						  :        :      |       :      |       :
--					    n-1	  message data| upper address| lower address

type msi_x_mem_t is array (0 to interrupts-1) of std_logic_vector(31 downto 0);
signal msix_DW0,  msix_DW1,  msix_DW2  : msi_x_mem_t := (others => (others => '0'));
signal shift_DW0, shift_DW1, shift_DW2, shift_DW3 : std_logic_vector(31 downto 0);
signal wr_en0,    wr_en1,    wr_en2,    wr_en3    : std_Logic := '0';

signal msix_DW3  : msi_x_mem_t := (others => x"00000001");

-- pending bit array table
--type pba_mem_t is array (0 to (interrupts/32)-1) of std_logic_vector(31 downto 0);
--signal pba_DW	 : pba_mem_t := (others => (others => '0'));

-- memory write and read address pointer
signal wr_ptr0, wr_ptr1, wr_ptr2, wr_ptr3: unsigned(mem_addr_bits-1 downto 0);
signal rd_ptr0, rd_ptr1, rd_ptr2, rd_ptr3: unsigned(mem_addr_bits-1 downto 0);

signal DW0,    DW1,    DW2,   DW3 : std_logic_vector(31 downto 0);

signal offset_lsb : std_logic_vector(1 downto 0);
signal DW_vld  : std_logic_vector(3 downto 0);
signal is_MWr, eof : std_Logic;

signal data128_vld : std_logic;
signal data128 : std_logic_vector(127 downto 0);
signal is_MRr : std_logic;

begin

cfg_req <= '1';

DW0 <= data128(31 downto 0);
DW1 <= data128(63 downto 32);
DW2 <= data128(95 downto 64);
DW3 <= data128(127 downto 96);

barrel_mux: process(offset_lsb, DW0, DW1, DW2, DW3, DW_vld(0), DW_vld(1), DW_vld(2), DW_vld(3))
begin
	case offset_lsb(1 downto 0) is

	when "00" =>
		shift_DW0 <= DW3;     -- DW0 is in DW3
		shift_DW1 <= DW0;     -- DW1 is in DW0
		shift_DW2 <= DW1;     -- DW2 is in DW1
		shift_DW3 <= DW2;  -- DW3 is in DW2

		wr_en0 <= DW_vld(3);
		wr_en1 <= DW_vld(0);
		wr_en2 <= DW_vld(1);
		wr_en3 <= DW_vld(2);

	when "01" =>
		shift_DW0 <= DW2;     -- DW0 is in DW2
		shift_DW1 <= DW3;     -- DW1 is in DW3
		shift_DW2 <= DW0;     -- DW2 is in DW0
		shift_DW3 <= DW1;  -- DW3 is in DW1

		wr_en0 <= DW_vld(2);
		wr_en1 <= DW_vld(3);
		wr_en2 <= DW_vld(0);
		wr_en3 <= DW_vld(1);

	when "10" =>
		shift_DW0 <= DW1;     -- DW0 is in DW1
		shift_DW1 <= DW2;     -- DW1 is in DW2
		shift_DW2 <= DW3;     -- DW2 is in DW3
		shift_DW3 <= DW0;  -- DW3 is in DW0

		wr_en0 <= DW_vld(1);
		wr_en1 <= DW_vld(2);
		wr_en2 <= DW_vld(3);
		wr_en3 <= DW_vld(0);

	when "11" =>
		shift_DW0 <= DW0;     -- DW0 is in DW0
		shift_DW1 <= DW1;     -- DW1 is in DW1
		shift_DW2 <= DW2;     -- DW2 is in DW2
		shift_DW3 <= DW3;  -- DW3 is in DW3

		wr_en0 <= DW_vld(0);
		wr_en1 <= DW_vld(1);
		wr_en2 <= DW_vld(2);
		wr_en3 <= DW_vld(3);

	when others =>
		null;

	end case;
end process;

is_MWr <= '1' when cfg.data(3 downto 0) = MWr32_desc else '0';
is_MRr <= '1' when cfg.data(3 downto 0) = MRd32_desc else '0';

process(clk)
	variable o_rqst : rqst32 := init_rqst32;
	variable o_cpld : cpld := init_cpld;
	variable tmp: unsigned(mem_addr_bits_DW-1 downto 0);
begin
	if rising_edge(clk) then

		---------------------
		-- 1st pipeline stage
		---------------------
		-- store MWr or MRd in pipeline register
		data128     <= cfg.data;
		data128_vld <= cfg_vld;
		eof         <= cfg.eof;

		-- check if DWORDs in pipeline register are valid msi_x data
		DW_vld(0) <= cfg.keep(0) and cfg_vld and not cfg.sof and is_MWr;
		DW_vld(1) <= cfg.keep(1) and cfg_vld and not cfg.sof and is_MWr;
		DW_vld(2) <= cfg.keep(2) and cfg_vld and not cfg.sof and is_MWr;
		DW_vld(3) <= cfg.keep(3) and cfg_vld and is_MWr;

		-- initialize write address pointer when a new header is received, might be a MWr see FSM below
		if cfg_vld = '1' and cfg.sof = '1' then
			offset_lsb <= get_rqst32(cfg.data(95 downto 0)).dw2.address(3 downto 2);

			tmp     := unsigned(get_rqst32(cfg.data(95 downto 0)).dw2.address(mem_addr_bits_DW+1 downto 2)) + 3;
			wr_ptr0 <= tmp(mem_addr_bits_DW-1 downto 2);
			rd_ptr0 <= tmp(mem_addr_bits_DW-1 downto 2);
			tmp     := unsigned(get_rqst32(cfg.data(95 downto 0)).dw2.address(mem_addr_bits_DW+1 downto 2)) + 2;
			wr_ptr1 <= tmp(mem_addr_bits_DW-1 downto 2);
			rd_ptr1 <= tmp(mem_addr_bits_DW-1 downto 2);
			tmp     := unsigned(get_rqst32(cfg.data(95 downto 0)).dw2.address(mem_addr_bits_DW+1 downto 2)) + 1;
			wr_ptr2 <= tmp(mem_addr_bits_DW-1 downto 2);
			rd_ptr2 <= tmp(mem_addr_bits_DW-1 downto 2);
			tmp     := unsigned(get_rqst32(cfg.data(95 downto 0)).dw2.address(mem_addr_bits_DW+1 downto 2));
			wr_ptr3 <= tmp(mem_addr_bits_DW-1 downto 2);
			rd_ptr3 <= tmp(mem_addr_bits_DW-1 downto 2);
		end if;

		---------
		-- FSM --
		---------
		case state is

		when IDLE =>

			if o_req = '1' then
				o_vld <= '0';
			end if;

			if cfg_vld = '0' then
				-- initialize read address pointer with lower bits of i.
				rd_ptr0   <= unsigned(i.data(96+mem_addr_bits-1 downto 96));
				rd_ptr1   <= unsigned(i.data(96+mem_addr_bits-1 downto 96));
				rd_ptr2   <= unsigned(i.data(96+mem_addr_bits-1 downto 96));
				rd_ptr3   <= unsigned(i.data(96+mem_addr_bits-1 downto 96));
			end if;

			if cfg_vld = '1' then
				if is_MWr = '1' then
					state <= MEM_WRITE;
				elsif is_MRr = '1' then
					state <= MEM_READ;
				end if;
			elsif i_vld = '1' and i.data(3 downto 0) = MSIX_desc then
				state <= SEND_MSIX_HEADER;
			end if;


		when MEM_READ =>

			if o_req = '1' then
				o_cpld.dw0.desc              := CplD_desc;
				o_cpld.dw0.tag               := get_rqst32(data128(95 downto 0)).dw0.tag;
				o_cpld.dw0.length            := std_logic_vector(to_unsigned(1, 10));
				o_cpld.dw1.byte_count        := std_logic_vector(to_unsigned(4, 12));
				o_cpld.dw1.completer_id      := x"FFFF";
				o_cpld.dw2.lower_addr        := get_rqst32(data128(95 downto 0)).dw2.address(6 downto 0);

				set_cpld_header(o.data(95 downto 0), o_cpld);

				case get_rqst32(data128(95 downto 0)).dw2.address(3 downto 2) is
				when "00" =>
					o.data(127 downto 96) <= (msix_DW0(to_integer(rd_ptr0)));
				when "01" =>
					o.data(127 downto 96) <= (msix_DW1(to_integer(rd_ptr1)));
				when "10" =>
					o.data(127 downto 96) <= (msix_DW2(to_integer(rd_ptr2)));
				when "11" =>
					o.data(127 downto 96) <= (msix_DW3(to_integer(rd_ptr3)));
				when others => null;
				end case;

				o.keep <= x"F";
				o.sof  <= '1';
				o.eof  <= '1';

				o_vld <= '1';

				state <= IDLE;
			end if;

		when MEM_WRITE =>

			if (data128_vld = '1' and eof = '1') and not (cfg_vld = '1' and is_MWr = '1') then
				state <= IDLE;
			end if;

			---------------------
			-- 2nd pipeline stage
			---------------------
			-- store data into MSI-X table memory
			if wr_en0 = '1' then
				msix_DW0(to_integer(wr_ptr0)) <= shift_DW0;
				wr_ptr0 <= wr_ptr0 + 1;
			end if;
			if wr_en1 = '1' then
				msix_DW1(to_integer(wr_ptr1)) <= shift_DW1;
				wr_ptr1 <= wr_ptr1 + 1;
			end if;
			if wr_en2 = '1' then
				msix_DW2(to_integer(wr_ptr2)) <= shift_DW2;
				wr_ptr2 <= wr_ptr2 + 1;
			end if;
			if wr_en3 = '1' then
				msix_DW3(to_integer(wr_ptr3)) <= shift_DW3;
				wr_ptr3 <= wr_ptr3 + 1;
			end if;

		when MSIX_PENDING =>
				state <= SEND_MSIX_HEADER;

		when SEND_MSIX_HEADER =>

			if o_req = '1' then

				o_rqst.dw0.desc              := MWr32_desc;
				o_rqst.dw0.length            := std_logic_vector(to_unsigned(1, 10));
				o_rqst.dw0.tag               := x"00";

				o_rqst.dw1.first_be          := x"F";
				o_rqst.dw1.last_be           := x"0";
				o_rqst.dw1.requester_id      := x"FFFF";

				o_rqst.dw2.address           := msix_DW0(to_integer(rd_ptr0));

				set_rqst32_header(o.data(95 downto 0), o_rqst);

				o.data(127 downto 96) <= msix_DW2(to_integer(rd_ptr2));

				o.keep <= x"F";
				o.sof  <= '1';
				o.eof  <= '1';

				o_vld <= '1';

				state <= IDLE;
			end if;

		end case;
		
		if rst = '1' then
			o <= default_fragment;
			o_vld <= '0';
		end if;
		
		
	end if;
end process;


i_req <= '0' when state = SEND_MSIX_HEADER else '1';

end architecture;
