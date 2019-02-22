---------------------------------------------------------------------------------------------------
-- Author:		Oguzhan Sezenlik
---------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;

entity rx_CplD_preprocessor is
	port(
		clk    : in std_logic;
		rst    : in std_logic;

		-- Input Port
		i     : in  fragment;
		i_vld : in  std_logic;
		i_req : out std_logic := '1';

		-- Output Port
		o     : out fragment := default_fragment;
		o_vld : out std_logic := '0';
		o_req : in  std_logic         -- we assume that next module will never stop dataflow
	);
end rx_CplD_preprocessor;


architecture arch of rx_CplD_preprocessor is

	signal byte_count : std_logic_vector(11 downto 0);
	signal header_desc : descriptor_t;

	type state_t is (HEADER, CPLD, EOF_IN_BUFFER);
	signal state : state_t := HEADER;
	signal buf_reg : std_logic_vector(127 downto 0);
	signal buf_vld : std_logic := '0';
	signal byte_count_32 : std_logic_vector(1 downto 0);
	signal buf_keep : std_logic_vector(3 downto 0);

begin

	byte_count  <= get_cpld(i.data).dw1.byte_count;
	header_desc <= i.data(3 downto 0);

	i_req <= '0' when state = EOF_IN_BUFFER else o_req;

	process(clk)
	begin
		if rising_edge(clk) then

			-- buffer data in case of CPLD
			buf_reg  <= i.data;
			buf_vld  <= i_vld;

			if i.sof = '1' then
				buf_keep <= "1000";
			else
				buf_keep <= i.keep;
			end if;

			o <= i;
			o_vld <= i_vld;

			case state is

			when HEADER =>
				if i_vld = '1' and i.sof = '1'  and header_desc = CplD_desc then
						-- CplD header: only DW0, DW1 are necessary and is never eof
						if i.eof = '1' then
							state <= EOF_IN_BUFFER;
						else
							state <= CPLD;
						end if;

						o.keep <= "0011";
						o.eof  <= '0';
				end if;

				-- buffer relevant byte_count bits
				byte_count_32 <= byte_count(3 downto 2);

			when CPLD => -- rearrange CplD DWORDs until eof is received

				-- eof will be in buffer next clock cycle
				if i.eof = '1' then
					if  (byte_count_32 = "00" and  i.keep(3) = '1') or
						(byte_count_32 = "01" and (i.keep(3) or i.keep(2)) = '1') or
						(byte_count_32 = "10" and (i.keep(3) or i.keep(2) or i.keep(1)) = '1') or
						 byte_count_32 = "11" then

						state <= EOF_IN_BUFFER;
					else
						state <= HEADER;
						o.eof <= i.eof;
					end if;
				end if;

				o.sof <= '0';

			when EOF_IN_BUFFER =>

				o_vld  <= buf_vld;

				o.eof <= '1';
				state <= HEADER;
				o.sof <= '0';

			end case;

			if state = CPLD or state = EOF_IN_BUFFER then

				case byte_count_32 is
				when "00" => o.data <= i.data(95 downto 0) & buf_reg (127 downto 96);

							 if state = EOF_IN_BUFFER then
							    o.keep <= "000" & buf_keep(3 downto 3);
							 else
							    o.keep <= i.keep(2 downto 0) & buf_keep(3 downto 3);
							 end if;

				when "11" => o.data <= i.data(63 downto 0) & buf_reg (127 downto 64);

							 if state = EOF_IN_BUFFER then
							    o.keep <= "00" & buf_keep(3 downto 2);
							 else
							    o.keep <= i.keep(1 downto 0) & buf_keep(3 downto 2);
							 end if;

				when "10" => o.data <= i.data(31 downto 0) & buf_reg (127 downto 32);

							 if state = EOF_IN_BUFFER then
							    o.keep <= "0" & buf_keep(3 downto 1);
							 else
							    o.keep <= i.keep(0 downto 0) & buf_keep(3 downto 1);
							 end if;

				when "01" => o.data <= buf_reg;
							 o.keep <= buf_keep;

				when others => null;
				end case;

			end if;

			if rst = '1' then
				state <= HEADER;
				o <= default_fragment;
				o_vld <= '0';
				buf_vld <= '0';
			end if;

		end if;
	end process;

end architecture;
