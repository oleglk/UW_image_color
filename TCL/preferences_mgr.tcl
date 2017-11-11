# preferences_mgr.tcl

set SCRIPT_DIR [file dirname [info script]]

ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "read_img_metadata.tcl"]
source [file join $SCRIPT_DIR   "Parse_CSV_65433-1.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]
source [file join $SCRIPT_DIR   "raw_converters.tcl"]


################################################################################
proc _SetInitialValues {}  {
  global INITIAL_CONVERTER_NAME WORK_DIR INITIAL_WORK_DIR
  global LOG_VIEWER HELP_VIEWER SHOW_TRACE
  ok_trace_msg "Setting hardcoded functional preferences"
  
  # TODO: so far INITIAL_CONVERTER_NAME should be set in raw_converters.tcl
  ##set INITIAL_CONVERTER_NAME "COREL-AFTERSHOT"
  ##set INITIAL_CONVERTER_NAME "RAW-THERAPEE"
  
  set INITIAL_WORK_DIR [pwd]
  set WORK_DIR $INITIAL_WORK_DIR
  set LOG_VIEWER write
  set HELP_VIEWER write
  set SHOW_TRACE 1
}
################################################################################
_SetInitialValues
################################################################################


###
set KEY_DCRAW "dcraw-path"
set KEY_INITIAL_CONVERTER_NAME "default-raw-converter"
set KEY_INITIAL_WORK_DIR "default-working-directory"
set KEY_LOG_VIEWER "log-viewer-path"
set KEY_HELP_VIEWER "help-viewer-path"
set KEY_HELP_VIEWER "help-viewer-path"
set KEY_LOUD_MODE "trace-loud-mode"

proc PreferencesCollectAndWrite {}  {
  if { 0 == [set prefAsListOfPairs [PreferencesCollect]] }  {
    return  0;  # error already printed
   }
   return  [PreferencesWriteIntoFile $prefAsListOfPairs]
}


# Read preferences from file and installs them.
# If 'oldValsDict' given, fills it with old values
proc PreferencesReadAndApply {{oldValsDict 0}}  {
  upvar $oldValsDict oldVals
  if { 0 == [set prefAsListOfPairs [PreferencesReadFromFile]] }  {
    return  0;  # error already printed
   }
   return  [PreferencesApply $prefAsListOfPairs oldVals]
}


# Saves the obtained list of pairs (no header) in the predefined path.
# Returns 1 on success, 0 on error.
proc PreferencesWriteIntoFile {prefAsListOfPairs}  {
  set pPath [FindPreferencesFile 0]
  if { 0 == [CanWriteFile $pPath] }  {
    ok_err_msg "Cannot write into preferences file <$pPath>"
    return  0
  }
  # prepare wrapped header; "concat" data-list to it 
  set header [list [list "param-name" "param-val"]]
  set prefListWithHeader [concat $header $prefAsListOfPairs]
  return  [ok_write_list_of_lists_into_csv_file $prefListWithHeader \
                                                $pPath ","]
}


proc PreferencesCollect {}  {
  global DCRAW
  global CONVERTER_NAME_LIST INITIAL_CONVERTER_NAME
  global INITIAL_WORK_DIR WORK_DIR
  global LOG_VIEWER HELP_VIEWER SHOW_TRACE LOUD_MODE
  global KEY_DCRAW KEY_INITIAL_CONVERTER_NAME KEY_INITIAL_WORK_DIR
  global KEY_LOG_VIEWER KEY_HELP_VIEWER KEY_LOUD_MODE

  # apply proxy variables - read from GUI
  set LOUD_MODE $SHOW_TRACE
  
  set prefAsListOfPairs [list]
  lappend prefAsListOfPairs [list $KEY_DCRAW \"$DCRAW\"]
  lappend prefAsListOfPairs [list $KEY_INITIAL_CONVERTER_NAME \"$INITIAL_CONVERTER_NAME\"]
  lappend prefAsListOfPairs [list $KEY_INITIAL_WORK_DIR \"$INITIAL_WORK_DIR\"]
  lappend prefAsListOfPairs [list $KEY_LOG_VIEWER \"$LOG_VIEWER\"]
  lappend prefAsListOfPairs [list $KEY_HELP_VIEWER \"$HELP_VIEWER\"]
  lappend prefAsListOfPairs [list $KEY_LOUD_MODE \"$SHOW_TRACE\"]
  return  $prefAsListOfPairs
}


# Reads and returns list of pairs (no header) from the predefined path.
# Returns 0 on error.
proc PreferencesReadFromFile {}  {
  if { 0 == [set pPath [FindPreferencesFile 1]] }  {
    ok_warn_msg "Inexistent preferences file <$pPath>; will use built-in values"
    return  0
  }
  set prefListWithHeader [ok_read_csv_file_into_list_of_lists $pPath "," "#" 0]
  if { $prefListWithHeader == 0 } {
    ok_err_msg "Failed reading preferences from file '$pPath'"
    return  0
  }
  return  [lrange $prefListWithHeader 1 end]
}


# Installs preferred values from the obtained list of pairs (no header).
# Returns 1 on success, 0 on error.
# If 'oldValsDict' given, fills it with old values
proc PreferencesApply {prefListNoHeader {oldValsDict 0}}  {
  global DCRAW
  global CONVERTER_NAME_LIST INITIAL_CONVERTER_NAME
  global INITIAL_WORK_DIR WORK_DIR
  global LOG_VIEWER HELP_VIEWER
  global LOUD_MODE SHOW_TRACE
  global KEY_DCRAW KEY_INITIAL_CONVERTER_NAME KEY_INITIAL_WORK_DIR
  global KEY_LOG_VIEWER KEY_HELP_VIEWER KEY_LOUD_MODE

  if { 0 == [llength $prefListNoHeader] }  {
    ok_err_msg "Got empty list of preferences"
    return 0
  }
  if { 0 == [SafeListOfListsToArray $prefListNoHeader prefArr] }  {
    ok_err_msg "Invalid/corrupted list of preferences: ($prefListNoHeaderS)"
    return 0
  }
  if { $oldValsDict != 0 }  {
    upvar $oldValsDict oldVals;    set oldVals [dict create]
  }
  set errCnt 0
  if { 1 == [SafeCheckNameInArray $KEY_DCRAW prefArr] }  {
    if { $oldValsDict != 0 }  { dict set oldVals $KEY_DCRAW $DCRAW }
    set DCRAW $prefArr($KEY_DCRAW)
  } else {
    ok_err_msg "Missing $KEY_DCRAW in the stored preferences"
    incr errCnt 1
  }
  if { 1 == [SafeCheckNameInArray $KEY_INITIAL_CONVERTER_NAME prefArr] }  {
    if { $oldValsDict != 0 }  { dict set oldVals $KEY_INITIAL_CONVERTER_NAME $INITIAL_CONVERTER_NAME }
    set INITIAL_CONVERTER_NAME $prefArr($KEY_INITIAL_CONVERTER_NAME)
  } else {
    ok_err_msg "Missing $KEY_INITIAL_CONVERTER_NAME in the stored preferences"
    incr errCnt 1
  }
  if { 1 == [SafeCheckNameInArray $KEY_INITIAL_WORK_DIR prefArr] }  {
    if { $oldValsDict != 0 }  { dict set oldVals $KEY_INITIAL_WORK_DIR $INITIAL_WORK_DIR }
    set INITIAL_WORK_DIR $prefArr($KEY_INITIAL_WORK_DIR)
  } else {
    ok_err_msg "Missing $KEY_INITIAL_WORK_DIR in the stored preferences"
    incr errCnt 1
  }
  if { 1 == [SafeCheckNameInArray $KEY_LOG_VIEWER prefArr] }  {
    if { $oldValsDict != 0 }  { dict set oldVals $KEY_LOG_VIEWER $LOG_VIEWER }
    set LOG_VIEWER $prefArr($KEY_LOG_VIEWER)
  } else {
    ok_err_msg "Missing $KEY_LOG_VIEWER in the stored preferences"
    incr errCnt 1
  }
  if { 1 == [SafeCheckNameInArray $KEY_HELP_VIEWER prefArr] }  {
    if { $oldValsDict != 0 }  { dict set oldVals $KEY_HELP_VIEWER $HELP_VIEWER }
    set HELP_VIEWER $prefArr($KEY_HELP_VIEWER)
  } else {
    ok_err_msg "Missing $KEY_HELP_VIEWER in the stored preferences"
    incr errCnt 1
  }
  if { 1 == [SafeCheckNameInArray $KEY_LOUD_MODE prefArr] }  {
    if { $oldValsDict != 0 }  { dict set oldVals $KEY_LOUD_MODE $LOUD_MODE }
    set SHOW_TRACE $prefArr($KEY_LOUD_MODE)
  } else {
    ok_err_msg "Missing $KEY_LOUD_MODE in the stored preferences"
    incr errCnt 1
  }
  
  # apply proxy variables - read from file
  set LOUD_MODE $SHOW_TRACE
  
  return  [expr $errCnt == 0]
}


# Restores preferences to values in 'oldValsDict'
proc PreferencesRollback {oldValsDict}  {
  global DCRAW
  global CONVERTER_NAME_LIST INITIAL_CONVERTER_NAME
  global INITIAL_WORK_DIR WORK_DIR
  global LOG_VIEWER HELP_VIEWER
  global LOUD_MODE SHOW_TRACE
  global KEY_DCRAW KEY_INITIAL_CONVERTER_NAME KEY_INITIAL_WORK_DIR
  global KEY_LOG_VIEWER KEY_HELP_VIEWER KEY_LOUD_MODE
  set allProps {DCRAW INITIAL_CONVERTER_NAME INITIAL_WORK_DIR \
                LOG_VIEWER HELP_VIEWER LOUD_MODE}
  #ok_trace_msg "Going to rollback preferences: {$oldValsDict}"
  foreach propName $allProps {
    set keyVarName "KEY_$propName"
    set key [subst $[subst $keyVarName]]
    if { [dict exists $oldValsDict $key] }  {
      set propVal  [dict get $oldValsDict $key]
      ok_trace_msg "Restoring '$propName' to '$propVal'"
      set $propName $propVal
    }
  }
}
