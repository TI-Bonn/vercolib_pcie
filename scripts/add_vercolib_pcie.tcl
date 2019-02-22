# Script to add the VerCoLib PCIe source code to the current Vivado project.
# Author: Sebastian Schüller <schueller@ti.uni-bonn.de>

set script_dir [file normalize [file dirname [info script]]]
set project_root [file normalize $script_dir/../]

proc loadFileList {filename} {
  upvar project_root project_root
  set values [list]
  set filehandle [open [file normalize $filename]]
  set lines [split [read $filehandle] \n]
  close $filehandle
  foreach line $lines {
    if {$line != ""} {
      lappend values $project_root/$line
    }
  }
  return $values
}

set srcs [loadFileList $script_dir/source_files]
set ips [loadFileList $script_dir/ip_files]
set constraints [loadFileList $script_dir/constraint_files]

import_ip -quiet $ips
add_files -fileset [current_fileset] -quiet $constraints

puts $srcs
set src_objs [add_files -fileset [current_fileset] $srcs]
foreach obj $src_objs {
  set_property -name "file_type" -value "VHDL 2008" -object $obj
  set_property -name "library" -value "vercolib" -object $obj
}

