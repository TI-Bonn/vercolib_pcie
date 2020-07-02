Linux Driver
============


### Dependencies
This driver is tested on a  Ubuntu 18.04 system with a 4.15 and a 5.3 kernel.
There is a known incompatibility with all kernel versions <=4.7 due to a change
in the interrupt API.
If you can't compile the driver on with a newer kernel than 4.7, please open an
issue.

You also need the header files for the running kernel. On Ubuntu, these are made
available through the package
`linux-headers-generic`:
```sh
sudo apt install linux-headers-generic
```

### Building & Installing
To build the driver, just run `make` in the drivers directory.
This builds a file `vercolib_pcie.ko`. To load the driver your currently running
system run:
```sh
sudo insmod ./vercolib_pcie.ko
```
If you want to permanently install the driver module on your system, copy the
file to your systems module directory.
The following command does so, regardless of the specific kernel version you're
running:
```sh
sudo copy ./vercolib_pcie.ko /lib/modules/`uname -r`/kernel/drivers/char
```

After this you can load the install driver with:
```sh
sudo modprobe vercolib_pcie
```

If you want to unload the driver from the running system, run:
```sh
sudo rmmod vercolib_pcie
```

### Using DKMS
We recommend that you setup a [DKMS](https://github.com/dell/dkms) package for
this driver, so you don't need to manually re-install it every time the
host systems receives a kernel update.
To setup and install a DKMS package for this driver, run the following script
located in the drivers source directory:
```sh
./setup_dkms
```



### Using the driver
Once the driver is loaded and the FPGA is programmed with a bitstream containing
the PCIe transceiver, the system should be ready to use.
Note that (re-)progamming the FPGA usually doesn't send a signal to the kernel,
which is left unaware of the hardware change.
In this case you need to manually issue a rescan of the PCIe devices in
question.
To do this, you need to know the bus number of the FPGA in your current system.
You can find it out by running `lspci`:
```sh
lspci
…
03:00.1 Audio device: NVIDIA Corporation GK107 HDMI Audio Controller (rev a1)
04:00.0 Memory controller: Xilinx Corporation Device 7028
07:00.0 FireWire (IEEE 1394): VIA Technologies, Inc. VT6315 Series Firewire Controller (rev 01)
…
```
In the result of `lspci` you should see at least one device which is classified
as `Memory controllor: Xilinx Corporation Device`.
In the case above, the corresponding bus-device-function number is `04:00.0`.

To rescan a spcific PCIe device, run the following *as root*:
```sh
echo 1 > /sys/bus/pci/devices/<bus-device-function number>/remove
echo 1 > /sys/bus/pci/devices/<bud-device-function number>/rescan
```

To verify that the driver attached itself to the PCIe devices, you can run
`dmesg` and obsever the last couple lines of output:
```sh
dmesg
…
[10172.378371] pci 0000:04:00.0: [10ee:7028] type 00 class 0x058000
[10172.378395] pci 0000:04:00.0: reg 0x10: [mem 0xf7200000-0xf7200fff]
[10172.378405] pci 0000:04:00.0: reg 0x14: [mem 0xf7201000-0xf72017ff]
[10172.388364] pci 0000:04:00.0: BAR 0: assigned [mem 0xf7200000-0xf7200fff]
[10172.388371] pci 0000:04:00.0: BAR 1: assigned [mem 0xf7201000-0xf72017ff]
[10203.713653] vercolib_pcie 0000:04:00.0: Initialised endpoint 0 with 2 channel(s).
```
The important line of the output is the last one; it tells you that the driver
initialised one endpoint with the dynamically assigned number 0 and 2 channels.

Once the driver has attached itself to a device, it presents one device file for
the endpoint and each channel in `/dev`.
For the example above, the following files would be present:
```
/dev/vcl_0
/dev/vcl_0_rx_1
/dev_vcl_0_tx_2
```
Files named `vcl_<i>` are access points to communicate directly with the
transceiver via ioctls.

**Note:**

The `<i>` number is assigned by the driver and will be different each
time the devices is scanned!

The files called `vcl_<i>_<rx|tx>_<id>` are the access points for the
corresponding channel modules in the hardware, with <id> being the
channel id assigned to the FPGA channel module and <rx|tx> being the
direction of the channel from the perspective of the FPGA (so any rx channel
transports data from the host to the FPGA and vice versa).

It is highly recommended to use udev rules to create symlinks to
the devices files that remain constant and to allow read and write
access to non-root users.

To do so, you need to create a `.rules` file that finds the driver
devices files, sets the correct access mode and creates thet symlinks.
This file then has to be copied to `/etc/udev/rules.d` and activated
by running the command `udevadm control --reload` as root.
Afterwards you will have to either reload the driver or rescan
the hardware.
You can use the following adapt the following rules to your needs:
```
# 99-vcl.rules
SUBSYSTEM=="vcl_endpoint" MODE="666"
SUBSYSTEM=="vcl_endpoint", KERNELS=="0000:04:00.0", SYMLINK+="virtex7_1"
SUBSYSTEM=="vcl_channel" MODE="666"
SUBSYSTEM=="vcl_channel", KERNELS=="0000:04:00.0", SYMLINK+="virtex7_1_$attr{dir}_$addr{id}"
```

Make sure to replace the entry `KERNELS=="0000:04:00.0"` with the correct
bus-device-function number for your system.



