-- Host specific types for VHDL
-- Author: Sebastian Schüller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package host_types is
	subtype nibble is std_logic_vector(  3 downto 0);
	subtype   byte is std_logic_vector(  7 downto 0);
	subtype   word is std_logic_vector( 15 downto 0);
	subtype  dword is std_logic_vector( 31 downto 0);
	subtype  qword is std_logic_vector( 63 downto 0);
	subtype qdword is std_logic_vector(127 downto 0);

	subtype  u8 is unsigned( 7 downto 0);
	subtype u16 is unsigned(15 downto 0);
	subtype u32 is unsigned(31 downto 0);
	subtype u64 is unsigned(63 downto 0);

	subtype  s8 is signed( 7 downto 0);
	subtype s16 is signed(15 downto 0);
	subtype s32 is signed(31 downto 0);
	subtype s64 is signed(63 downto 0);
end package;
