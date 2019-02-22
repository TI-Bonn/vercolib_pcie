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


tests = ui.add_library("tests")
tests.add_source_file(join(sim_path, "./tb_tx_stream_timeout.vhd"))


ui.main()
