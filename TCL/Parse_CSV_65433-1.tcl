set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR            "debug_utils.tcl"]


proc csv2list {str {sepChar ,}} {
  regsub -all {(\A\"|\"\Z)} $str \0 str
  set str [string map [list $sepChar\"\"\" $sepChar\0\" 		\"\"\"$sepChar \"\0$sepChar 		\"\" \" \" \0 ] $str]
  set end 0
  while {[regexp -indices -start $end {(\0)[^\0]*(\0)} $str fullMatch start end]} {
    set start [lindex $start 0]
    set end   [lindex $end 0]
    set range [string range $str $start $end]
    set first [string first $sepChar $range]
    if {$first >= 0} {
	    set str [string replace $str $start $end 		[string map [list $sepChar \1] $range]]
    }
    incr end
  }
  set str [string map [list $sepChar \0 \1 $sepChar \0 {} ] $str] 
  return [split $str \0]
}


proc list2csv {list {sepChar ,}} {
  set out ""
  foreach l $list {
    set sep {}
    foreach val $l {
	    if {[string match "*\[\"$sepChar\]*" $val]} {
        append out $sep\"[string map [list \" \"\"] $val]\"
      } else {
        append out $sep$val
	    }
	    set sep $sepChar
    }
    append out $sepChar
  }
  return $out
}


## Oleg's code


# Stores lists from 'arrName' one-at-a-line in file 'fullPath';
# each list prepended by its key
# Returns 1 on success, 0 on error.
proc ok_write_array_of_lists_into_csv_file {arrName fullPath headerPattern \
                                            {sepChar ,}} {
  upvar $arrName theArr
  set goodCnt 0
  set tclExecResult [catch {
    if { ![string equal $fullPath "stdout"] } {
      set outF [open $fullPath w]
    } else {
      set outF stdout
    }
    # find and print the header
    foreach name [array names theArr] {
      if { 1 == [regexp $headerPattern $name] } {
        puts $outF [format "%s%s%s" \
                            $name $sepChar [list2csv $theArr($name) $sepChar]]
        break
      }
    }
    # print the body (everything other than the header)
    foreach name [lsort [array names theArr]] {
      if { 0 == [regexp $headerPattern $name] } {
        puts $outF [format "%s%s%s" \
                            $name $sepChar [list2csv $theArr($name) $sepChar]]
        incr goodCnt
      }
    }
    if { ![string equal $fullPath "stdout"] } {    close $outF	}
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  ok_info_msg "Wrote $goodCnt record(s) into '$fullPath'"
  return  1
}


# Stores lists from 'topList' one-at-a-line in file 'fullPath'
# Returns 1 on success, 0 on error.
proc ok_write_list_of_lists_into_csv_file {topList fullPath {sepChar ,}} {
  set goodCnt 0
  set tclExecResult [catch {
    if { ![string equal $fullPath "stdout"] } {
      set outF [open $fullPath w]
    } else {
      set outF stdout
    }
    foreach rec $topList {
      puts $outF [list2csv $rec $sepChar]
      incr goodCnt
    }
    if { ![string equal $fullPath "stdout"] } {    close $outF	}
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  ok_info_msg "Wrote $goodCnt record(s) into '$fullPath'"
  return  1
}

# Reads lists from file 'fullPath' into array 'arrName';
# each first list element used as array key.
# If 'LineCheckCB' callback supplied, it's called on each line except the header;
#   if 'LineCheckCB' returns non-empty string, error reported and reading stopped.
# Returns 1 on success, 0 on error.
proc ok_read_csv_file_into_array_of_lists {arrName fullPath sepChar \
                                                              {LineCheckCB 0}} {
  upvar $arrName theArr
  set descr "data-file '$fullPath'"
  set goodCnt 0
  set prevLst {};  # to compare lengths of subsequent lines (after header)
  set tclExecResult [catch {
  set inF [open $fullPath r]
  	while { [gets $inF line] >= 0 } {
      set lst [ok_discard_trailing_empty_list_elements \
                                                    [csv2list $line $sepChar]]
      #~ if { ($prevLst != {}) && ($goodCnt > 1) && \
            #~ ([llength $lst] != [llength $prevLst]) }  {
        #~ ok_err_msg "Line length mismatch in $descr: {$prevLst} vs {$lst}" 
        #~ return  0
      #~ }
      if { ($LineCheckCB != 0) && ($goodCnt >= 1) && \
                                      ("" != [set err [$LineCheckCB $lst]]) }  {
        ok_err_msg "Error in a line of $descr ([lindex $lst 0]): $err"
        return  0
      }
      set prevLst $lst
      set name [lindex $lst 0]
      if { $name == "" }  { continue } ;  # skip empty lines
      set theArr($name) [lrange $lst 1 end]
      incr goodCnt
    }
   close $inF
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  #~ # convert into list-of-lists and check lengths
  #~ set listOfLists {}
  #~ foreach ix [lsort [array names theArr]]   { lappend listOfLists $theArr($ix) }
  #~ if { 0== [ok_check_list_of_lists_lengths $listOfLists "data file '$fullPath'"] } {
    #~ return  0;  # error already printed
  #~ }
  ok_info_msg "Read $goodCnt record(s) from $descr"
  return  1
}


# Reads lists from file 'fullPath' into a list and returns it
# Returns 0 on error.
proc ok_read_csv_file_into_list_of_lists {fullPath sepChar commentStart \
                                                              {LineCheckCB 0}} {
  set descr "data-file '$fullPath'"
  set goodCnt 0
  set fullList [list ]
  set prevLst {};  # to compare lengths of subsequent lines (after header)
  set tclExecResult [catch {
  set inF [open $fullPath r]
  	while { [gets $inF line] >= 0 } {
      if { $commentStart == [string index $line 0] }   { continue }
      set oneLineList [ok_discard_trailing_empty_list_elements \
                                                      [csv2list $line $sepChar]]
      #~ if { ($prevLst != {}) && ($goodCnt > 1) && \
           #~ ([llength $oneLineList] != [llength $prevLst]) }  {
        #~ ok_err_msg "Line length mismatch in $descr: {$prevLst} vs {$oneLineList}" 
        #~ return  0
      #~ }
      if { ($LineCheckCB != 0) && ($goodCnt >= 1) && \
                              ("" != [set err [$LineCheckCB $oneLineList]]) } {
        ok_err_msg "Error in a line of $descr  ([lindex $oneLineList 0]): $err"
        return  0
      }
      set prevLst $oneLineList
      lappend fullList $oneLineList
      incr goodCnt
    }
   close $inF
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  #~ if { 0 == [ok_check_list_of_lists_lengths $fullList "data file '$fullPath'"] } {
    #~ return  0;  # error already printed
  #~ }
  ok_info_msg "Read $goodCnt record(s) from $descr"
  return  $fullList
}


### Empty elements are discarded, thus cannot compare with header
#~ # Returns 1 if lengths of all lists in 'listOfLists' are equal; otherwise - 0
#~ proc ok_check_list_of_lists_lengths {listOfLists descr {priErr 1}}  {
  #~ if { 1 >= [llength $listOfLists] }  { return 1 };  # nothing to check
  #~ set lng [llength [lindex $listOfLists 0]]
  #~ foreach lst [lrange $listOfLists 1 end]  {
    #~ if { [llength $lst] != $lng }  {
      #~ if { $priErr }  {
        #~ ok_err_msg "Line length mismatch in $descr: {[lindex $listOfLists 0]} vs {$lst}" 
      #~ }
      #~ return  0
    #~ }
  #~ }
  #~ return  1
#~ }


proc ok_read_csv_file_keys {fullPath sepChar {commentStart "#"}} {
  return  [ok_read_csv_file_column $fullPath 0 $sepChar $commentStart]
}

proc ok_read_csv_file_column {fullPath iColumn sepChar {commentStart "#"}} {
  set listOfLists [ok_read_csv_file_into_list_of_lists $fullPath \
                                                        $sepChar $commentStart]
  set res [list]
  # comments dropped; do skip header
  for {set i 1} {$i < [llength $listOfLists]} {incr i} {
    set lnL [lindex $listOfLists $i]
    if { $iColumn >= [llength $lnL] } {
      ok_err_msg "Invalid field index $iColumn in '$fullPath'";  return  ""
    }
    lappend res [lindex $lnL $iColumn]
  }
  return  $res
}



# Returns a list that is a copy of 'inpList' but without empty ("") elements
proc ok_discard_empty_list_elements {inpList} {
  set length [llength $inpList]
  set outList [list]
  for {set i 0} {$i < $length} {incr i} {
	set elem [lindex $inpList $i]
	if { $elem != "" } {
	    lappend outList $elem
	}
    }
    return  $outList
}


# Returns a list that is a copy of 'inpList' but without trailing empty ("") elements
proc ok_discard_trailing_empty_list_elements {inpList} {
  set length [llength $inpList]
  set last -1
  for {set i [expr $length-1]} {$i >= 0} {incr i -1} {
    set elem [lindex $inpList $i]
    if { $elem != "" } {
      set last $i;  break
    }
  }
  if { $last == -1 }  { return  [list] }
  return  [lrange $inpList 0 $last]
}


# Sorts records of 'csvPath' by column 'columnIndex'.
# First line is the header.
# Returns resulting list on success, 0 on error.
proc sort_csv_file_by_numeric_column {csvPath columnIndex descr} {
  if { 0 == [file exists $csvPath] } {
    ok_err_msg "Inexistent $descr file '$csvPath'"
    return  0
  }
  set fullList [ok_read_csv_file_into_list_of_lists $csvPath " " "#" 0]
  if { $fullList == 0 } {
    ok_err_msg "Failed reading $descr file '$csvPath'";    return  0
  }
  set sortedList [lsort -real -index $columnIndex [lrange $fullList 1 end]]
  set header [list [lindex $fullList 0]];  # wrapped to prepare for "concat" 
  set sortedListWithHeader [list ]
  set sortedListWithHeader [concat $header $sortedList]
  return  $sortedListWithHeader
}
