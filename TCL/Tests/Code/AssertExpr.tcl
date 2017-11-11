# AssertExpr.tcl

puts "====== TCL [info script] runs from within '[pwd]' =========="


set g_errCnt 0;   # global error counter

set g_loud   1;   # global "verbose" flag initialized to VERBOSE
if { [file exists "./TCL_set_verbose.tcl"] } {
  source "./TCL_set_verbose.tcl"
}


#################################################################################

# assert procedure
proc AssertExpr {descr theExpr expectResult} {
  global g_errCnt
  global g_loud
  if { $g_loud == 1 } {  puts -nonewline "$descr : " }
  set result [uplevel 1 $theExpr]
  if { $g_loud == 1 } {  puts -nonewline " ($result)\t" }
  set isOK [expr {$result == $expectResult}]
  if {$isOK == 0} {
    if { $g_loud == 0 } {
      # we didn't print it earlier
      puts -nonewline "$descr : ";  puts -nonewline " ($result)\t"
    }
    puts " -- FAILED ($theExpr)-- Expected ($expectResult) --";
    incr g_errCnt;
  }  else {          if { $g_loud == 1 } {  puts " -- PASSED --" }  }
  if { $g_loud == 1 } {  puts "===== Error count so far: $g_errCnt\t=====" }
  return $isOK
}
