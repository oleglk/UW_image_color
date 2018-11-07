# RunAll.tcl - runs all tests

# Invocation examples:
##  cd C:/TMP/UWIC/;  source c:/Oleg/Work/UW_image_color/TCL/Tests/Code/RunAll.tcl
##  file mkdir f:/UWIC_TEST;  cd f:/UWIC_TEST;  source c:/Oleg/Work/UW_image_color/TCL/Tests/Code/RunAll.tcl
##  cd D:/ANY/TMP/UWIC/;  source D:/Work/UW_image_color/TCL/Tests/Code/RunAll.tcl


set TESTCODE_DIR [file dirname [file normalize [info script]]]
set TESTS_DIR    [file join $TESTCODE_DIR ".."]
set UWIC_DIR     [file join $TESTCODE_DIR ".." ".."]
set TESTINP_DIR  [file join $TESTCODE_DIR ".." ".." ".." "Test" "Inputs"]

set _WRD [pwd];   # use current directory for work-root

# tell all tests to run in non-verbose mode
set tclExecResult [catch {
    set outF [open [file join $TESTS_DIR "TCL_set_verbose.tcl"] w]
    puts $outF "set g_loud 0"
    close $outF
} execResult]


# do not use 'CONVERTER_NAME_LIST' - to enable subsets
# keep the more available converter the last - for verification
set allConverters [list "RAW-THERAPEE" "PHOTO-NINJA" \
                        "CAPTURE-ONE" "COREL-AFTERSHOT"]
#~ set allConverters [list "RAW-THERAPEE" "PHOTO-NINJA" \
                        #~ "CAPTURE-ONE" "DXO-OPTICS" "COREL-AFTERSHOT"]
##set allConverters [list "RAW-THERAPEE" "PHOTO-NINJA" "COREL-AFTERSHOT"]
#set allConverters [list "COREL-AFTERSHOT"]
################################################################################

#set allTests [list /home/mrv/workspace/op/main/ifcmgr/test/tcl/TCLTest__ifIndex.tcl /home/mrv/workspace/op/main/ifcmgr/test/tcl/TCLTest__Dump_02_no_trunks.tcl]
set allTests [glob [file join $TESTS_DIR "TCLTest_*.tcl"]]
set numTests [llength $allTests]

set allDives [glob [file join $TESTINP_DIR "*_UW"]]
set numDives [llength $allTests]


# build test combinations beforehand to enable filtering some
set testCombos [list] ;   # will be list of {test converter dive} lists
foreach f $allTests {
  foreach conv $allConverters {
    foreach diveDirPath $allDives {
      lappend testCombos [list $f $conv [file tail $diveDirPath]]
    }
  }
}
set numTestCombos [llength $testCombos]

set testCnt 0
set listFailed [list ]
puts "-RunAll-: start running $numTestCombos test combination(s); work-dir: '$_WRD'"
foreach tc $testCombos {
  incr testCnt
  puts "\n\n================================================================="
  puts "-RunAll-: Starting test combination $testCnt of $numTestCombos -\t{$tc}"
  puts "================================================================="
  set testCodeFile  [lindex $tc 0]
  set conv          [lindex $tc 1]
  set diveName      [lindex $tc 2]
  set procName [file rootname [file tail $testCodeFile]]

  # each test expected to return 1 on success, 0 on error
  set tclExecResult [catch {
    file delete -force [file join $_WRD $diveName]
    set child [interp create "interp_$testCnt"]
    interp eval $child [list source $testCodeFile] ;    # load the code
    # by convention test's main proc is named after the test code file
    #(TODO: DOESN'T WORK) interp eval $child [list set procName [file rootname [file tail $testCodeFile]]]
    set tResult [interp eval $child [list $procName $_WRD $TESTINP_DIR $diveName $conv]]
    puts "-RunAll-: Finished test combination $testCnt of $numTestCombos -\t{$tc}; result=$tResult"
    puts "=================================================================\n"
    interp delete $child
  } evalExecResult]
  #puts "@@@ Analyze test results: tclExecResult='$tclExecResult';  evalExecResult='$evalExecResult';  tResult='$tResult'"
  if { $tclExecResult != 0 } {
    puts "-RunAll-: ==============================================="
    puts "-RunAll-: *** Test {$tc} CRASHED:\n-RunAll-: $evalExecResult"
    puts "-RunAll-: ==============================================="
    lappend listFailed $tc
    break;  # OK_TMP; TODO: if continuing, save WA of the failed test
  } elseif { $evalExecResult != "" } {
    puts "-RunAll-: ==============================================="
    puts "-RunAll-: *** Test {$tc} probably FAILED:\t'$evalExecResult'"
    puts "-RunAll-: ==============================================="
    lappend listFailed $tc
  } elseif { $tResult == 0 } {
    puts "-RunAll-: ==============================================="
    puts "-RunAll-: *** Test {$tc} FAILED"
    puts "-RunAll-: ==============================================="
    lappend listFailed $tc
    break;  # OK_TMP; TODO: if continuing, save WA of the failed test
  } else  {
    puts "-RunAll-: ==============================================="
    puts "-RunAll-: +++ Test {$tc} PASSED ($tResult)"
    puts "-RunAll-: ==============================================="
  }
  set DUMP_PATH "NO-DUMP-PATH-GIVEN";  # cleanup
}
puts "\n\n-RunAll-: finished running $testCnt out of $numTestCombos test(s); work-dir: '$_WRD'"
puts "========== Test run order: =========="
for {set i 0} {$i < $testCnt} {incr i 1} {
  puts "== \[[expr $i+1]\]: '[lindex $testCombos $i]'"
}
puts "====================================="


if {[llength $listFailed] > 0} {
  puts "-RunAll-: Failed [llength $listFailed] test(s) out of $testCnt being run ([expr $numTestCombos-$testCnt] not run)"
  foreach t $listFailed {
    puts "*** FAILED test '$t'"
  }
}

