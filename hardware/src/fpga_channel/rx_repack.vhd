-- Remove PCIe headers and stuff data for FIFO
-- Author: Sebastian Schüller <schuell1@cs.uni-bonn.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pcie.all;
use work.host_types.all;
use work.utils.all;

entity receiver_repack is
port(
	clk: in std_logic;

	i:     in  fragment;
	i_vld: in  std_logic;
	i_req: out std_logic := '0';

	o:      out std_logic_vector(127 downto 0);
	o_keep: out std_logic_vector(  3 downto 0);
	o_vld:  out std_logic := '0';
	o_req:  in  std_logic);
end entity;

architecture arch of receiver_repack is
	type vec is array(3 downto 0) of dword;
	signal i_vec, o_vec: vec := (others => (others => '0'));

	signal pipe_buf: dword := (others => '0');
	signal pipe_eof, pipe_vld: std_logic := '0';

begin

i_req <= o_req;
i_vec <= ( dword(i.data(127 downto 96)), dword(i.data( 95 downto 64)), dword(i.data( 63 downto 32)), dword(i.data( 31 downto 0)));
o     <= o_vec(3) & o_vec(2) & o_vec(1) & o_vec(0);

process
begin
	wait until rising_edge(clk) and o_req = '1';

	pipe_eof <= i.eof and i.keep(3);
	pipe_vld <= i_vld and i.keep(3);
	pipe_buf <= i_vec(3);
	o_vec    <= i_vec(2 downto 0) & pipe_buf;

	o_vld <= (pipe_vld and i_vld) or (pipe_eof and pipe_vld);

	o_keep <= "0001" when pipe_vld and pipe_eof else
	          "0011" when i_vld = '1' and i.eof = '1' and i.keep = "0001" else
	          "0111" when i_vld = '1' and i.eof = '1' and i.keep = "0011" else
	          "1111";

end process;

end architecture arch;
