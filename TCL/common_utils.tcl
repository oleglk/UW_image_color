# common_utils.tcl


proc GetDepthResolution {}  { return  0.5 };  # min depth difference in meters

# Reads record: {pure-name depth time wbParam1 wbParam2 [wbParam3_OR_-1]}
proc ParseDepthColorRecord {recAsList pureName time depth \
                            wbParam1 wbParam2 wbParam3}  {
  upvar $pureName   nm
  upvar $depth      dp
  upvar $time       tm
  upvar $wbParam1  wb1
  upvar $wbParam2  wb2
  upvar $wbParam3  wb3
  if { 5 > [llength $recAsList] }  {
    return  0
  }
  set nm    [lindex $recAsList 0]
  set tm    [lindex $recAsList 1]
  set dp    [lindex $recAsList 2]
  set wb1  [lindex $recAsList 3]
  set wb2   [lindex $recAsList 4]
  set wb3   [expr {([llength $recAsList] > 5)? [lindex $recAsList 5] : -1}]
  return  1
}


# Checks record: {pure-name depth time wbParam1 wbParam2 [wbParam3_OR_-1]}
proc CheckDepthColorRecord {recAsList}  {
  ParseDepthColorRecord $recAsList pureName time depth wbParam1 wbParam2 wbParam3
  if { 0 == [string is integer -strict $time] }  {
    return "Invalid global-time field '$time'"
  }
  if { (0 == [string is double -strict $depth]) || ($depth < 0.0) }  {
    return "Invalid depth field '$depth'"
  }
  # TODO: so far checking WB-parameters as double, but need to vary per converter
  if { 0 == [string is double -strict $wbParam1] }  {
    return "Invalid WB-parameter-1 field '$wbParam1'"
  }
  if { 0 == [string is double -strict $wbParam2] }  {
    return "Invalid WB-parameter-2 field '$wbParam2'"
  }
  if { 0 == [string is double         $wbParam3] }  { ;  # no "-strict"!
    return "Invalid WB-parameter-3 field '$wbParam3'"
  }
  return  "" ;  # no error found
}

# 
proc PackDepthColorRecord {pureName time depth wbParam1 wbParam2 wbParam3}  {
  return  [list $pureName $time [format "%2.2f" $depth] \
                                    $wbParam1 $wbParam2 $wbParam3]
}


# Reads record: {pure-name depth time multR multG multB}
proc ParseDepthColorRecord_Mults {recAsList \
                                    pureName time depth multR multG multB}  {
  upvar $pureName   nm
  upvar $depth      dp
  upvar $time       tm
  upvar $multR      mr
  upvar $multG      mg
  upvar $multB      mb
  return  [ParseDepthColorRecord $recAsList nm tm dp mr mg mb]
}



# Reads record: {time depth wbParam1 wbParam2 [wbParam3_OR_-1]}
proc ParseDepthColorNoNameRecord {recAsList time depth \
                                  wbParam1 wbParam2 wbParam3}  {
  upvar $time       tm
  upvar $depth      dp
  upvar $wbParam1  wb1
  upvar $wbParam2  wb2
  upvar $wbParam3  wb3
  set tm    [lindex $recAsList 0]
  set dp    [lindex $recAsList 1]
  set wb1  [lindex $recAsList 2]
  set wb2   [lindex $recAsList 3]
  set wb3   [expr {([llength $recAsList] > 4)? [lindex $recAsList 4] : -1}]
  return
}


# Checks record: {time depth wbParam1 wbParam2 [wbParam3_OR_-1]}
# Not sure it's needed - such records aren't stored in data-files
proc CheckDepthColorNoNameRecord {recAsList}  {
  ParseDepthColorNoNameRecord $recAsList time depth wbParam1 wbParam2 wbParam3
  if { 0 == [string is integer -strict $time] }  {
    return "Invalid global-time field '$time'"
  }
  if { (0 == [string is double -strict $depth]) || ($depth < 0.0) }  {
    return "Invalid depth field '$depth'"
  }
  # TODO: so far checking WB-parameters as double, but need to vary per converter
  if { 0 == [string is double -strict $wbParam1] }  {
    return "Invalid WB-parameter-1 field '$wbParam1'"
  }
  if { 0 == [string is double -strict $wbParam2] }  {
    return "Invalid WB-parameter-2 field '$wbParam2'"
  }
  if { 0 == [string is double         $wbParam3] }  { ;  # no "-strict"!
    return "Invalid WB-parameter-3 field '$wbParam3'"
  }
  return  "" ;  # no error found
}


# Reads record: {time depth multR multG multB}
proc ParseDepthColorNoNameRecord_Mults {recAsList \
                                        time depth multR multG multB}  {
  upvar $depth      dp
  upvar $time       tm
  upvar $multR      mr
  upvar $multG      mg
  upvar $multB      mb
  return  [ParseDepthColorNoNameRecord $recAsList tm dp mr mg mb]
}


# 
proc PackDepthColorNoNameRecord {time depth wb1 wb2 wb3}  {
  return  [list $time [format "%2.2f" $depth] $wb1 $wb2 $wb3]
}



# Inserts mapping-pairs from list 'srcList' into array 'dstArrName'.
# Returns 1 on success, 0 on failure.
proc SafeListToArray {srcList dstArrName} {
  upvar $dstArrName dstArr
  set tclExecResult [catch {
    array set dstArr $srcList } evalExecResult]
    if { $tclExecResult != 0 } {
    ok_err_msg "$evalExecResult!"
    return  0
  }
  return  1
}


# Inserts mapping-pairs from nested list-of-pairs 'srcList' into array 'dstArrName'.
# Returns 1 on success, 0 on failure.
proc SafeListOfListsToArray {srcList dstArrName} {
  upvar $dstArrName dstArr
  array unset dstArr
  set errCnt 0
  foreach pair $srcList {
    if { 2 != [llength $pair] }   {
      incr errCnt 1;  continue
    }
    set dstArr([lindex $pair 0])  [lindex $pair 1]
  }
  return  [expr $errCnt == 0]
}


# Checks whether 'name' appears in 'arrayName'
proc SafeCheckNameInArray {name arrayName} {
  upvar $arrayName theArray
  set result [expr {[llength [array names theArray -exact $name]] >= 1} ]
  # puts "ok_name_in_array -> $result"
  return  $result
}
