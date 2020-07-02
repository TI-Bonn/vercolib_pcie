obj-m := vercolib_pcie.o
vercolib_pcie-y := vercolib.o mmio_device.o channel.o channel_device.o


all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

debug:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules EXTRA_CFLAGS="-DDEBUG"


clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
