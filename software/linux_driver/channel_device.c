// Channel character device functions
// Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/poll.h>

#include "vercolib_pcie.h"

#define BUF_CNT 2
#define BUF_ORD 8

static int open(struct inode *, struct file *);
static int release(struct inode *, struct file *);

static ssize_t write(struct file *, const char *, size_t, loff_t *);
static ssize_t read(struct file *, char *, size_t, loff_t *);

static unsigned int poll(struct file *, poll_table *);


static struct file_operations chn_ops = {
	.owner = THIS_MODULE,
	.llseek = no_llseek,
	.open = open,
	.release = release,
	.write = write,
	.read = read,
	.poll = poll,
};

static int open(struct inode *inode, struct file *filp) {
	struct pcie_endpoint *ep;
	struct channel *chn;
	int open_count;

	ep = container_of(inode->i_cdev, struct pcie_endpoint, channel_cdev);
	chn = ep->channels[iminor(inode)];

	open_count = atomic_read(&chn->open_count);
	if(atomic_read(&chn->open_count)) {
		dev_err(chn->dev, "Called open on busy channel %u", chn->id);
		return -EBUSY;
	}
	atomic_inc(&chn->open_count);
	open_count = atomic_read(&chn->open_count);

	if(chn->direction == DMA_FROM_DEVICE &&
		(inode->i_flags & FMODE_WRITE)) {
		dev_err(chn->dev,
			"Tried to open tx channel w/ read permissions");
		return -ENODEV;
	}

	if(chn->direction == DMA_TO_DEVICE &&
		(inode->i_flags & FMODE_READ)) {
		dev_err(chn->dev,
			"Tried to open rx channel w/ write permissions");
		return -ENODEV;
	}


	filp->private_data = chn;

	return nonseekable_open(inode, filp);
}

static int release(struct inode *inode, struct file *filp) {
	struct channel *chn = filp->private_data;
	int open_count;
	atomic_dec(&chn->open_count);
	open_count = atomic_read(&chn->open_count);
	return 0;
}

static ssize_t map_and_request_buffer(struct channel *chn, struct buffer *buf) {
	ssize_t ret = 0;
	unsigned long flags;
	buf->dma_addr = dma_map_single(
		chn->dev,
		buf->ptr,
		buf->size,
		chn->direction
	);
	if(unlikely(dma_mapping_error(chn->dev, buf->dma_addr))) {
		dma_unmap_single(
			chn->dev,
			buf->dma_addr,
			buf->size,
			chn->direction
		);
		dev_err(chn->dev,
			"Failed to map dma addr for read.");
		return -EFAULT;
	}

	ret = buf->size;


	spin_lock_irqsave(&chn->lock, flags);
	if(list_empty(&chn->active_buffers)) {
		list_add(&buf->list, &chn->active_buffers);

		chn->num_active_buffers += 1;
		write_buffer_info(chn, buf);
		chn->transaction_id += 1;
		dev_dbg(chn->dev, "Channel %d: Opening transaction %u requesting %u bytes on buffer %d.", chn->id, chn->transaction_id, buf->size, buf->id);

	} else {
		dev_dbg(chn->dev, "Channel %d: Queueing buffer %d for transaction with size %d", chn->id, buf->id, buf->size);
		list_add_tail(&buf->list, &chn->active_buffers);
		chn->num_active_buffers += 1;
		dev_dbg(chn->dev, "Channel %d: After queueing a buffer, %d buffers are in the queue.", chn->id, chn->num_active_buffers);
	}
	spin_unlock_irqrestore(&chn->lock, flags);
	return ret;
}

static ssize_t request_idle_buffers(
	struct channel *chn,
	size_t size
) {
	struct buffer *buf;
	ssize_t requested = 0, ret = 0;


	while(has_idle_buffer(chn) && size) {
		buf = remove_idle_buffer(chn);
		buf->size = buf->init_size < size ? buf->init_size : size;

		ret = map_and_request_buffer(chn, buf);
		if(ret < 0) {
			return ret;
		}

		size -= ret;
	}

	return requested;
}


static ssize_t write(
	struct file *filp,
	const char *usr_ptr,
	size_t size, loff_t *offs
) {
	struct channel *chn;
	struct buffer *buf;
	ssize_t bytes_written;
	ssize_t ret;

	chn = filp->private_data;

	ret = wait_event_interruptible_timeout(
		chn->waitq,
		has_idle_buffer(chn) || has_serviced_buffer(chn),
		500
	);
	if(ret == -ERESTARTSYS) {
		return ret;
	}
	if(ret == 0 || ret == 1) { // Timeout
		return -EAGAIN;
	}


	while(has_serviced_buffer(chn)) {
		buf = remove_serviced_buffer(chn);
		add_idle_buffer(chn, buf);
	}

	bytes_written = 0;
	while(has_idle_buffer(chn) && size) {
		buf = remove_idle_buffer(chn);

		buf->size = buf->init_size < size ? buf->init_size : size;
		ret = copy_from_user(
			buf->ptr,
			usr_ptr + bytes_written,
			buf->size
		);


		ret = map_and_request_buffer(chn, buf);
		if(ret < 0) {
			dev_err(chn->dev, "[write] Failed to dma-map buffer.");
			return ret;
		}
		bytes_written += ret;
		size -= ret;
	}

	return bytes_written;
};


static ssize_t read_serviced_buffers(
	struct channel *chn,
	char *usr_ptr,
	size_t size
) {
	size_t read_size;
	ssize_t ret, bytes_read;
	struct buffer *buf = NULL;
	unsigned long flags;
	u32 bytes_left_in_buffer;

	bytes_read = 0;
	while(has_serviced_buffer(chn) && size) {
		buf = remove_serviced_buffer(chn);
		if(!buf->size) {
			dev_dbg(chn->dev, "Channel %d: Encountered empty buffer %d, skipping", chn->id, buf->id);
			add_idle_buffer(chn, buf);
			continue;
		}

		bytes_left_in_buffer = buf->size - buf->head;
		if (buf->size < buf->head) {
			dev_err(chn->dev,
				"Invalid fill state of buffer %u with head %u and size %u",
				buf->id, buf->head, buf->size);
		}
		read_size = bytes_left_in_buffer < size ?
			bytes_left_in_buffer : size;
		dev_dbg(chn->dev, "Channel %d: Reading %lu bytes from buffer %d", chn->id, read_size, buf->id);

		ret = copy_to_user(
			usr_ptr + bytes_read,
			buf->ptr + buf->head,
			read_size
		);
		if(unlikely(ret)) {
			dev_err(chn->dev,
				"Failed to copy read data to user.");
			return ret;
		}

		buf->head += read_size;
		bytes_read += read_size;
		size -= read_size;

		if(buf->head == buf->size) {
			buf->head = 0;
			buf->size = 0;
			add_idle_buffer(chn, buf);
		} else {
			// This buffer is not done yet, so we stick it
			// right back to the top of the serviced buffers.
			spin_lock_irqsave(&chn->lock, flags);
			list_add(&buf->list, &chn->serviced_buffers);
			chn->num_serviced_buffers += 1;
			spin_unlock_irqrestore(&chn->lock, flags);
		}
	}
	return bytes_read;
}

static ssize_t read(struct file *filp, char *usr_ptr, size_t size, loff_t *offs) {
	struct channel *chn;
	ssize_t bytes_read, ret;

	chn = filp->private_data;

	// Step 1: We won't have anything to read on the first read
	// of every user transaction.
	// Since POSIX defines a read() return value of 0 as EOF,
	// and since we wan't to be a good citizen, we start a new
	// initial hardware request so that even the first read()
	// can return data.
	if(!has_serviced_buffer(chn) && !has_active_buffer(chn)) {
		dev_dbg(chn->dev, "Channel %d: Requesting idle buffers for read.", chn->id);
		ret = request_idle_buffers(chn, size);
		if(ret < 0) {
			dev_err(chn->dev, "Failed to request buffers");
			return ret;
		}
	}

	ret = wait_event_interruptible_timeout(
		chn->waitq,
		has_serviced_buffer(chn),
		1000
	);
	if(ret == -ERESTARTSYS) {
		dev_dbg(chn->dev, "Channel %d: Forced to restart systemcall while waiting for read serviced buffers", chn->id);
		return ret;
	}
	if(ret == 0 || ret == 1) { // Timeout
		dev_dbg(chn->dev, "Channel %d: Timeout while waiting for read serviced buffers", chn->id);
		ret = -EAGAIN;
		return ret;
	}

	bytes_read = 0;

	// Step 2: Read enough data to satisfy the current request.
	ret = read_serviced_buffers(chn, usr_ptr, size);
	if(ret < 0) {
		return ret;
	}

	bytes_read += ret;
	size -= ret;

	// Step 3: If we couldn't deliver enough data to complete
	// the user read transaction, issue a new read request
	// to hardware for the remainder.
	ret = request_idle_buffers(chn, size);
	if(ret < 0) {
		return ret;
	}

	return bytes_read;
}

static unsigned int poll(struct file *filp, poll_table *wait) {
	struct channel *chn;

	chn = filp->private_data;

	poll_wait(filp, &chn->waitq, wait);

	if(has_idle_buffer(chn) || has_serviced_buffer(chn)) {
		if(chn->direction == DMA_TO_DEVICE) {
			return (POLLOUT | POLLWRNORM);
		} else if(chn->direction == DMA_FROM_DEVICE) {
			return (POLLIN | POLLRDNORM);
		} else {
			return 0;
		}
	}

	return 0;
}

static ssize_t id_show(struct device *dev, struct device_attribute *attr, char *buf) {
	struct channel *chn = dev_get_drvdata(dev);
	return snprintf(buf, PAGE_SIZE, "%u\n", (u32)(chn->id));
}
DEVICE_ATTR_RO(id);

static ssize_t dir_show(struct device *dev, struct device_attribute *attr, char *buf) {
	struct channel *chn = dev_get_drvdata(dev);
	if(chn->direction == DMA_TO_DEVICE) {
		return snprintf(buf, PAGE_SIZE, "rx");
	} else if(chn->direction == DMA_FROM_DEVICE) {
		return snprintf(buf, PAGE_SIZE, "tx");
	} else {
		return snprintf(buf, PAGE_SIZE, "none");
	}

}
DEVICE_ATTR_RO(dir);

static ssize_t active_bufs_show(struct device *dev, struct device_attribute *attr, char *buf) {
	struct channel *chn = dev_get_drvdata(dev);
	return snprintf(buf, PAGE_SIZE, "%u\n", (u32)(chn->num_active_buffers));
}
DEVICE_ATTR_RO(active_bufs);

static ssize_t idle_bufs_show(struct device *dev, struct device_attribute *attr, char *buf) {
	struct channel *chn = dev_get_drvdata(dev);
	return snprintf(buf, PAGE_SIZE, "%u\n", (u32)(chn->num_idle_buffers));
}
DEVICE_ATTR_RO(idle_bufs);

static ssize_t serviced_bufs_show(struct device *dev, struct device_attribute *attr, char *buf) {
	struct channel *chn = dev_get_drvdata(dev);
	return snprintf(buf, PAGE_SIZE, "%u\n", (u32)(chn->num_serviced_buffers));
}
DEVICE_ATTR_RO(serviced_bufs);

int chn_devices_init(struct pcie_endpoint *ep) {
	int ret = 0;
	dev_t devt;
	size_t idx;
	struct device *dev;
	char name[32] = {0};

	ret = alloc_chrdev_region(
		&devt, 0, ep->channel_cnt, "vercolib_pcie_dma");
	if(ret) {
		dev_err(ep->dev, "Failed to alloc chrdev region for channels");
		goto done;
	}

	cdev_init(&ep->channel_cdev, &chn_ops);
	ep->channel_cdev.owner = THIS_MODULE;

	ret = cdev_add(&ep->channel_cdev, devt, ep->channel_cnt);
	if(ret) {
		dev_err(ep->dev, "Failed to add cdev for endpoint %u", ep->id);
		goto unregister;
	}

	for(idx = 0; idx < ep->channel_cnt; ++idx) {
		struct channel *chn = ep->channels[idx];
		memset(name, 0, ARRAY_SIZE(name));
		if(chn->direction == DMA_FROM_DEVICE) {
			sprintf(name, "vcl_%u_tx_%d", ep->id, chn->id);
		} else if (chn->direction == DMA_TO_DEVICE) {
			sprintf(name, "vcl_%u_rx_%d", ep->id, chn->id);
		} else {
			sprintf(name, "vcl_%u_misc_%d", ep->id, chn->id);
		}
		dev = device_create(
			vcl_channel_class, ep->dev,
			MKDEV(MAJOR(devt), idx),
			chn, name
		);
		if(IS_ERR(dev)) {
			dev_err(chn->dev, "Failed to create device for channel %u", chn->id);
			ret = PTR_ERR(dev);
			goto destroy;
		}

		ret = device_create_file(dev, &dev_attr_active_bufs);
		if(ret) {
			dev_err(chn->dev, "Failed to create active_bufs attribute for channel device");
			goto destroy;
		}

		ret = device_create_file(dev, &dev_attr_idle_bufs);
		if(ret) {
			dev_err(chn->dev, "Failed to create idle_bufs attribute for channel device");
			goto destroy;
		}

		ret = device_create_file(dev, &dev_attr_serviced_bufs);
		if(ret) {
			dev_err(chn->dev, "Failed to create serived_bufs attribute for channel device");
			goto destroy;
		}

		ret = device_create_file(dev, &dev_attr_id);
		if(ret) {
			dev_err(chn->dev, "Failed to create id attribute for channel device");
			goto destroy;
		}

		ret = device_create_file(dev, &dev_attr_dir);
		if(ret) {
			dev_err(chn->dev, "Failed to create dir attribute for channel device");
			goto destroy;
		}


	}

	goto done;

destroy:
	for(; idx >= 0; --idx) {
		device_destroy(vcl_channel_class, MKDEV(MAJOR(devt), idx));
	}
	cdev_del(&ep->channel_cdev);

unregister:
	unregister_chrdev_region(devt, ep->channel_cnt);
done:
	return ret;
}

void chn_devices_cleanup(struct pcie_endpoint *ep) {
	dev_t devt, ldevt;
	size_t idx;

	devt = ep->channel_cdev.dev;

	for(idx = 0; idx < ep->channel_cnt; ++idx) {
		ldevt = MKDEV(MAJOR(devt), idx);
		device_destroy(vcl_channel_class, ldevt);
	}
	cdev_del(&ep->channel_cdev);
	unregister_chrdev_region(devt, ep->channel_cnt);
}
