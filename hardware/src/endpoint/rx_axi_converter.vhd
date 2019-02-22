---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;
use work.tlp_types.all;

entity rx_axi_converter is
	port(
		clk      : in std_logic;
		rst      : in std_logic;

		-- PCIe Endpoint AXIS input port
		axis_rx_user  : in  std_logic_vector(21 downto 0);
		axis_rx_data  : in  std_logic_vector(127 downto 0);
		axis_rx_valid : in  std_logic;
		axis_rx_ready : out std_logic := '1';

		-- Output Port
		o     : out tlp_packet := init_tlp_packet;
		o_vld : out std_logic  := '0';
		o_req : in  std_logic
	);
end rx_axi_converter;

architecture arch of rx_axi_converter is

function eof_to_keep(input: std_logic_vector(1 downto 0)) return std_logic_vector is
begin
	case input is
	when "00" => return "000";
	when "01" => return "001";
	when "10" => return "011";
	when "11" => return "111";
	when others => return "XXX";
	end case;
end eof_to_keep;

type state_t is (NON_STRADDLED, STRADDLED, EOF_IN_BUFFER);
signal state : state_t := NON_STRADDLED;

signal sof, eof : std_logic_vector(4 downto 0);
signal bar      : std_logic_vector(5 downto 0);

signal QW_buffer  : std_logic_vector(63 downto 0);
signal QW_buf_eof : std_logic;
signal QW_buf_bar : std_logic_vector(5 downto 0);
signal QW_buf_sof : std_logic;

begin

	bar <= axis_rx_user(7 downto 2);   -- indicates bar hit; bar(0) = BAR0
	sof <= axis_rx_user(14 downto 10);
	eof <= axis_rx_user(21 downto 17);

	axis_rx_ready <= '0' when state = EOF_IN_BUFFER else o_req;

	process(clk)
	begin
		if rising_edge(clk) then

			case state is

			when NON_STRADDLED =>

				if o_req = '1' then
					o_vld <= axis_rx_valid;

					o.eof <= eof(4);

					if eof(4) = '1' then
						o.keep <= eof_to_keep(eof(3 downto 2)) & '1';
					else
						o.keep <= x"F";
					end if;

					if axis_rx_valid = '1' and sof(3) = '1' then
						state <= STRADDLED;
					end if;
				end if;

			when STRADDLED =>

				if o_req = '1' then
					o_vld <= axis_rx_valid;

					o.eof <= eof(4) and not eof(3);

					if eof(4) = '1' and eof(3) = '0' then
						o.keep <= eof(2) & "111";
					else
						o.keep <= x"F";
					end if;

					if axis_rx_valid = '1'  then
						if eof(3) = '0' then
							if sof(4) = '0' and eof(4) = '1' then
								state <= NON_STRADDLED;
							end if;
						else
							-- eof(3) = '1' means DWORD2 or DWORD3 is eof
							-- -> eof will be in QW_buffer next clock cycle
							state <= EOF_IN_BUFFER;
						end if;
					end if;
				end if;

			when EOF_IN_BUFFER =>

				-- last DWORD of packet is in QW_buffer
				-- send content of buffer -> delay input for one clock cycle
				if o_req = '1' then
					o_vld <= '1';

					o.eof  <= '1';
					o.keep <= "00" & QW_buf_eof & '1';

					state <= NON_STRADDLED;
				end if;

			end case;

			if o_req = '1' then
				-- if data transfer is straddled then QWORD0 is in buffer,
				if state = STRADDLED or state = EOF_IN_BUFFER then
					o.data(127 downto 64) <= axis_rx_data(63 downto 0);
					o.data(63 downto 0)   <= QW_buffer;

					o.sof <= QW_buf_sof;
					o.bar <= QW_buf_bar;
				else
					o.data <= axis_rx_data(127 downto 0);
					o.sof  <= sof(4) and not sof(3);
					o.bar  <= bar;
				end if;

				if not (state = EOF_IN_BUFFER) then
					-- buffer QWORD1
					QW_buffer  <= axis_rx_data(127 downto 64);
					-- eof(2) = '1' means DWORD1 or DWORD3 is eof
					QW_buf_eof <= eof(2);
					QW_buf_bar <= bar;
					QW_buf_sof <= sof(4);
				end if;
			end if;
			
			if rst = '1' then
				state <= NON_STRADDLED;
				o <= init_tlp_packet;
				o_vld <= '0';
			end if;
		end if;
	end process;

end architecture;
