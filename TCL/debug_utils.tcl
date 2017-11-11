 # debug_utils.tcl

# Copyright - Oleg Kosyakovsky

# this file is reread from multiple files; don't override LOUD_MODE
if { 0 == [info exists LOUD_MODE] }  {  set LOUD_MODE 1 }


set DIAGNOSTICS_FILE_HANDLE 0 ;  # =0 means not yet open
set DIAGNOSTICS_FILE_PATH  ""

proc ok_set_loud {toPriTraceMsgs} {
    global LOUD_MODE
    set LOUD_MODE [expr ($toPriTraceMsgs == 0)? 0 : 1]
}

proc ok_arr_to_string {theArr} {
    upvar $theArr arrName
    set arrStr ""
    foreach {name value} [array get arrName] {
	append arrStr " $theArr\[\"$name\"\]=\"$value\""
    }
    return  $arrStr
}

proc pri_arr {theArr} {
    upvar $theArr arrName
    foreach {name value} [array get arrName] {
	puts "$theArr\[\"$name\"\] = \"$value\""
    }
}

proc ok_pri_list_as_list {theList} {
    set length [llength $theList]
    for {set i 0} {$i < $length} {incr i} {
	set elem [lindex $theList $i]
	puts -nonewline " ELEM\[$i\]='$elem'"
    }
    puts ""
}

###############################################################################
########## Messages/Errors/Warning ################################
set _CNT_ERR_WARN  0;  # counter of problems
set _MSG_CALLBACK  0;  # for  proc _cb {msg} {}

proc ok_msg_set_callback {cb}  {
  global _MSG_CALLBACK
  set _MSG_CALLBACK $cb
}


proc ok_msg {text kind} {
  global LOUD_MODE _CNT_ERR_WARN _MSG_CALLBACK
  set pref ""
  set tags ""
  switch [string toupper $kind] {
    "INFO" { set pref "-I-" }
    "TRACE" {
        set pref [expr {($LOUD_MODE == 1)? "\# [msg_caller_name]:" : "\#"}]
    }
    "ERROR" {
        #set pref [expr {($LOUD_MODE == 1)? "-E- [msg_caller_name]:":"-E-"}]
        set pref "-E-"
        #set tags "boldline"
        set tags "underline"
        incr _CNT_ERR_WARN 1
    }
    "WARNING" {
        set pref [expr {($LOUD_MODE == 1)? "-W- [msg_caller_name]:":"-W-"}]
        set pref "-W-"
        #set tags "italicline boldline"
        set tags "underline"
        incr _CNT_ERR_WARN 1
    }
  }
  puts "$pref $text"
  _ok_write_diagnostics "$pref $text"
  if { $_MSG_CALLBACK != 0 }  {
    set tclResult [catch { set res [$_MSG_CALLBACK "$pref $text" "$tags"] } \
                          execResult]
    if { $tclResult != 0 } {
      puts "$pref Failed message callback: $execResult!"; #DO NOT USE ok_err_msg
    }
  }
}

proc ok_info_msg {text} {
    ok_msg $text "INFO"
}
proc ok_trace_msg {text} {
    global LOUD_MODE
    if { $LOUD_MODE == 1 } {
	ok_msg $text "TRACE"
    }
}
proc ok_err_msg {text} {
    ok_msg $text "ERROR"
}
proc ok_warn_msg {text} {
    ok_msg $text "WARNING"
}

proc ok_msg_get_errwarn_cnt {}  {
  global _CNT_ERR_WARN
  return  $_CNT_ERR_WARN
}

proc msg_caller_name {} {
  #puts "level=[info level]"
  set callerLevel [expr { ([info level] > 3)? -3 : [expr -1*([info level]-1)] }]
    set callerAndArgs [info level $callerLevel]
    return  [lindex $callerAndArgs 0]
}

###################### Current- and caller procedure names #####################
proc ok_procname {} {
  set level [expr [info level] - 1]
  return [lindex [info level $level] 0]
}


proc ok_callername {} {
  set level [expr [info leve] - 2]
  if { $level > 0 } {
      return [lindex [info level $level ] 0]
  } else {
      if { [string length [info script] ] > 0 } {
          return [info script]
      } else {
          return [info nameofexecutable]
      }
  }
}


###############################################################################
########## Assertions ################################

proc ok_assert {condExpr {msgText ""}} {
#    ok_trace_msg "ok_assert '$condExpr'"
    if { ![uplevel expr $condExpr] } {
# 	set theMsg [expr ($msgText == "")? "condExpr" : $msgText]
 	set theMsg $msgText
 	ok_err_msg "Assertion failed: '$theMsg' at [info level -1]"
	for {set theLevel [info level]} {$theLevel >= 0} {incr theLevel -1} {
	     ok_err_msg "Stack $theLevel:\t[info level $theLevel]"
	}
	return -code error
    }
}


proc ok_finalize_diagnostics {}  {
  global DIAGNOSTICS_FILE_HANDLE DIAGNOSTICS_FILE_PATH
  if { $DIAGNOSTICS_FILE_HANDLE != 0 }  {
    ok_info_msg "Closing old diagnostics file '$DIAGNOSTICS_FILE_PATH'"
    catch { close $DIAGNOSTICS_FILE_HANDLE;  set DIAGNOSTICS_FILE_HANDLE 0 }
  }
}

proc ok_init_diagnostics {outFilePath}  {
  global DIAGNOSTICS_FILE_PATH
##   if { $outFilePath != $DIAGNOSTICS_FILE_PATH }  {
 #     ok_finalize_diagnostics;  # if old file was open, close it
 #   }
 ##
  set DIAGNOSTICS_FILE_PATH $outFilePath
  # file will be opened at 1st write
  _ok_write_diagnostics "Diagnostics log file set to '$DIAGNOSTICS_FILE_PATH'"
}


################################################################################
# Internal utilities
################################################################################
proc _ok_write_diagnostics {msg}  {
  global DIAGNOSTICS_FILE_HANDLE
  set dPath [_ok_find_diagnostics_file]
  if { $dPath == "" }  { return  0 };  # not ready yet
  if { $DIAGNOSTICS_FILE_HANDLE == 0 }  {;  # first attempt to write; avoid recursion
    if { 1 == [file exists $dPath] }  { catch { file delete $dPath } }
    set tclExecResult [ catch { set DIAGNOSTICS_FILE_HANDLE [open $dPath a+] } ]
    if { $tclExecResult != 0 }  {
      return  0;  # there will be no log; anyway cannot complain
    }
  }
  set tclExecResult [ catch { puts $DIAGNOSTICS_FILE_HANDLE $msg } ]
  if { $tclExecResult != 0 }  {
    return  0;  # there will be no log; anyway cannot complain
  }
  return  1
}


proc _ok_find_diagnostics_file {}  {
  global DIAGNOSTICS_FILE_PATH
  if { $DIAGNOSTICS_FILE_PATH == "" }  {
    return  "";  # not ready yet
  }
  return $DIAGNOSTICS_FILE_PATH
}