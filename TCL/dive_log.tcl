# dive_log.tcl - handling of one dive depth-log data

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "Parse_CSV_65433-1.tcl"]
source [file join $SCRIPT_DIR   "search.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]



# Example: dateStr=="2010-11-07"  timeStr=="21:07:00" ==> returns 1289156820
# Returns -1 on error
proc ParseSubsurfaceDateTime {dateStr timeStr} {
  set tclExecResult [catch {
    set globalTime  [clock scan "$dateStr $timeStr" -format {%Y-%m-%d %H:%M:%S}]
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Invalid date/time string '$dateStr $timeStr': $evalExecResult!"
    return  -1
  }
  return  $globalTime
}


# Example: durationStr=="07:00" ==> returns 420.
# Returns -1 on error
proc ParseSubsurfaceDuration {durationStr} {
  if { 2 != [scan $durationStr "%d:%d" min sec] }  {
    ok_err_msg "ParseSubsurfaceDuration: invalid time string '$durationStr'"
    return -1
   }
  set elapsedTime [expr 60*$min + $sec]
  return  $elapsedTime
}


# Reads record: {"dive number","date","time","duration","depth","temperature","pressure"}
proc ParseDivelogRecord {recAsList dateStr timeStr durationStr depth}  {
  upvar $dateStr dt
  upvar $timeStr tm
  upvar $durationStr dr
  upvar $depth dp
  #ok_trace_msg "[ok_pri_list_as_list $recAsList]"
  # TODO: check record validity
  set dt [lindex $recAsList 1];      set tm [lindex $recAsList 2]
  set dr [lindex $recAsList 3];  # example: "13:20"
  set dp [lindex $recAsList 4]
}


# Checks record: {"dive number","date","time","duration","depth","temperature","pressure"}
proc CheckDivelogRecord {recAsList}  {
  if { 5 > [llength $recAsList] }  {
    return "Dive log record '$recAsList' has [llength $recAsList] field(s), while mininum required is 5"
  }
  ParseDivelogRecord $recAsList dateStr timeStr durationStr depth
  if { -1 == [ParseSubsurfaceDateTime $dateStr $timeStr] }  {
    return "Invalid date/time fields '$dateStr'/'$timeStr'"
  }
  if { -1 == [ParseSubsurfaceDuration "$durationStr"] }  {
    return "Invalid duration field '$durationStr'"
  }
  if { (0 == [string is double -strict $depth]) || ($depth < 0.0) }  {
    return "Invalid depth field '$depth'"
  }
  return  "" ;  # no error found
}


# Builds correlated lists of time and depth samples.
# Expected format:
# "dive number","date","time","duration","depth","temperature","pressure"
# First line is the header - skipped
proc DepthLogRead__SubsurfaceCSV {timeListName depthListName} {
  upvar $timeListName timeList
  upvar $depthListName depthList
  set fullList [ok_read_csv_file_into_list_of_lists [FindSavedLog] ","  "#" \
                                                          "CheckDivelogRecord"]
  if { $fullList == 0 } {
    ok_err_msg "Failed reading depth-log file";    return  0
  }
  set timeList  [list ]
  set depthList [list ]
  for { set i 1 }  { $i < [llength $fullList] }  { incr i }  {
    set sample [lindex $fullList $i]
    ParseDivelogRecord $sample dateStr timeStr durationStr depth
    set startTimeSec [ParseSubsurfaceDateTime $dateStr $timeStr]
    # durationStr example: "13:20"
    set durationSec [ParseSubsurfaceDuration "$durationStr"]
    set timeSec [expr $startTimeSec + $durationSec]
    lappend timeList $timeSec
    lappend depthList $depth
  }
  return  [llength $timeList]
}


proc  DepthLogFindDepthForTime {globalTime \
                                timeList depthList priErr} {
  BisectFindRange $timeList $globalTime posBefore posAfter
  set time1 [lindex $timeList $posBefore]
  set time2 [lindex $timeList $posAfter]
  set depth1 [lindex $depthList $posBefore]
  set depth2 [lindex $depthList $posAfter]
  if { $time1 == $time2 }  {
    set depth $depth1
  } else {  # take weighted average depth
    set offset [expr 1.0* ($globalTime-$time1) / ($time2-$time1)]
    set depth  [expr 1.0* $depth1 + $offset*($depth2-$depth1)]
    set depth [string trim [format "%8.2f" $depth]];  # restrict precision
  }
  # TODO: error condition?
  ok_info_msg "Depth at $globalTime is $depth ($depth1 ... $depth2)"
  return $depth
}


proc ValidateUltimateDepthString {depthStr} {
  return  [ expr {([string is double $depthStr])       && \
                  (-1 == [string first "-" $depthStr]) && \
                  (-1 == [string first "+" $depthStr]) && \
                  ("" != [string trim $depthStr])}        ]
}


# For edit-time validation; have to permit empty field
proc ValidateDepthString {depthStr} {
  return  [ expr { (([string is double $depthStr])       && \
                   (-1 == [string first "-" $depthStr])  && \
                   (-1 == [string first "+" $depthStr])) || \
                   ("" == [string trim $depthStr]) } ]
}

