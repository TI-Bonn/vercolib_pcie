-- Pack Write Requests from user design data
-- Author: Sebastian Schueller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.host_types.all;

package sender_pack_data_types is
	type state_t is (
		INIT,
		CALC_INIT_LENGTH,
		CALC_REP_LENGTH,
		HANDLE_EOB,
		HEADER_32,
		HEADER_64,
		PAYLOAD,
		INTERRUPT
	);

	type data_info_t is record
		dw_to_send: u32;
		length: u16;
		write_addr: u64;
		state: state_t;
	end record;
	constant init_data_info: data_info_t := (
		dw_to_send => (others => '0'),
		length => (others => '0'),
		write_addr => (others => '0'),
		state => INIT
	);
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.host_types.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;

use work.sender_pack_data_types.all;
use work.sender_cfg_ctrl_types.all;
use work.pcie_fifo_packet.all;

entity sender_pack_data is
generic(
	id: natural := 1;
	max_payload_bytes: natural := 128);
port(
	clk: in std_logic;

	fifo: in fifo_packet;
	fifo_req: out std_logic := '0';
	status: in fifo_status;

	cfg: in fpga_tx_config_t;

	transferred: out u32 := (others => '0');

	o: out fragment;
	o_vld: out std_logic := '0';
	o_req: in std_logic);
end entity;


architecture arch of sender_pack_data is
	signal info: data_info_t := init_data_info;

	signal align_size: u16 := (others => '0');

	signal fifo_idx: unsigned(1 downto 0) := (others => '0');


	pure function umin(a,b: unsigned) return unsigned is
		variable ret: unsigned(maximum(a'high,b'high) downto 0);
	begin
		if a <= b then
			ret := resize(a, ret'length);
		else
			ret := resize(b, ret'length);
		end if;
		return ret;
	end function;


	constant max_payload_dw: u16 := to_unsigned(max_payload_bytes/4, 16);
begin

update_dw: process
	variable increasing, decreasing: u32 := (others => '0');
begin
	wait until rising_edge(clk);

	increasing := shift_right(cfg.size_bytes,2);
	decreasing := (others => '0');

	if o_req = '1' and (info.state = HEADER_32 or info.state = HEADER_64) then
		decreasing := resize(info.length,32);

		if cfg.target = TARGET_FPGA and info.length(1 downto 0) /= 0 then
			decreasing := resize(info.length + (4 - info.length(1 downto 0)), 32);
		end if;
	end if;

	info.dw_to_send <= info.dw_to_send + increasing - decreasing;

end process;

fsm: process
	variable tmp_length: u16 := (others => '0');
	variable enough_dw:  boolean := false;
	variable enough_for_full_packet: boolean := false;
begin
	wait until rising_edge(clk);


	case info.state is
	when INIT =>
		info.write_addr <= cfg.addr;

		align_size <= max_payload_dw - cfg.addr(17 downto 2) when cfg.target = TARGET_HOST else
		              max_payload_dw;

		if info.dw_to_send /= 0 then
			info.state <= CALC_INIT_LENGTH;
		end if;

	when CALC_INIT_LENGTH =>
		tmp_length := resize(umin(align_size, info.dw_to_send),16);
		enough_dw  := (status.dwords >= tmp_length) and (??fifo.data_vld);
		info.length <= tmp_length;

		info.state <= HANDLE_EOB when status.got_eob else
		              HEADER_32  when enough_dw and cfg.addr_mode = ADDR_32BIT  else
		              HEADER_64  when enough_dw and cfg.addr_mode = ADDR_64BIT  else
		              CALC_INIT_LENGTH;

	when CALC_REP_LENGTH =>
		tmp_length := resize(umin(max_payload_dw, info.dw_to_send),16);
		enough_dw  := status.dwords >= tmp_length;
		info.length <= tmp_length;

		info.state <= INTERRUPT  when info.dw_to_send = 0 else
		              HANDLE_EOB when status.got_eob else
		              HEADER_32  when enough_dw and cfg.addr_mode = ADDR_32BIT  else
		              HEADER_64  when enough_dw and cfg.addr_mode = ADDR_64BIT  else
		              CALC_INIT_LENGTH;

	when HANDLE_EOB =>
		tmp_length := umin(info.length, status.dwords);
		info.length <= tmp_length;

		info.state <= HEADER_32 when cfg.addr_mode = ADDR_32BIT  else
		              HEADER_64 when cfg.addr_mode = ADDR_64BIT  else
		              CALC_INIT_LENGTH;

	when HEADER_32 =>
		if o_req then
			tmp_length := info.length - 1;
			info.length <= tmp_length;

			info.state <= CALC_REP_LENGTH  when tmp_length = 0 else
			              PAYLOAD;
		end if;

	when HEADER_64 =>
		if o_req then
			info.state <= PAYLOAD;
		end if;

	when PAYLOAD =>
		if o_req then
			tmp_length := info.length - 4 when info.length >= 4 else to_unsigned(0,16);

			enough_for_full_packet := info.dw_to_send >= max_payload_dw and
			                          status.dwords   >= max_payload_dw;


			info.length <= max_payload_dw  when info.length <= 4 else tmp_length;

			info.state <= HEADER_32        when info.length <= 4 and enough_for_full_packet and cfg.addr_mode = ADDR_32BIT else
			              HEADER_64        when info.length <= 4 and enough_for_full_packet else
			              CALC_REP_LENGTH  when info.length <= 4 else
			              PAYLOAD;
		end if;

	when INTERRUPT =>
		if o_req then
			info.state <= INIT;
		end if;
	end case;

end process;

output: process
	variable data_dw:  dword  := (others => '0');
	variable data_qdw: qdword := (others => '0');
begin
	wait until rising_edge(clk);

	data_dw := fifo.data(to_integer(fifo_idx));
	data_qdw := as_vec(fifo.data)                                     when fifo_idx = "00" else
	            as_vec(fifo.prev(0)          & fifo.data(3 downto 1)) when fifo_idx = "01" else
	            as_vec(fifo.prev(1 downto 0) & fifo.data(3 downto 2)) when fifo_idx = "10" else
	            as_vec(fifo.prev(2 downto 0) & fifo.data(3))          when fifo_idx = "11" else
	            (127 downto 0 => '0');


	case info.state is
	when HEADER_32 =>
		if o_req then
			o_vld <= '1';
			set_rqst32_header(o, make_wr_rqst32(
				length  => to_integer(info.length),
				chn_id  => id,
				address => std_logic_vector(info.write_addr(31 downto 0))
			));
			set_dw(o, 3, data_dw);
			o.eof <= '1' when info.length = 1 else '0';

			fifo_idx <= fifo_idx + 1;
		end if;

	when HEADER_64 =>
		if o_req then
			o_vld <= '1';
			set_rqst64_header(o, make_wr_rqst64(
				length  => to_integer(info.length),
				chn_id  => id,
				addr_lo => std_logic_vector(info.write_addr(63 downto 32)),
				addr_hi => std_logic_vector(info.write_addr(31 downto  0))
			));
		end if;

	when PAYLOAD =>
		if o_req then
			o_vld  <= '1';
			o.data <= data_qdw;
			o.keep <= "1111" when info.length >= 4 else
			          "0111" when info.length  = 3  else
			          "0011" when info.length  = 2  else
			          "0001" when info.length  = 1  else
			          "XXXX";
			o.sof <= '0';
			o.eof <= '1' when info.length <= 4 else '0';

			fifo_idx <= fifo_idx + 4 when info.length >= 4 else
			            fifo_idx + info.length(1 downto 0);

		end if;
	when INTERRUPT =>
		if o_req = '1' and cfg.target = TARGET_HOST then
			o_vld <= '1';
			o.sof <= '1';
			o.eof <= '1';
			set_dw(o, 0, std_logic_vector(resize(unsigned(MSIX_desc), 32)));
			set_dw(o, 1, (31 downto 0 => '0'));
			set_dw(o, 2, (31 downto 0 => '0'));
			set_dw(o, 3, std_logic_vector(to_unsigned(id,32)));
		end if;

	when others =>
		if o_req then
			o_vld <= '0';
			reset(o);
		end if;

	end case;
end process;

request_data: process(fifo_idx, info.length, info.state, fifo.data_vld, o_req)
	variable good_dw: unsigned(2 downto 0) := (others => '0');
	variable header32_eats, payload_eats: boolean := false;
begin
	good_dw := resize(4 - fifo_idx, 3);
	header32_eats := good_dw = 1;
	payload_eats  := info.length > 4 or (info.length <= 4 and info.length >= good_dw);

	fifo_req <= '1' when not fifo.data_vld else
	            '1' when o_req = '1' and info.state = PAYLOAD   and payload_eats  else
	            '1' when o_req = '1' and info.state = HEADER_32 and header32_eats else
	            '0';
end process;

emit_transferred: process
begin
	wait until rising_edge(clk);

	case info.state is
	when HEADER_32 =>
		transferred <= transferred + 1;
	when PAYLOAD =>
		transferred <= transferred + 4 when info.length >= 4 else
		               transferred + shift_left(info.length(1 downto 0),2);
	when others => null;
	end case;
end process;




end architecture arch;















