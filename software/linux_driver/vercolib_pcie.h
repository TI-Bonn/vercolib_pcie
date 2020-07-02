// Kernel driver module to communicate with the VerCoLib-PCIe transceiver
// Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

#ifndef _VERCOLIB_PCIE_H
#define _VERCOLIB_PCIE_H

#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/interrupt.h>
#include <linux/list.h>
#include <linux/spinlock.h>
#include <linux/cdev.h>
#include <linux/dma-mapping.h>
#include <asm/atomic.h>

#define DBG_OUTPUT 1

#ifdef DBG_OUTPUT
#define dbg_print(f_, ...) printk((f_), ##__VA_ARGS__)
#else
#define dbg_print(f_, ...)
#endif

extern const char driver_name[];
extern struct class *vcl_channel_class;
extern struct class *vcl_endpoint_class;

struct buffer {
	struct list_head list;

	u8 id;
	bool in_flight;

	u32 head;
	u32 size;
	u32 init_size;
	void *ptr;
	dma_addr_t dma_addr;
};

enum channel_register_offsets {
	CHN_ADDR_LO_REG = (0 << 2),
	CHN_ADDR_HI_REG = (1 << 2),
	CHN_SIZE_REG = (2 << 2),
	CHN_MODE_REG = (3 << 2),
	CHN_TRNS_REG = (4 << 2),
	CHN_INFO_REG = (5 << 2),
	CHN_DATA_REG = (15 << 2),
};

struct channel {
	struct device *dev;
	enum dma_data_direction direction;

	__iomem void *base_addr;

	wait_queue_head_t waitq;
	spinlock_t lock;

	struct list_head idle_buffers;
	struct list_head active_buffers;
	struct list_head serviced_buffers;

	u8 num_idle_buffers;
	u8 num_active_buffers;
	u8 num_serviced_buffers;

	u32 id;
	u32 transaction_id;
	atomic_t open_count;
};

struct pcie_endpoint {
	struct device *dev;

	u32 id;
	u32 channel_info;

	__iomem void *base_addr;
	unsigned long long bar;

	struct cdev mmio_cdev;
	atomic_t mmio_open_count;

	struct cdev channel_cdev;
	struct channel **channels;
	size_t channel_cnt;
};

int mmio_device_init(struct pcie_endpoint *);
void mmio_device_cleanup(struct pcie_endpoint *);

int channels_init(struct pcie_endpoint *ep);
irqreturn_t host_channel_isr(int, void *);

void add_idle_buffer(struct channel *, struct buffer *);
bool has_idle_buffer(struct channel *);
struct buffer *remove_idle_buffer(struct channel *);

void add_active_buffer(struct channel *, struct buffer *);
bool has_active_buffer(struct channel *);

void add_serviced_buffer(struct channel *, struct buffer *);
bool has_serviced_buffer(struct channel *);
struct buffer *remove_serviced_buffer(struct channel *);

void write_buffer_info(struct channel *, struct buffer *);


int chn_devices_init(struct pcie_endpoint *);
void chn_devices_cleanup(struct pcie_endpoint *);

#endif
