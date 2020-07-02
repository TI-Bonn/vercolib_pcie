// General channel oriented function
// Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

#include "vercolib_pcie.h"

#define chn_id_offset(id) (id << 6)

#define chn_info_dir(info) ((info >> 8) & 0x3)
#define chn_info_kind(info) ((info >> 10) & 0x7)

#define host_chn_cnt(info) ((info & 0xFF) + ((info >> 8) & 0xFF))
#define chn_cnt(info) (info & 0xFF) + ((info >> 8) & 0xFF) + \
	((info >> 16) & 0xFF) + ((info >> 24) & 0xFF)

#define BUF_CNT 2
#define BUF_ORD 8

enum channel_info_dir {
	CHN_DIR_RX = 0,
	CHN_DIR_TX = 1,
	CHN_DIR_BI = 2,
	CHN_DIR_NONE = 3,
};

enum channel_info_kind {
	CHN_KIND_HOST,
};

static inline u32 read_channel_info(struct pcie_endpoint *ep, u32 id) {
	u32 info = ioread32(ep->base_addr + chn_id_offset(id) + CHN_INFO_REG);
	return info;
}

static inline u32 read_transferred_bytes(struct channel *chn) {
	return ioread32(chn->base_addr + chn_id_offset(chn->id) + CHN_TRNS_REG);
}


static bool has_buffer(struct channel *chn, struct list_head *list) {
	bool ret;
	unsigned long flags;
	spin_lock_irqsave(&chn->lock, flags);
	ret = !list_empty(list);
	spin_unlock_irqrestore(&chn->lock, flags);
	return ret;
}

bool has_idle_buffer(struct channel *chn) {
	return has_buffer(chn, &chn->idle_buffers);
}

bool has_active_buffer(struct channel *chn) {
	return has_buffer(chn, &chn->active_buffers);
}

bool has_serviced_buffer(struct channel *chn) {
	return has_buffer(chn, &chn->serviced_buffers);
}

static void add_buffer(struct channel *chn, struct list_head *list, struct buffer *buf) {
	unsigned long flags;
	spin_lock_irqsave(&chn->lock, flags);
	list_add_tail(&buf->list, list);
	spin_unlock_irqrestore(&chn->lock, flags);
}

void add_active_buffer(struct channel *chn, struct buffer *buf) {
	add_buffer(chn, &chn->active_buffers, buf);
	chn->num_active_buffers += 1;
}

void add_idle_buffer(struct channel *chn, struct buffer *buf) {
	add_buffer(chn, &chn->idle_buffers, buf);
	chn->num_idle_buffers += 1;
}

void add_serviced_buffer(struct channel *chn, struct buffer *buf) {
	add_buffer(chn, &chn->serviced_buffers, buf);
	chn->num_serviced_buffers += 1;
}

static struct buffer *remove_buffer(struct channel *chn, struct list_head *list) {
	struct buffer *buf = NULL;
	unsigned long flags;
	spin_lock_irqsave(&chn->lock, flags);
	if(!list_empty(list)) {
		buf = list_entry(list->next, struct buffer, list);
		list_del_init(&buf->list);
	}
	spin_unlock_irqrestore(&chn->lock, flags);
	return buf;
}

struct buffer *remove_idle_buffer(struct channel *chn) {
	struct buffer *buf = remove_buffer(chn, &chn->idle_buffers);
	if(buf) {
		chn->num_idle_buffers -= 1;
	}
	return buf;
}

struct buffer *remove_serviced_buffer(struct channel *chn) {
	struct buffer *buf = remove_buffer(chn, &chn->serviced_buffers);
	if(buf) {
		chn->num_serviced_buffers -= 1;
	}
	return buf;
}

void write_buffer_info(struct channel *chn, struct buffer *buf) {
	u32 lo_addr = (u32)(buf->dma_addr);
	u32 hi_addr = (u32)(buf->dma_addr >> 32);

	buf->in_flight = true;
	iowrite32(lo_addr, chn->base_addr + chn_id_offset(chn->id) + CHN_ADDR_LO_REG);
	if(!!hi_addr) {
		iowrite32(hi_addr, chn->base_addr + chn_id_offset(chn->id) + CHN_ADDR_HI_REG);
	}
	iowrite32((u32)buf->size, chn->base_addr + chn_id_offset(chn->id) + CHN_SIZE_REG);
}


irqreturn_t host_channel_isr(int irq, void *data) {
	struct channel *chn = data;
	struct buffer *buf;
	unsigned long flags;


	// The first active buffer has been serviced by the hardware
	//
	spin_lock_irqsave(&chn->lock, flags);

	buf = list_entry(chn->active_buffers.next, struct buffer, list);
	list_del_init(&buf->list);
	chn->num_active_buffers -= 1;

	dma_unmap_single(
		chn->dev, buf->dma_addr, buf->size, chn->direction);
	buf->in_flight = false;
	buf->size = read_transferred_bytes(chn);
	buf->head = 0;

	dev_dbg(chn->dev, "ISR Channel %d: Closing transaction %u with %u bytes transfer on buffer %d.", chn->id, chn->transaction_id, buf->size,  buf->id);

	list_add_tail(&buf->list, &chn->serviced_buffers);
	chn->num_serviced_buffers += 1;


	// We may still have some active buffers waiting to be serviced by the hardware.
	if(!list_empty(&chn->active_buffers)) {
		buf = list_entry(chn->active_buffers.next, struct buffer, list);
		if(buf->in_flight != true) {
			buf->dma_addr = dma_map_single(
				chn->dev, buf->ptr, buf->size, chn->direction);
			if(unlikely(dma_mapping_error(chn->dev, buf->dma_addr))) {
				dev_warn(chn->dev, "ISR Channel %d: Failed to map dma adress for buffer %d", chn->id, buf->id);
				dma_unmap_single(
					chn->dev, buf->dma_addr,
					buf->size, chn->direction
				);
				spin_unlock_irqrestore(&chn->lock, flags);
				return IRQ_HANDLED;
			}
			write_buffer_info(chn, buf);
			chn->transaction_id += 1;
			dev_dbg(chn->dev, "ISR Channel %d: Opening transaction %u requesting %u bytes on buffer %d.", chn->id, chn->transaction_id, buf->size, buf->id);
		} else {
			dev_dbg(chn->dev, "ISR Channel %d: Didn't schedule new buffer since it's already been scheduled by map_and_request_buffer.", chn->id);
		}
	} else {
		dev_dbg(chn->dev, "ISR Channel %d: Did't find any further buffers for queueing", chn->id);
	}

	spin_unlock_irqrestore(&chn->lock, flags);

	wake_up_interruptible(&chn->waitq);

	return IRQ_HANDLED;
}

static struct buffer *create_buffer(struct channel *chn, u8 id, size_t page_order) {
	struct buffer *buffer = NULL;
	buffer = devm_kmalloc(chn->dev, sizeof(*buffer), GFP_KERNEL);
	if(!buffer) {
		return ERR_PTR(-ENOMEM);
	}
	INIT_LIST_HEAD(&buffer->list);
	buffer->head = 0;
	buffer->size = 0;
	buffer->in_flight = false;
	buffer->id = id;
	buffer->init_size = (1 << page_order) * PAGE_SIZE;
	buffer->ptr = (void *)devm_get_free_pages(chn->dev, GFP_KERNEL, page_order);
	if(!buffer->ptr) {
		return ERR_PTR(-ENOMEM);
	}

	return buffer;
}

static struct channel *init_channel(
	struct pcie_endpoint *ep,
	u32 id,
	enum dma_data_direction dir
) {
	struct channel *chn = devm_kmalloc(ep->dev, sizeof(*chn), GFP_KERNEL);
	struct buffer *buf = NULL;
	size_t idx;

	if(unlikely(!chn)) {
		return ERR_PTR(-ENOMEM);
	}

	chn->dev = ep->dev;
	chn->direction = dir;

	chn->base_addr = ep->base_addr;

	init_waitqueue_head(&chn->waitq);
	spin_lock_init(&chn->lock);

	INIT_LIST_HEAD(&chn->idle_buffers);
	INIT_LIST_HEAD(&chn->active_buffers);
	INIT_LIST_HEAD(&chn->serviced_buffers);

	chn->num_idle_buffers = 0;
	chn->num_active_buffers = 0;
	chn->num_serviced_buffers = 0;

	chn->id = id;
	chn->transaction_id = 0;
	atomic_set(&chn->open_count, 0);

	for(idx = 0; idx < BUF_CNT; ++idx) {
		buf = create_buffer(chn, idx, BUF_ORD);
		if(IS_ERR(buf)) {
			dev_err(chn->dev,
				"Failed to create channel buffer.");
			return ERR_PTR(PTR_ERR(buf));
		}
		list_add_tail(&buf->list, &chn->idle_buffers);
		chn->num_idle_buffers += 1;
	}

	return chn;
}

int channels_init(struct pcie_endpoint *ep) {
	struct channel *new;
	size_t host_chns = host_chn_cnt(ep->channel_info);
	size_t chn_cnt = chn_cnt(ep->channel_info);
	size_t host_chn_idx;
	size_t id;

	if(!chn_cnt) {
		dev_dbg(ep->dev, "No channels to set up");
		return 0;
	}

	ep->channels = devm_kcalloc(ep->dev, host_chns, sizeof(new), GFP_KERNEL);

	host_chn_idx = 0;
	for(id = 1; id <= chn_cnt; ++id) {
		u32 chn_info;
		enum channel_info_dir chn_dir;
		enum dma_data_direction dma_dir = DMA_NONE;
		enum channel_info_kind chn_kind;

		chn_info = read_channel_info(ep, id);
		if(chn_info == 0xFFFFFFFF) {
			dev_err(ep->dev, "Failed to read channel info for id %lu.", id);
			continue;
		}

		chn_dir = (chn_info >> 8) & 0x3;
		chn_kind = (chn_info >> 11) & 0x5;

		if(chn_kind != CHN_KIND_HOST) {
			continue;
		}

		switch(chn_dir) {
			case CHN_DIR_RX:
				dma_dir = DMA_TO_DEVICE;
				break;
			case CHN_DIR_TX:
				dma_dir = DMA_FROM_DEVICE;
				break;
			case CHN_DIR_BI:
				dma_dir = DMA_BIDIRECTIONAL;
				break;
			default:
				dma_dir = DMA_NONE;
				break;
		};

		// We currently have no support for non-unidirectional dma
		// channels in the driver.
		if(dma_dir != DMA_TO_DEVICE && dma_dir != DMA_FROM_DEVICE) {
			return -ENODEV;
		}

		new = init_channel(ep, id, dma_dir);
		if(IS_ERR(new)) {
			return PTR_ERR(new);
		}
		ep->channels[host_chn_idx++] = new;
	}
	ep->channel_cnt = host_chn_idx;
	return 0;
}

