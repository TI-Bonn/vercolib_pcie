
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.transceiver_128bit_types.all;

entity pipe_reg is
	generic(data_bits : natural);
	port (
		clk    : in std_logic;

		-- Input Port
		i      : in  std_logic_vector(data_bits-1 downto 0);
		i_vld  : in  std_logic;
		i_req  : out std_logic;

		-- Output Port
		o      : out std_logic_vector(data_bits-1 downto 0);
		o_vld  : out std_logic := '0';
		o_req  : in  std_logic        
	);
end entity pipe_reg;

architecture RTL of pipe_reg is

	signal internal_data : std_logic_vector(data_bits-1 downto 0);
	signal internal_new : std_logic;
	signal internal_cont : std_logic;
	
begin
		

dvc_to_dnc: entity work.channel_DVCtoDNC
	generic map(
		data_bits => data_bits
	)
	port map(
		clk    => clk,
		i_data => i,
		i_vld  => i_vld,
		i_cont => i_req,
		o_data => internal_data,
		o_new  => internal_new,
		o_cont => internal_cont
	);
	
dnc_to_dvc: entity work.channel_DNCtoDVC
	generic map(
		data_bits => data_bits
	)
	port map(
		clk    => clk,
		i_data => internal_data,
		i_new  => internal_new,
		i_cont => internal_cont,
		o_data => o,
		o_vld  => o_vld,
		o_cont => o_req
	);

end architecture RTL;
