// Direct MMIO access device to an PCIe endpoint
// Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/version.h>

#include "vercolib_pcie.h"

#include "mmio_ioctl.h"

#define register_offset(id, offs) ((id & 0xFF) << 6) + ((offs & 0xF) << 2)

#if LINUX_VERSION_CODE <= KERNEL_VERSION(5,0,0)
#define VCL_WRITE_ACCESS_OK(Addr, Size) access_ok(VERIFY_WRITE, Addr, Size)
#else
#define VCL_WRITE_ACCESS_OK(Addr, Size) access_ok(Addr, Size)
#endif


static int mmio_open(struct inode *, struct file *);
static int mmio_release(struct inode *, struct file *);

static long ioctl(struct file *, unsigned int, unsigned long);

static struct file_operations mmio_ops = {
	.owner = THIS_MODULE,
	.open = mmio_open,
	.release = mmio_release,
	.llseek = no_llseek,
	.unlocked_ioctl = ioctl,
};


int mmio_device_init(struct pcie_endpoint *ep) {
	int ret = 0;
	dev_t devt;
	char name[32] = {0};
	struct device *dev;

	ret = alloc_chrdev_region(&devt, 0, 1, driver_name);
	if(ret < 0) {
		dev_err(ep->dev, "Failed to allocate mmio chrdev region.");
		goto done;
	}

	cdev_init(&ep->mmio_cdev, &mmio_ops);
	ep->mmio_cdev.owner = THIS_MODULE;
	atomic_set(&ep->mmio_open_count, 0);

	ret = cdev_add(&ep->mmio_cdev, devt, 1);
	if(ret) {
		goto unregister;
	}

	sprintf(name, "vcl_%d", ep->id);
	dev = device_create(vcl_endpoint_class, ep->dev, devt, NULL, name);
	if(IS_ERR(dev)) {
		ret = PTR_ERR(dev);
		goto del;
	}

	goto done;

del:
	cdev_del(&ep->mmio_cdev);
unregister:
	unregister_chrdev_region(devt, 1);
done:
	return ret;
}

void mmio_device_cleanup(struct pcie_endpoint *ep) {
	dev_t devt = ep->mmio_cdev.dev;

	device_destroy(vcl_endpoint_class, devt);
	cdev_del(&ep->mmio_cdev);
	unregister_chrdev_region(devt, 1);
}

static int mmio_open(struct inode *inode, struct file *filp) {
	struct pcie_endpoint *ep;
	ep = container_of(inode->i_cdev, struct pcie_endpoint, mmio_cdev);

	if(atomic_read(&ep->mmio_open_count)) {
		return -EBUSY;
	}

	atomic_inc(&ep->mmio_open_count);

	filp->private_data = ep;

	return nonseekable_open(inode, filp);
}

static int mmio_release(struct inode *inode, struct file *fil) {
	struct pcie_endpoint *ep;
	ep = container_of(inode->i_cdev, struct pcie_endpoint, mmio_cdev);
	atomic_dec(&ep->mmio_open_count);
	return 0;
};

static long ioctl(struct file *filp, unsigned int cmd, unsigned long params) {
	long ret = 0;
	struct pcie_endpoint *ep = filp->private_data;
	struct vcl_register reg;
	struct pair_info loc;

	switch(cmd) {
	case VCL_MMIO_IOCTL_GETBAR:
		if(!VCL_WRITE_ACCESS_OK((unsigned long long __user *)params, sizeof(ep->bar))) {
			dev_err(ep->dev, "User ptr for reading bar is invalid.");
			return -EFAULT;
		}

		if(put_user(ep->bar, (unsigned long long __user *)params)) {
			dev_err(ep->dev, "Failed to copy bar to user.");
			return -EFAULT;
		}

		break;
	case VCL_MMIO_IOCTL_PAIR_TX:
		if(copy_from_user(&loc, (struct pair_info __user *)params, sizeof(loc))) {
			dev_err(ep->dev, "Failed to copy tx location data from user.");
			return -EFAULT;
		}

		iowrite32((u32)(loc.other_bar + register_offset(loc.other_id, CHN_DATA_REG)),
			ep->base_addr + register_offset(loc.this_id, CHN_ADDR_LO_REG));
		iowrite32((u32)1, ep->base_addr + register_offset(loc.this_id, CHN_MODE_REG));


		break;

	case VCL_MMIO_IOCTL_PAIR_RX:
		if(copy_from_user(&loc, (struct pair_info __user *)params, sizeof(loc))) {
			dev_err(ep->dev, "Failed to copy rx location data from user.");
			return -EFAULT;
		}

		iowrite32((u32)(loc.other_bar + register_offset(loc.other_id, CHN_SIZE_REG)),
			ep->base_addr + register_offset(loc.this_id, CHN_ADDR_LO_REG));
		iowrite32((u32)1, ep->base_addr + register_offset(loc.this_id, CHN_MODE_REG));

		break;
	case VCL_MMIO_IOCTL_RDREG:
		if(copy_from_user(&reg, (struct vcl_register __user *)params, sizeof(reg))) {
			dev_err(ep->dev, "Failed to copy register data from user.");
			return -EFAULT;
		}

		reg.value = ioread32(ep->base_addr + register_offset(reg.chn_id, reg.offset));

		if(copy_to_user((struct vcl_register __user *)params, &reg, sizeof(reg))) {
			dev_err(ep->dev, "Failed to copy register data from user.");
			return -EFAULT;
		}

		break;
	case VCL_MMIO_IOCTL_WRREG:
		if(copy_from_user(&reg, (struct vcl_register __user *)params, sizeof(reg))) {
			dev_err(ep->dev, "Failed to copy register data from user.");
			return -EFAULT;
		}

		iowrite32(reg.value,
			ep->base_addr + register_offset(reg.chn_id, reg.offset)
		);

		break;
	default:
		ret =  -ENOTTY;
	}

	return ret;
}


