#!/usr/bin/env python3
from os.path import join, dirname
from vunit import VUnit

ui = VUnit.from_argv()
ui.add_osvvm()
ui.enable_check_preprocessing()
ui.enable_location_preprocessing()
ui.add_verification_components()


sim_path = dirname(__file__)
root_path = join(sim_path, "../../../")

vercolib = ui.add_library("vercolib")

with open(join(root_path, "scripts/source_files")) as f:
    missed_files = []

    for line in f:
        if len(line.strip()) == 0:
            continue
        filename = join(root_path, line.strip())
        try:
            vercolib.add_source_files(filename)
        except ValueError:
            missed_files.append(filename)

            continue

    if missed_files:
        raise ValueError(
            "Not all specified files found. Missing files: {}".format(
                missed_files)
        )


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

tests = ui.add_library("tests")

ui.main()
