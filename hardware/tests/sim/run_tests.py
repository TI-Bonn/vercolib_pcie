#!/usr/bin/env python3
from os.path import join, dirname
from os import environ
from vunit import VUnit

ui = VUnit.from_argv()
ui.add_osvvm()
ui.enable_check_preprocessing()
ui.enable_location_preprocessing()
ui.add_verification_components()


sim_path = dirname(__file__)
root_path = join(sim_path, "../../../")

vercolib = ui.add_library("vercolib")
vcl_sources = [
    "./hardware/src/common/host_types.vhd",
    "./hardware/src/common/tlp_types.vhd",
    "./hardware/src/common/transceiver_128bit_types.vhd",
    "./hardware/src/common/utils.vhd",
    "./hardware/src/common/channel_types.vhd",
    "./hardware/src/endpoint/config_channel/cfg_channel_completer.vhd",
    "./hardware/src/endpoint/config_channel/cfg_channel_controller.vhd",
    "./hardware/src/endpoint/config_channel/cfg_channel_decoder.vhd",
    "./hardware/src/endpoint/config_channel/cfg_channel_memory.vhd",
    "./hardware/src/endpoint/config_channel/cfg_channel_types.vhd",
    "./hardware/src/endpoint/config_channel/config_channel.vhd",
    "./hardware/src/endpoint/endpoint_core.vhd",
    "./hardware/src/endpoint/msix_table.vhd",
    "./hardware/src/endpoint/packet_arbiter.vhd",
    "./hardware/src/endpoint/rx_axi_converter.vhd",
    "./hardware/src/endpoint/rx_bar_demux.vhd",
    "./hardware/src/endpoint/rx_cpld_preprocessor.vhd",
    "./hardware/src/endpoint/tlp_tag_mapper/rx_tag_restorer.vhd",
    "./hardware/src/endpoint/tlp_tag_mapper/tlp_tag_mapper.vhd",
    "./hardware/src/endpoint/tlp_tag_mapper/tlp_tag_memory.vhd",
    "./hardware/src/endpoint/tlp_tag_mapper/tx_tag_replacer.vhd",
    "./hardware/src/endpoint/tlp_tag_mapper/virtual_tag_memory.vhd",
    "./hardware/src/endpoint/tx_axi_converter.vhd",
    "./hardware/src/endpoint/tx_interrupt_mux.vhd",
    "./hardware/src/endpoint/tx_tlp_mux.vhd",
    "./hardware/src/fpga_channel/filter.vhd",
    "./hardware/src/fpga_channel/fpga_rx_channel.vhd",
    "./hardware/src/fpga_channel/fpga_tx_channel.vhd",
    "./hardware/src/fpga_channel/rx_cfg_ctrl.vhd",
    "./hardware/src/fpga_channel/rx_fifo.vhd",
    "./hardware/src/fpga_channel/rx_fifo_internal.vhd",
    "./hardware/src/fpga_channel/rx_filter.vhd",
    "./hardware/src/fpga_channel/rx_output_count.vhd",
    "./hardware/src/fpga_channel/rx_repack.vhd",
    "./hardware/src/fpga_channel/rx_write_request.vhd",
    "./hardware/src/fpga_channel/tx_cfg_ctrl.vhd",
    "./hardware/src/fpga_channel/tx_cfg_ctrl_types.vhd",
    "./hardware/src/fpga_channel/tx_controller.vhd",
    "./hardware/src/fpga_channel/tx_fifo.vhd",
    "./hardware/src/fpga_channel/tx_fifo_internal.vhd",
    "./hardware/src/fpga_channel/tx_fifo_types.vhd",
    "./hardware/src/fpga_channel/tx_pack_data.vhd",
    "./hardware/src/fpga_channel/tx_write_cpld.vhd",
    "./hardware/src/host_channel/channel_DNCtoDVC.vhd",
    "./hardware/src/host_channel/channel_DVCtoDNC.vhd",
    "./hardware/src/host_channel/dma_decoder.vhd",
    "./hardware/src/host_channel/dma_decoder_filter.vhd",
    "./hardware/src/host_channel/dma_decoder_instructor.vhd",
    "./hardware/src/host_channel/dma_interrupt_handler.vhd",
    "./hardware/src/host_channel/dma_requester.vhd",
    "./hardware/src/host_channel/dma_writer_packer.vhd",
    "./hardware/src/host_channel/host_channel_types.vhd",
    "./hardware/src/host_channel/host_rx_channel.vhd",
    "./hardware/src/host_channel/host_tx_channel.vhd",
    "./hardware/src/host_channel/input_ctrl.vhd",
    "./hardware/src/host_channel/output_buf.vhd",
    "./hardware/src/host_channel/output_ctrl.vhd",
    "./hardware/src/host_channel/pipe_reg.vhd",
    "./hardware/src/host_channel/pipe_register.vhd",
    "./hardware/src/host_channel/rx_dma_buffer.vhd",
    "./hardware/src/host_channel/rx_dma_interrupt_handler.vhd",
    "./hardware/src/host_channel/rx_dma_interrupt_handler_filter.vhd",
    "./hardware/src/host_channel/rx_dma_writer.vhd",
    "./hardware/src/host_channel/rx_dma_writer_arbiter.vhd",
    "./hardware/src/host_channel/tx_dma_fifo.vhd",
    "./hardware/src/host_channel/tx_dma_interrupt_handler.vhd",
    "./hardware/src/host_channel/tx_dma_interrupt_handler_filter.vhd",
    "./hardware/src/host_channel/tx_dma_writer.vhd",
    "./hardware/src/host_channel/tx_dma_writer_buffer.vhd",
    "./hardware/src/host_channel/tx_mwr32_shifter_128.vhd",
    "./hardware/src/utilities/tx_timeout.vhd",
    "./hardware/src/pcie_utilities.vhd",
    "./hardware/src/pcie.vhd",
]
vcl_sources = [join(root_path, src) for src in vcl_sources]

sim_sources = [
    "./tb_types.vhd",
    "./fpga_channel/tb_pcie_fifo_128.vhd",
    "./fpga_channel/tb_receiver_filter.vhd",
    "./fpga_channel/tb_receiver_repack.vhd",
    "./fpga_channel/tb_receiver.vhd",
    "./fpga_channel/tb_sender_cfg_ctrl.vhd",
    "./fpga_channel/tb_sender.vhd",
    "./fpga_channel/tb_sender_write_cpld.vhd",
    "./fpga_channel/tb_sender_write_data.vhd",
    "./utilities/tb_tx_stream_timeout.vhd",
]

sim_sources = [join(sim_path, src) for src in sim_sources]

vercolib.add_source_files(sim_sources)
vercolib.add_source_files(vcl_sources)

tests = ui.add_library("tests")

# Look for pre-compiled vendor libraries

ghdl_vivado_path = environ.get('GHDL_VIVADO_LIBRARIES')

if ghdl_vivado_path:
    ui.set_compile_option('ghdl.flags', ['-P{}'.format(ghdl_vivado_path)])
    ui.set_sim_option('ghdl.elab_flags', ['-P{}'.format(ghdl_vivado_path)])

ui.main()
