// Kernel driver module to communicate with the VerCoLib-PCIe transceiver
// Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>

#include "vercolib_pcie.h"

#define int_cnt(info) ((info & 0xFF) + ((info >> 8) & 0xFF) + 1)

MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("Char driver for VerCoLib-PCIe");
MODULE_AUTHOR("Sebastian Schüller, University of Bonn, Technische Informatik");
MODULE_VERSION("0.1");

const char driver_name[] = "vercolib_pcie";
struct class *vcl_channel_class = NULL;
struct class *vcl_endpoint_class = NULL;

static atomic_t ep_id = ATOMIC_INIT(0);

static const struct pci_device_id pcie_ids[] = {
	{PCI_DEVICE(PCI_VENDOR_ID_XILINX, 0x0007)},
	{PCI_DEVICE(PCI_VENDOR_ID_XILINX, 0x7028)},
	{ /* All zeroes */ }
};
MODULE_DEVICE_TABLE(pci, pcie_ids);


enum endoint_register_offsets {
	ENDPOINT_ID_REG = 0x20,
	CHANNEL_INFO_REG = 0x28,
};

static int pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	int ret, irq;
	u32 nvec;
	size_t idx;
	struct pcie_endpoint *ep;

	ret = pcim_enable_device(pdev);
	if(ret != 0) {
		dev_err(&pdev->dev, "Failed to enable driver");
		return ret;
	}

	if(!(pci_resource_flags(pdev, 0) & IORESOURCE_MEM)) {
		dev_err(&pdev->dev, "Bar 0 not configured");
		return -ENODEV;
	}

	if(dma_set_mask(&pdev->dev, DMA_BIT_MASK(64))) {
		dev_err(&pdev->dev, "Failed to enable 64bit DMA Addresses.");
		return -ENODEV;
	}

	ret = pcim_iomap_regions(pdev, 0x01, driver_name);
	if(ret < 0) {
		dev_err(&pdev->dev, "Failed to map bar register 0.");
		return ret;
	}


	ep = devm_kzalloc(&pdev->dev, sizeof(*ep), GFP_KERNEL);
	if(!ep) {
		dev_err(&pdev->dev, "Failed to allocate endpoint.");
		return -ENOMEM;
	}

	ep->dev = &pdev->dev;
	ep->base_addr = pcim_iomap_table(pdev)[0];
	ep->bar = pci_resource_start(pdev, 0);
	ep->id = atomic_read(&ep_id); //ioread32(ep->bar + ENDPOINT_ID_REG);
	atomic_inc(&ep_id);
	ep->channel_info = ioread32(ep->base_addr + CHANNEL_INFO_REG);

	if(ep->channel_info == 0xFFFFFFFF) {
		dev_err(&pdev->dev, "Failed to read from FPGA.");
		return -ENODEV;
	}

	nvec = int_cnt(ep->channel_info);

	nvec = pci_alloc_irq_vectors(
		pdev, nvec, nvec, PCI_IRQ_MSI | PCI_IRQ_MSIX
	);
	if(nvec < 0) {
		dev_err(&pdev->dev, "Failed to allocate interrupts.");
		return nvec;
	}


	ret = mmio_device_init(ep);
	if(ret) {
		dev_err(&pdev->dev, "Failed to create mmio character device.");
		return ret;
	}

	ret = channels_init(ep);
	if(ret) {
		dev_err(&pdev->dev, "Failed to initialise channels.");
		return ret;
	}

	for(idx = 0; idx < ep->channel_cnt; ++idx) {
		irq = pci_irq_vector(pdev, ep->channels[idx]->id);

		ret = devm_request_irq(
			&pdev->dev,
			irq,
			host_channel_isr,
			0,
			driver_name,
			ep->channels[idx]
		);
		if(ret) {
			dev_err(&pdev->dev, "Failed to get irq.");
			return ret;
		}
	}

	ret = chn_devices_init(ep);
	if(ret) {
		dev_err(&pdev->dev, "Failed to initialise channel devices.");
		return ret;
	}

	pci_set_drvdata(pdev, ep);


	pci_set_master(pdev);

	dev_info(&pdev->dev, "Initialised endpoint %u with %lu channel(s).", ep->id, ep->channel_cnt);

	return 0;
}

static void pcie_remove(struct pci_dev *pdev)
{
	struct pcie_endpoint *ep;
	ep = pci_get_drvdata(pdev);

	chn_devices_cleanup(ep);
	mmio_device_cleanup(ep);
}

static struct pci_driver pcie_driver = {
	.name = driver_name,
	.id_table = pcie_ids,
	.probe = pcie_probe,
	.remove = pcie_remove
};


static int __init vercolib_pcie_init(void)
{
	int err = 0;

	vcl_channel_class = class_create(THIS_MODULE, "vcl_channel");
	if(IS_ERR(vcl_channel_class)) {
		err = PTR_ERR(vcl_channel_class);
		return err;
	}

	vcl_endpoint_class = class_create(THIS_MODULE, "vcl_endpoint");
	if(IS_ERR(vcl_endpoint_class)) {
		class_destroy(vcl_channel_class);
		err = PTR_ERR(vcl_endpoint_class);
		return err;
	}

	err = pci_register_driver(&pcie_driver);
	if(err < 0) {
		class_destroy(vcl_channel_class);
		class_destroy(vcl_endpoint_class);
		return err;
	}
	return 0;
}

static void __exit vercolib_pcie_exit(void)
{
	pci_unregister_driver(&pcie_driver);
	class_destroy(vcl_channel_class);
	class_destroy(vcl_endpoint_class);
}

module_init(vercolib_pcie_init);
module_exit(vercolib_pcie_exit);
