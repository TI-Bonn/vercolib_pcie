-- Author: Oguzhan Sezenlik

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.transceiver_128bit_types.all;
use work.pcie.all;
use work.host_channel_types.all;
use work.utils.all;

entity tx_dma_fifo is
	generic(
		debug : boolean := false
	);
	port(
		rst    : in std_logic;
		rst_dbg : in std_logic;
		clk    : in std_logic;

		i_vld  : in  std_logic;
		i_req  : out std_logic := '1';
		i      : in  tx_stream;

		o_vld  : out std_logic := '0';
		o_req  : in  std_logic;
		o      : out tx_stream;

		end_of_transfer : out std_logic;
		data_count      : out unsigned(11 downto 0)
	);
end tx_dma_fifo;

architecture arch of tx_dma_fifo is
	type   RAM_t  is array (0 to 511) of std_logic_vector(131 downto 0);
	signal memory : RAM_t := (others => (others => '0'));

	signal wr_ptr, rd_ptr : unsigned(8 downto 0) := (others => '0');

	type   state_t is (FULL, TRANSFER, EMPTY);
	signal state : state_t := EMPTY;

	type   rst_state_t is (WAIT_FOR_RST, WAIT_FOR_EOT);
	signal rst_state : rst_state_t := WAIT_FOR_EOT;

	signal written, read : unsigned(2 downto 0) := (others => '0');
	signal mem_out  : std_logic_vector(131 downto 0) := (others => '0');

	signal data_cnt : unsigned(11 downto 0) := (others => '0');
begin

i_req <= not i_vld when state = FULL or rst_state = WAIT_FOR_RST else '1';

o <= (
	 payload       => mem_out(127 downto 0),
	 cnt           => unsigned(mem_out(130 downto 128)),
	 end_of_stream => mem_out(131)
 );

written <= unsigned(i.cnt) when state /= FULL and rst_state /= WAIT_FOR_RST and i_vld = '1' else "000";
read    <= unsigned(o.cnt) when o_vld = '1' and o_req = '1' else "000";

data_count <= data_cnt;

main: process
begin
	wait until rising_edge(clk);

	data_cnt <= data_cnt + written - read;

	if o_req = '1' then
		o_vld <= '0';
	end if;

	if state /= FULL and i_vld = '1' and rst_state = WAIT_FOR_EOT then
		wr_ptr <= wr_ptr + 1;
		memory(to_integer(wr_ptr)) <=
			i.end_of_stream & std_logic_vector(i.cnt) & i.payload;
	end if;

	if state /= EMPTY and o_req = '1' then
		rd_ptr  <= rd_ptr + 1;
		mem_out <= memory(to_integer(rd_ptr));
		o_vld   <= '1';
	end if;

	if (rst = '1' and rst_state = WAIT_FOR_RST and data_count = 0) or rst_dbg = '1' then
		o_vld <= '0';
		wr_ptr <= (others => '0');
		rd_ptr <= (others => '0');
		data_cnt <= (others => '0');
	end if;

end process;

fsm: process
begin
	wait until rising_edge(clk);
	case state is
	when EMPTY =>
		if i_vld = '1' and rst_state = WAIT_FOR_EOT then
			state <= TRANSFER;
			if i.end_of_stream = '1' then
				rst_state <= WAIT_FOR_RST;
				end_of_transfer <= '1';
			end if;
		end if;
	when TRANSFER =>
		if wr_ptr - 1 = rd_ptr and i_vld = '0' and o_req = '1' then
			state <= EMPTY;
		end if;
		if wr_ptr + 1 = rd_ptr and i_vld = '1' and o_req = '0' and rst_state = WAIT_FOR_EOT then
			state <= FULL;
		end if;
		if i_vld = '1' and i.end_of_stream = '1' and rst_state = WAIT_FOR_EOT then
			rst_state <= WAIT_FOR_RST;
			end_of_transfer <= '1';
		end if;
	when FULL =>
		if o_req = '1' then
			state <= TRANSFER;
		end if;
	end case;

	if o_req = '1' and o_vld = '1' and o.end_of_stream = '1' then
		end_of_transfer <= '0';
	end if;

	if rst = '1' and rst_state = WAIT_FOR_RST and data_count = 0 then
		state <= EMPTY;
		rst_state <= WAIT_FOR_EOT;
	end if;

	if  rst_dbg = '1' then
		state <= EMPTY;
		rst_state <= WAIT_FOR_EOT;
	end if;

end process;

dbg: if debug generate
	signal dbg_fifo_state : std_ulogic_vector(1 downto 0);
	signal dbg_rst_state  : std_ulogic;
begin
	dbg_fifo_state <= "00" when state = EMPTY else
	                  "01" when state = TRANSFER else
	                  "10" when state = FULL else
					  "11";

	dbg_rst_state  <= '0' when rst_state = WAIT_FOR_RST else
	                  '1' when rst_state = WAIT_FOR_EOT else
	                  '0';

	dbg_mon: entity work.dbg_tx_dma_fifo
		port map(
			fifo_state      => dbg_fifo_state,
			rst_state       => dbg_rst_state,
			data_cnt        => data_cnt,
			end_of_transfer => end_of_transfer,
			i_req           => i_req,
			i_vld           => i_vld
		);
end generate;

end architecture;
