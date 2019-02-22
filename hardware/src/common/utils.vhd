library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package utils is

function repr(input : natural) return natural;
function ones(input: std_logic_vector) return natural;
function min(a,b: unsigned) return unsigned;
function change_endianess_32(input: std_logic_vector(31 downto 0)) return std_logic_vector;
function change_endianess_DW(input: std_logic_vector) return std_logic_vector;
function keep2cnt(i: std_logic_vector(3 downto 0)) return unsigned;

end package utils;

package body utils is

	-- function to calculate number of bits to represent input
	-- (Note: This was formally called log2, but this name isn't
	-- really correct and confused me. -sebastian)
	function repr(input : natural) return natural is
		variable temp : natural := 1;
		variable ret  : natural := 0;
	begin
		for i in 0 to input loop
			if temp <= input then
				ret  := ret + 1;
				temp := temp * 2;
			end if;
		end loop;
		return ret;
	end function;

	function ones(input: std_logic_vector) return natural is
		variable ret: natural := 0;
	begin
		for i in 0 to input'length - 1 loop
			if ?? input(i) then
				ret := ret + 1;
			end if;
		end loop;
		return ret;
	end ones;

	function min(a,b: unsigned) return unsigned is
		variable ret: unsigned(maximum(a'high, b'high) downto 0) := (others => '0');
	begin
		if a <= b then
			ret := resize(a, ret'length);
		else
			ret := resize(b, ret'length);
		end if;
		return ret;
	end min;

	function change_endianess_32 (input: std_logic_vector(31 downto 0)) return std_logic_vector is
		variable ret: std_logic_vector(31 downto 0);
	begin
		ret(7 downto 0)   := input(31 downto 24);
		ret(15 downto 8)  := input(23 downto 16);
		ret(23 downto 16) := input(15 downto 8);
		ret(31 downto 24) := input(7 downto 0);
		return ret;
	end function;
	
	function change_endianess_DW (input: std_logic_vector) return std_logic_vector is
		variable ret  : std_logic_vector(input'high-input'low downto 0);
	begin
		for i in 1 to (input'high-input'low+1)/32 loop
			ret(32*i-1 downto 32*(i-1)) := change_endianess_32(input(input'low+32*i-1 downto input'low+32*(i-1)));
		end loop;
		return ret;
	end function;
	
	function keep2cnt(i: std_logic_vector(3 downto 0)) return unsigned is
		variable ret: unsigned(2 downto 0) := (others => '0');
	begin
		ret :=
			3x"4" when i = "1111" else
			3x"3" when i = "0111" else
			3x"2" when i = "0011" else
			3x"1" when i = "0001" else
			3x"0" when i = "0000" else
			"XXX";
			assert ret /= "XXX"
				report "Invalid keep value. All marks should be consecutive from the LSB!"
				severity failure;
			return ret;
	end function;

end utils;

