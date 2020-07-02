library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.pcie.all;
use work.host_channel_types.all;
use work.utils.all;

entity writer_buffer is
	generic(
		debug : boolean := false
	);
	port (
		clk : in std_logic;
		rst : in std_logic;

		i_vld  : in  std_logic;
		i_req  : out std_logic;
		i      : in  tx_stream;

		fifo_eot   : in  std_logic;
		fifo_count : in  unsigned(11 downto 0);

		o_vld   : out std_logic := '0';
		o_req   : in  unsigned(2 downto 0);
		o       : out tx_stream;

		eot     : out std_logic := '0';
		count   : out unsigned(11 downto 0) := (others => '0')
	);
end entity writer_buffer;

architecture RTL of writer_buffer is

signal buf      : std_logic_vector(127 downto 32) := (others => '0');
signal buf_cnt  : unsigned(1 downto 0) := (others => '0');
signal buf_eot  : std_logic := '0';

signal enough_in_buf : std_logic;

signal buf_ptr : unsigned(1 downto 0) := (others => '0');

begin

enough_in_buf <= '1' when o_req <= buf_cnt else '0';

o.end_of_stream <= buf_eot when enough_in_buf = '1'  else i.end_of_stream;
o_vld <= '1'     when (buf_cnt /= 0 and enough_in_buf = '1') else i_vld;

-- pull data from fifo when packer requests more than stored in buffer
i_req <= '1' when not enough_in_buf or not i_vld else '0';

main: process
	variable buf_cnt_temp : unsigned(2 downto 0) := (others => '0');
begin
	wait until rising_edge(clk);

	-- data_count is clocked for optimization and could be one lock cycle behind current fifo state ->
	-- underestimates count -> packer starts later -> adds latency -> unproblematic!
	-- eot also has to be delayed by one clock cycle
	count  <= fifo_count + buf_cnt - o_req;
	eot    <= buf_eot or fifo_eot;

	-- if more dwords are requested than stored in buffer -> some input dwords might be left out ->
	-- store those in buffer and remember if it was a eot
	if not enough_in_buf then
		buf      <= i.payload(127 downto 32);
		buf_eot  <= i.end_of_stream and i_vld;

		-- reset eot if all available data is requested
		if o_req = i.cnt + ('0' & buf_cnt) and i_vld = '1' then
			buf_eot <= '0';
		end if;
	end if;

	if o_req > 0 then
		-- update buf_cnt: dwords_in_buffer_new = input_dwords + dwords_in_buffer_current - requested_dwords MOD 4;
		buf_cnt_temp := i.cnt + ('0' & buf_cnt) - o_req;
		buf_cnt <= buf_cnt_temp(1 downto 0);

		-- update buf_ptr: works kind of an circular buffer, with input_cnt as reset
		buf_ptr <= buf_ptr + o_req(1 downto 0) - i.cnt(1 downto 0);
	end if;

	if rst = '1' then
		buf_cnt <= "00";
		buf_eot <= '0';
		buf_ptr <= "00";

		count <= (others => '0');
		eot <= '0';
	end if;

end process;

with buf_ptr select o.payload <=
	i.payload(31 downto 0) & buf                when "01",
	i.payload(63 downto 0) & buf(127 downto 64) when "10",
	i.payload(95 downto 0) & buf(127 downto 96) when "11",
	i.payload                                   when others;

dbg: if debug generate
begin
	dbg_mon: entity work.dbg_tx_dma_writer_buffer
		port map(
			clk           => clk,
			rst           => rst,
			input         => i,
			input_vld     => i_vld,
			input_req     => i_req,
			output_vld    => o_vld,
			output_req    => o_req,
			buf_cnt       => buf_cnt,
			buf_eot       => buf_eot,
			enough_in_buf => enough_in_buf,
			buf_ptr       => buf_ptr,
			count         => count,
			eot           => eot
		);
end generate;

end architecture RTL;
