# topological_sort.tcl - from: http://rosettacode.org/wiki/Topological_sort

package require Tcl 8.5

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]


proc topsort {data} {
  # Clean the data
  dict for {node depends} $data {
    if {[set i [lsearch -exact $depends $node]] >= 0} {
      set depends [lreplace $depends $i $i]
      dict set data $node $depends
    }
    foreach node $depends {dict lappend data $node}
  }
  # Do the sort
  set sorted {}
  while 1 {
    # Find available nodes
    set avail [dict keys [dict filter $data value {}]]
    if {![llength $avail]} {
      if {[dict size $data]} {
        ok_info_msg "graph is cyclic, possibly involving nodes \"[dict keys $data]\""
        return  0
      }
      return $sorted
    }
    # Note that the lsort is only necessary for making the results more like other langs
    lappend sorted {*}[lsort $avail]
    # Remove from working copy of graph
    dict for {node depends} $data {
      foreach n $avail {
        if {[set i [lsearch -exact $depends $n]] >= 0} {
            set depends [lreplace $depends $i $i]
            dict set data $node $depends
        }
      }
    }
    foreach node $avail {
      dict unset data $node
    }
  }
}


proc _Test_topsort {}  {
  set inputData {
      des_system_lib	std synopsys std_cell_lib des_system_lib dw02 dw01 ramlib ieee
      dw01		ieee dw01 dware gtech 
      dw02		ieee dw02 dware
      dw03		std synopsys dware dw03 dw02 dw01 ieee gtech
      dw04		dw04 ieee dw01 dware gtech
      dw05		dw05 ieee dware
      dw06		dw06 ieee dware
      dw07		ieee dware
      dware		ieee dware
      gtech		ieee gtech
      ramlib		std ieee
      std_cell_lib	ieee std_cell_lib
      synopsys
  }
  foreach line [split $inputData \n] {
      if {[string trim $line] eq ""} continue
      dict set parsedData [lindex $line 0] [lrange $line 1 end]
  }
  puts [topsort $parsedData]
}
