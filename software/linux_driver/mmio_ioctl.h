// ioctl definitions for channel devices
// Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

#ifndef _VCL_MMIO_IOCTL_H_
#define _VCL_MMIO_IOCTL_H_

#include <linux/ioctl.h>

struct pair_info {
	unsigned long long other_bar;
	unsigned int other_id;
	unsigned int this_id;
};

struct vcl_register {
	unsigned int chn_id;
	unsigned int offset;
	unsigned int value;
};

#define VCL_MMIO_IOCTL_BASE 0xFF

#define VCL_MMIO_IOCTL_GETBAR _IOR(VCL_MMIO_IOCTL_BASE, 0, unsigned long long *)
#define VCL_MMIO_IOCTL_PAIR_TX   _IOW(VCL_MMIO_IOCTL_BASE, 1, struct channel_location *)
#define VCL_MMIO_IOCTL_PAIR_RX   _IOW(VCL_MMIO_IOCTL_BASE, 2, struct channel_location *)
#define VCL_MMIO_IOCTL_RDREG _IOWR(VCL_MMIO_IOCTL_BASE, 3, struct vcl_register *)
#define VCL_MMIO_IOCTL_WRREG _IOW(VCL_MMIO_IOCTL_BASE, 4, struct vcl_register *)

#endif
