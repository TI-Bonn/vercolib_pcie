-- Public package for VerCoLib PCIe transciever
-- Author: Sebastian Schüller <schueller@ti.uni-bonn.de>


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--! Public PCIe Transceiver Components, Data types and Functions.

--! For many components of this package the ports can be grouped
--! into simple streaming interfaces.
--! Ports belonging to the same interface share the same prefix in
--! their name (up to the last '_').
--! Each interface contains exactly one data port (either without
--! the suffix '_data' or without any suffix at all), one valid port
--! with the suffix '_vld' in the same direction as the data, and one
--! request port with the suffix '_req' in the opposite direction.
--! Words on the data port are consumed if, and only if both, valid
--! and request are set at the rising edge of the corresponding clock
--! signal.
--! A valid signal may only ever be changed if the corresponding
--! request signal is asserted and may only ever be deasserted if
--! at least one data word was consumed.
--! A request signal, once asserted, may only ever be deasserted if
--! the corresponding valid signal is asserted.
--! These rules imply that the only time it is OK for both control
--! signals to be deasserted is before the first change of the first
--! control signal.
--! As soon as the request signal was asserted once, there is no
--! valid transition that leaves both controls signals deasserted.
package pcie is


	--! The central configuration for the PCIe transceiver.
	--!
	--! _Note_:
	--! This type should be considered opaque and only be constructed/accessed
	--! through the provided functions.
	--!
	--! This record is used to configure the number of channels one instance of
	--! the PCIe transceiver uses as well as configuration parameters governing
	--! how the transceiver communicates with the PCIe bus.
	--!
	--! For convenient setup, create this record using the @ref new_config
	--! function and only specify the number of channels you plan to use.
	--! This should result in a full-duplex host-FPGA performance of roughly
	--! 2.79 GByte/s.
	--!
	--! _Example_:
	--!
	--! ```
	--! constant config: pcie.transceiver_configuration := new_config(
	--!     host_tx => 1,
	--!     host_rx => 1
	--! );
	--! ```
	--! The following behaviours are parameterized by this record:
	--!
	--! * `max_request_bytes`:
	--!
	--!   Sets the maximum number of bytes a channel is allowed to
	--!   request from main memory.
	--!   This generic corresponds directly to the `Max_Read_Request_Size`
	--!   parameter of the PCIe base specification.
	--!   Allowed values for `max_request_bytes` are (as taken from the PCIe 2
	--!   specification): 128, 256, 512, 1024, 2048 and 4096.
	--!   A higher `max_request_bytes` results in higher payload/packet_size
	--!   ratio which should in principal increase performance.
	--!   It's very likely that the operating system / mainboard chipset will
	--!   limit the choice to a smaller value than the PCIe specification would
	--!   allow.
	--!
	--!   **Warning!**: If an unsupported value is selected for
	--!   `max_request_bytes` the packets will most likely be silently dropped.
	--!
	--!   On Linux host systems supported values for `max_request_bytes` and
	--!   `max_payload_bytes` can be determined by calling `lspci -vv`
	--!   as the root user and looking at the capabilities entry of the FPGA
	--!   device.
	--!   The maximum supported payload size is specified under the entry
	--!   `DevCap: MaxPayload xxx bytes` and the current system selection
	--!   can be found under `DevCtl: MaxPayload xxx bytes`,
	--!   `MaxReadReq yyy bytes.`
	--!
	--!   This is currently only used by @ref rx_host_channel instances, since
	--!   only these channels request data directly from main memory.
	--!   By default channels will always try to request as many bytes as
	--!   they are allowed to, however they will request less data if the
	--!   request finishes the overall transaction, or a request would cross
	--!   a page boundary in main memory.
	--!
	--! * `max_payload_bytes`:
	--!
	--!   Sets the maximum number of bytes a channel is allowed to
	--!   send in one transaction.
	--!   Like `max_request_bytes`, `max_payload_bytes` corresponds to
	--!   a PCIe parameter (`Max_Payload_Size` in this case).
	--!   Read the `max_request_bytes` segment to see how this generic can and 
	--!   should be set.
	--!   Channels try to always maximise payload sizes up to `max_payload_size`
	--!   . They will not do so if either the outstanding request is smaller
	--!   than `max_payload_bytes` or if the payload would cross a page boundary
	--!   on the main memory.
	--!
	--! * `interrupts`:
	--!
	--!   Sets the number of MSI-X interrupt vectors the transceiver uses.
	--!
	--! * `host_rx_channels`, `host_tx_channels`:
	--!
	--!   Number of Host-FPGA (`rx`) and FPGA-Host (`tx`) channels.
	--!   This is used to generate the correct endpoint port size to connect
	--!   channels instances to. It also informs the host driver on how many
	--!   channels the hardware uses and thus how many software-channels need
	--!   to be generated.
	--!
	--! * `fpga_rx_channels`, `fpga_rx_channels`:
	--!
	--!   Number of incoming (`rx`) and outgoing (`tx`) FPGA-FPGA channels.
	--!   This is mainly used to size the endpoint ports connecting the
	--!   channel instances.
	--!
	--! Creation functions:
	--!   * @ref new_config
	--!
	--! Accessor functions:
	--!   * @ref channel_count
	--!   * @ref rx_count
	--!   * @ref tx_count
	--!   * @ref host_rx_count
	--!   * @ref host_tx_count
	--!   * @ref fpga_rx_count
	--!   * @ref fpga_tx_count
	type transceiver_configuration is record
		max_payload_bytes : natural;
		max_request_bytes : natural;
		interrupts        : natural;
		host_rx_channels : natural;
		host_tx_channels : natural;
		fpga_rx_channels : natural;
		fpga_tx_channels : natural;
	end record;

	--! Create new transceiver configuration
	--!
	--! Creates a new transceiver_configuration with user-selected and
	--! default parameters.
	--!
	--! The non-zero default parameters are selected to create a valid
	--! and reasonable performant transceiver.
	--!
	--! @param mbp Maximum Payload Size (in Bytes)
	--! @param mrb Maximum Request Size (in Bytes)
	--! @param interrupts Number of registered MSI-X interrupts
	--! @param host_tx Number of FPGA-Host channels
	--! @param host_rx Number of Host-FPGA channels
	--! @param fpga_tx Number of outgoing FPGA-FPGA channels
	--! @param fpga_rx Number of incoming FPGA-FPGA channels
	function new_config(
		mpb: natural := 128;
		mrb: natural := 512;
		interrupts: natural := 128;
		host_tx: natural;
		host_rx: natural;
		fpga_tx: natural := 0;
		fpga_rx: natural := 0
	) return transceiver_configuration;

	--- Accessor functions for the transceiver_configuration record.

	--! Get the maximum payload size of a transceiver_configuration.
	function mpb(conf: transceiver_configuration) return natural;

	--! Get the maximum read request size of a transceiver_configuration.
	function mrb(conf: transceiver_configuration) return natural;

	--! Get the number of registered MSI-X interrupts of a
	--! transceiver_configuration.
	function interrupts(conf: transceiver_configuration) return natural;

	--! Get the total number of channels of a transceiver_configuration.
	function channel_count(conf: transceiver_configuration) return natural;

	--! Get the total number of incoming channels of a
	--! transceiver_configuration.
	function rx_count(conf: transceiver_configuration) return natural;

	--! Get the total number of outgoing channels of a
	--! transceiver_configuration.
	function tx_count(conf: transceiver_configuration) return natural;

	--! Get the number of FPGA-Host channels of a transceiver_configuration.
	function host_rx_count(conf: transceiver_configuration) return natural;

	--! Get the number of Host-FPGA channels of a transceiver_configuration.
	function host_tx_count(conf: transceiver_configuration) return natural;

	--! Get the number of incoming FPGA-FPGA channels of a
	--! transceiver_configuration.
	function fpga_rx_count(conf: transceiver_configuration) return natural;

	--! Get the number of outgoing FPGA-FPGA channels of a
	--! transceiver_configuration.
	function fpga_tx_count(conf: transceiver_configuration) return natural;

	---

	--! Datatype used by all outgoing channels of the transceiver.
	--! This is the type of the user-facing data port of all `tx` channels.
	--! It's meant to be a public data type that is supposed to
	--! be usable in user-designs to create valid inputs for
	--! outgoing channels.
	--!
	--! The `payload` contains the user-data and should be interpreted as
	--! a vector of four 32bit DWords ordered from low to high indices:
	--!
	--! | Bit     |127:96 | 95:64 | 63:32 | 31:0  |
	--! |:--------|:-----:|:-----:|:-----:|:-----:|
	--! | DW      |   3   |   2   |   1   |   0   |
	--!
	--! The last word of a transmission must be marked by
	--! setting `end_of_stream` to `'1'` to ensure that all internal buffers
	--! in the channel modules send all remaining data to their target.
	--! If this isn't done, the last up to `max_payload_bytes` bytes will remain
	--! in the outgoing channel and potentially never be sent.
	--! Setting `end_of_stream` causes the channel to stop accepting new data
	--! until the current transmission is complete.
	--! Keeping `end_of_stream` continuously set to `'1'` will flush the
	--! outgoing channel with each word, which will _severely_ degrade
	--! performance.
	--! 
	--! The smallest unit of transferable data the transceiver supports is
	--! 32bit wide words.
	--! In order to transmit data that doesn't cleanly fit into the 128bit
	--! `payload` word, the last word of a transmission is allowed to only
	--! carry `cnt` number of valid DWords.
	--! In this case all DWords whose indices are smaller or equal to `cnt` - 1
	--! are interpreted as valid and all other DWords are ignored.
	--!
	--! **Warning!**:
	--! Setting `cnt` to anything less than 4 at any time other than the last
	--! word of a transmission is considered an error will probably result in
	--! data loss.
	type tx_stream is record
		payload       : std_ulogic_vector(127 downto 0);
		cnt           : unsigned(2 downto 0);
		end_of_stream : std_ulogic;
	end record;

	--! Default value to initialize tx_stream signals with.
	constant default_tx_stream: tx_stream := (
		payload       => (others => '0'),
		cnt           => (others => '0'),
		end_of_stream => '0'
	);

	--! Convenience vector type to handle multiple tx_stream signals.
	type tx_stream_vector is array (natural range <>) of tx_stream;

	--! Datatype used by all incoming channels of the transceiver.
	--! This is the type of the user-facing data port of all `rx` channels.
	--! It's meant to be a public data type that is supposed to
	--! be usable in user-designs to read data from incoming channels.
	--!
	--! The `payload` holds user-data and should be interpreted as a vector of
	--! four 32bit DWords ordered from low to high indices:
	--!
	--! |            127:0              |
	--! ---------------------------------
	--! |   3   |   2   |   1   |   0   | DWord indices
	--! |127:96 | 95:64 | 63:32 | 31:0  | Bit indices
	--!
	--! To facilitate transfer of data that does not fit cleanly into
	--! 128bit blocks (but fits cleanly into 32bit blocks), only
	--! `cnt` number of DWords contain valid data.
	--! Specifically all DWords with and index that is smaller or equal to
	--! `cnt` - 1 are valid, while all DWords with an index larger than `cnt`
	--! should be ignored.
	--! This may happen at any time during a transaction.
	type rx_stream is record
		payload : std_ulogic_vector(127 downto 0);
		cnt     : unsigned(2 downto 0);
	end record;

	--! Default value to initialize rx_stream signals with.
	constant default_rx_stream: rx_stream := (
		payload => (others => '0'),
		cnt     => (others => '0')
	);

	--! Convenience vector type to handle multiple rx_stream signals.
	type rx_stream_vector is array (natural range <>) of rx_stream;

	--! Datatype used for channel <-> endpoint communication.
	--! _Note_:
	--! Endusers of the transceiver should never have to actively
	--! handle the contents of a fragment.
	--! Users only have to instantiate the required fragment signals
	--! to connect all channel instances to the endpoint.
	--!
	--! A fragment contains four words of a transceiver-internal
	--! packet format in `data`.
	--! `keep` signifies which of the four DWords that are contained
	--! within `data` are valid.
	--! `sof` and `eof` signify whether the fragment is at a boundary of
	--! the packet.
	type fragment is record
		sof  : std_logic;
		eof  : std_logic;
		keep : std_logic_vector(  3 downto 0);
		data : std_logic_vector(127 downto 0);
	end record;

	--! Default value to initialize fragment with.
	constant default_fragment: fragment := (
		sof  => '0',
		eof  => '0',
		keep => (others => '0'),
		data => (others => '0')
	);

	--! Vector type to handle multiple fragments.
	type fragment_vector is array (natural range <>) of fragment;

	--! PCIe-2 Endpoint
	--!
	--! Connects the different channel modules to a PCIe-2 physical
	--! interface.
	--! It needs to be instantiated with a valid configuration,
	--! see @ref transceiver_configuration for details on how to
	--! create it.
	--!
	--! Offers a 250MHz clock domain with a synchronous, non-negated reset
	--! which must be used by the channel instances.
	--! It also can be used directly for the user design if desired.
	component gen2_endpoint
		generic(config: transceiver_configuration);
		port(
			clk : out std_logic;
			rst : out std_logic;

			--! PCIe System Interface
			--!
			--! PCIe lane signals that must be connected to the
			--! corresponding pins.
			--! The Xilinx IP-Core specifies the constraints for
			--! these signals, so users just need to pass them through
			--! the toplevel as ports.
			pci_exp_txp : out std_logic_vector(7 downto 0);
			pci_exp_txn : out std_logic_vector(7 downto 0);
			pci_exp_rxp : in  std_logic_vector(7 downto 0);
			pci_exp_rxn : in  std_logic_vector(7 downto 0);

			--! Differential system clock that should be taken from an
			--! external source.
			--! The default configuration for the VC707 board requires
			--! the 100MHz user clock as differential inputs.
			--! Example VC707 costraints:
			--! ```tcl
			--! # Set location for clock buffer.
			--! set_property LOG IBUFDS_GTE2_X1Y5 [get_cells */refclk_ibuf]
			--! create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]
			--! ```
			sys_clk_p   : in  std_logic;
			sys_clk_n   : in  std_logic;

			--! Global, active-low reset signal from the PCIe bus.
			--! Example VC707 constraints:
			--! ```tcl
			--! set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_n]
			--! set_property PACKAGE_PIN AV35 [get_ports sys_rst_n]
			--! set_property PULLUP true [get_ports sys_rst_n]
			--! # Ignore timing errors from PCIe reset
			--! set_false_path -from [get_ports sys_rst_n]
			--! ```
			sys_rst_n   : in  std_logic;

			--! RX Channel interface

			--! Each bus (grouping of `<dir>_rx, <dir>_rx__vld, <dir>_rx_req`)
			--! corresponds to the inverse direction of the connected channel
			--! (the `to_ep` port of an RX channel must be connected
			--! to the `from_rx` port of the ep and vice versa).
			to_rx       : out fragment_vector(rx_count(config)-1 downto 0);
			to_rx_vld   : out std_ulogic_vector(rx_count(config)-1 downto 0);
			to_rx_req   : in  std_ulogic_vector(rx_count(config)-1 downto 0);
			--
			from_rx     : in  fragment_vector(rx_count(config)-1 downto 0);
			from_rx_vld : in  std_ulogic_vector(rx_count(config)-1 downto 0);
			from_rx_req : out std_ulogic_vector(rx_count(config)-1 downto 0);
			---

			--! TX Channel interface

			--! Each bus (grouping of `<dir>_tx, <dir>_tx__vld, <dir>_tx_req`)
			--! corresponds to the inverse direction of the connected channel
			--! (the `to_ep` port of an TX channel must be connected
			--! to the `from_tx` port of the ep and vice versa).
			from_tx_vld : in  std_ulogic_vector(tx_count(config)-1 downto 0);
			from_tx_req : out std_ulogic_vector(tx_count(config)-1 downto 0);
			from_tx     : in  fragment_vector(tx_count(config)-1 downto 0);
			--
			to_tx_vld   : out std_ulogic_vector(tx_count(config)-1 downto 0);
			to_tx_req   : in  std_ulogic_vector(tx_count(config)-1 downto 0);
			to_tx       : out fragment_vector(tx_count(config)-1 downto 0)
			---
		);
	end component;

	--! Userfacing channel to receive data from the host.

	--! The supplied config must be the identical to the config
	--! constant of the corresponding endpoint.
	--! The id must be unique for all channels connected to the
	--! same endpoint.
	--! It also **must** be in the interval [1, rx_count(config)].
	--! The 'from_ep' and 'to_ep' interfaces need to be connected to the
	--! 'to_rx'/'from_rx' interfaces of the endpoit.
	--! The user data is delivered at the 'o' interface.
	--! If 'debug' is set to 'true' additional submodules will be
	--! inserted. These submodules observe several ports inside the
	--! channel and contain signal with set 'mark_debug' attributes
	--! for easier debugging with ILAs.
	component host_rx_channel
		generic(
			debug  : boolean := false;
			config : transceiver_configuration;
			id     : positive
		);
			port(
			clk         : in  std_logic;
			rst         : in  std_logic;
			from_ep     : in  fragment;
			from_ep_vld : in  std_ulogic;
			from_ep_req : out std_ulogic := '1';
			to_ep       : out fragment := default_fragment;
			to_ep_vld   : out std_ulogic := '0';
			to_ep_req   : in  std_ulogic;
			o           : out rx_stream := default_rx_stream;
			o_vld       : out std_ulogic := '0';
			o_req       : in  std_ulogic
		);
	end component;


	--! Userfacing channel to transmit data to the host.

	--! The supplied config must be the identical to the config
	--! constant of the corresponding endpoint.
	--! The id must be unique for all channels connected to the
	--! same endpoint.
	--! It also **must** be in the interval
	--! [rx_count(config)+1, channel_count(config)].
	--! The 'from_ep' and 'to_ep' interfaces need to be connected to the
	--! 'to_tx'/'from_tx' interfaces of the endpoint.
	--! The user data is accepted at the 'i' interface.
	--! If 'debug' is set to 'true' additional submodules will be
	--! inserted. These submodules observe several ports inside the
	--! channel and contain signal with set 'mark_debug' attributes
	--! for easier debugging with ILAs.
	component host_tx_channel
		generic(
			debug  : boolean := false;
			config : transceiver_configuration;
			id     : positive
		);
		port(
			clk         : in  std_logic;
			rst         : in  std_logic;
			i_vld       : in  std_logic;
			i_req       : out std_logic;
			i           : in  tx_stream;
			from_ep     : in  fragment;
			from_ep_vld : in  std_logic;
			from_ep_req : out std_logic;
			to_ep       : out fragment;
			to_ep_vld   : out std_logic;
			to_ep_req   : in  std_logic
		);
	end component host_tx_channel;

	--! Userfacing channel to send data directly to another FPGA.

	--! The supplied config must be the identical to the config
	--! constant of the corresponding endpoint.
	--! The id must be unique for all channels connected to the
	--! same endpoint.
	--! It also **must** be in the interval
	--! [rx_count(config)+1, channel_count(config)].
	--! The 'from_ep' and 'to_ep' interfaces need to be connected to the
	--! 'to_tx'/'from_tx' interfaces of the endpoit.
	--! The user data is accepted at the 'i' interface.
	--!
	--! The depth of the internal FIFO can be configured by setting
	--! 'fifo_addr_bits'.
	--! The resulting actual depth is equal to '2 ** fifo_addr_bits'.
	--! The selected default shouldn't affect performance and is selected
	--! to use a minimal number of BRAM resources for implementation.
	component fpga_tx_channel
		generic(
			config         : transceiver_configuration;
			id             : positive;
			fifo_addr_bits : positive := 9
		);
		port(
			clk         : in  std_logic;
			rst         : in  std_logic;
			from_ep     : in  fragment;
			from_ep_vld : in  std_ulogic;
			from_ep_req : out std_ulogic := '1';
			to_ep       : out fragment := default_fragment;
			to_ep_vld   : out std_ulogic := '0';
			to_ep_req   : in  std_ulogic;
			i           : in  tx_stream;
			i_vld       : in  std_ulogic;
			i_req       : out std_ulogic := '1'
		);
	end component;

	--! Userfacing channel to receive data directly from another FPGA.

	--! The supplied config must be the identical to the config
	--! constant of the corresponding endpoint.
	--! The id must be unique for all channels connected to the
	--! same endpoint.
	--! It also **must** be in the interval [1, rx_count(config)].
	--! The 'from_ep' and 'to_ep' interfaces need to be connected to the
	--! 'to_rx'/'from_rx' interfaces of the endpoit.
	--! The user data is delivered at the 'o' interface.
	--!
	--! The depth of the internal FIFO can be configured by setting
	--! 'fifo_addr_bits'.
	--! The resulting actual depth is equal to '2 ** fifo_addr_bits'.
	--! The selected default shouldn't affect performance and is selected
	--! to use a minimal number of BRAM resources for implementation.
	component fpga_rx_channel
		generic(
			config         : transceiver_configuration;
			id             : positive;
			fifo_addr_bits : positive := 9
		);
		port(
			clk         : in  std_logic;
			rst         : in  std_logic;
			from_ep     : in  fragment;
			from_ep_vld : in  std_ulogic;
			from_ep_req : out std_ulogic := '1';
			to_ep       : out fragment := default_fragment;
			to_ep_vld   : out std_ulogic := '0';
			to_ep_req   : in  std_ulogic;
			o           : out rx_stream := default_rx_stream;
			o_vld       : out std_ulogic := '0';
			o_req       : in  std_ulogic
		);
	end component;

end package;

package body pcie is

	function new_config(
		mpb: natural := 128;
		mrb: natural := 512;
		interrupts: natural := 128;
		host_tx: natural;
		host_rx: natural;
		fpga_tx: natural := 0;
		fpga_rx: natural := 0
	) return transceiver_configuration is
	begin
		return transceiver_configuration'(
			max_payload_bytes => mpb,
			max_request_bytes => mrb,
			interrupts        => interrupts,
			host_rx_channels => host_rx,
			host_tx_channels => host_tx,
			fpga_rx_channels => fpga_rx,
			fpga_tx_channels => fpga_tx
		);
	end;

	function mpb(conf: transceiver_configuration) return natural is
	begin
		return conf.max_payload_bytes;
	end;

	function mrb(conf: transceiver_configuration) return natural is
	begin
		return conf.max_request_bytes;
	end;

	function interrupts(conf: transceiver_configuration) return natural is
	begin
		return conf.interrupts;
	end;

	function channel_count(conf: transceiver_configuration) return natural is
	begin
		return conf.host_rx_channels + conf.host_tx_channels +
		       conf.fpga_rx_channels + conf.fpga_tx_channels;
	end;

	function rx_count(conf: transceiver_configuration) return natural is
	begin
		return conf.host_rx_channels + conf.fpga_rx_channels;
	end;

	function tx_count(conf: transceiver_configuration) return natural is
	begin
		return conf.host_tx_channels + conf.fpga_tx_channels;
	end;

	function host_rx_count(conf: transceiver_configuration) return natural is
	begin
		return conf.host_rx_channels;
	end;

	function host_tx_count(conf: transceiver_configuration) return natural is
	begin
		return conf.host_tx_channels;
	end;

	function fpga_rx_count(conf: transceiver_configuration) return natural is
	begin
		return conf.host_rx_channels;
	end;

	function fpga_tx_count(conf: transceiver_configuration) return natural is
	begin
		return conf.host_tx_channels;
	end;
end package body;
