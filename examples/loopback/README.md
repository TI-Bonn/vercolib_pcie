Loopback example
----------------

### Build hardware

##### Dependencies:
* Vivado 2017.4

##### Steps
* Run `vivado -mode batch -source ./create_project.tcl` from the command line
* Open Vivado project in ./vivado\_loopback
* Generate bitstream through Vivado
* Program the FPGA using the Vivado Hardware Server


### Build Software

##### Dependecies
* GCC >= 5.0
* The VerCoLib-PCIe Linux driver, see [the driver Readme](../../software/linux_driver/README.md) for build instructiions.

##### Steps
* Do either of these steps:
  * Create udev rules such that the FPGA running the loopback bitfile is called `fpga_1` and all channels are called `fpga_1_<tx|rx>_<id>`.
  * Change the `'/dev/fpga_1_tx_2'` and '`/dev/fpga_1_rx_1'` filenames in [`software/loopback.cpp`](./software/loopback.cpp) to reflect the device files on your system.
* Run `make` in [./software](./software).
* Run the executable `loopback` in ./software.
