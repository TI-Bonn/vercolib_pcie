
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcie.all;
use work.transceiver_128bit_types.all;

entity pipe_register is
	port (
		clk    : in std_logic;

		-- Input Port
		i      : in  fragment;
		i_vld  : in  std_logic;
		i_req  : out std_logic := '1';

		-- Output Port
		o      : out fragment := default_fragment;
		o_vld  : out std_logic := '0';
		o_req  : in  std_logic        
	);
end entity pipe_register;

architecture RTL of pipe_register is
	signal i_data : std_logic_vector(133 downto 0);
	signal o_data : std_logic_vector(133 downto 0);
	signal internal_data : std_logic_vector(133 downto 0);
	signal internal_new : std_logic;
	signal internal_cont : std_logic;
	
begin
	
	i_data <= packet_to_slv(i);
	

dvc_to_dnc: entity work.channel_DVCtoDNC
	generic map(
		data_bits => 134
	)
	port map(
		clk    => clk,
		i_data => i_data,
		i_vld  => i_vld,
		i_cont => i_req,
		o_data => internal_data,
		o_new  => internal_new,
		o_cont => internal_cont
	);
	
dnc_to_dvc: entity work.channel_DNCtoDVC
	generic map(
		data_bits => 134
	)
	port map(
		clk    => clk,
		i_data => internal_data,
		i_new  => internal_new,
		i_cont => internal_cont,
		o_data => o_data,
		o_vld  => o_vld,
		o_cont => o_req
	);
	
	o <= slv_to_packet(o_data);

end architecture RTL;
