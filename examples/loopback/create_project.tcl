# Script to create a Vivado Project for the loopback system
# Author: Sebastian Schüller <schueller@ti.uni-bonn.de>
#
# Usage:
#
# To simply create the project in the repository (will be ignored by git)
# # vivado -mode batch -nolog -nojournal -notrace -source create_project.tcl
#
# To create the project in a different location
# # vivado -mode batch -nolog -nojournal -notrace -source ../path/to/repository/create_project.tcl -tclargs --origin_dir ../path/to/repository
#



set target_dir "."
set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize $script_dir/../../]

set part "xc7vx485tffg1761-2"
set board_part "xilinx.com:vc707:part0:1.3"

set projectname loopback
set system_files [list \
  [file normalize $script_dir/hardware/loopback.vhd]
]
set toplevel loopback

set prj [create_project $projectname ./vivado_$projectname -part $part]

set_property "board_part" $board_part $prj
set_property "corecontainer.enable" "1" $prj


# Create default filesets
if {[string equal [get_fileset -quiet sources_1] ""]} { create_fileset -srcset sources_1 }
# if {[string equal [get_fileset -quiet constr] ""]} { create_fileset -constrset constr }

# Create default runs
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part $part -flow {Vivado Synthesis 2018} -strategy "Vivado Synthesis Defaults" -constrset constr
}
current_run -synthesis [get_runs synth_1]

if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part $part -flow {Vivado Implementation 2018} -strategy "Vivado Implementation Defaults" -constrset constr -parent_run synth_1
}
current_run -implementation [get_runs impl_1]


set src_set [get_filesets sources_1]
set system_objs [add_files -norecurse -quiet -fileset $src_set $system_files]
foreach obj $system_objs { set_property -name "file_type" -value "VHDL 2008" -object $obj }

set_property top $toplevel [current_fileset]

source $root_dir/scripts/add_vercolib_pcie.tcl


puts "-----------------------------------------------"
puts "-----------Creating Project Done---------------"
puts "-----------------------------------------------"
