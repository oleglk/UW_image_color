# toplevel_utils.tcl - manipulates both images'metadata and dive-log data

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR            "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "read_img_metadata.tcl"]
source [file join $SCRIPT_DIR   "dive_log.tcl"]
source [file join $SCRIPT_DIR   "Parse_CSV_65433-1.tcl"]

set CONVERT  [file nativename "C:/Program Files/ImageMagick-6.8.6-8/convert.exe"]


set DEPTH_OVERRIDE_HEADER   [list "global-time" "min-depth" "max-depth" "estimated-depth" "depth"]
set iiDepthOvrdGlobalTime 0
set iiDepthOvrdDepth      4


proc FindDepthOvrdData {{dir ""}} { ; #   TODO: accept optional dir param
  global DATA_DIR DEPTH_OVERRIDE_FILE
  if { $dir != "" }  {
    set path [file join $dir $DEPTH_OVERRIDE_FILE]
    if { 0 == [file exists $path] } {
      ok_warn_msg "No depth-override data found in '$path' (provided directory)"
      return  ""
    }
    return  $path
  }
  if { 0 == [file exists $DATA_DIR] } {    file mkdir $DATA_DIR  }
  return  [file join $DATA_DIR $DEPTH_OVERRIDE_FILE]
}


proc FindOldDepthOvrdData {{dir ""}} { ; #   TODO: accept optional dir param
  global DATA_DIR OLD_DEPTH_OVERRIDE_FILE
  if { $dir != "" }  {
    set path [file join $dir $OLD_DEPTH_OVERRIDE_FILE]
    if { 0 == [file exists $path] } {
      ok_warn_msg "No old depth-override data found in '$path' (provided directory)"
      return  ""
    }
    return  $path
  }
  if { 0 == [file exists $DATA_DIR] } {    file mkdir $DATA_DIR  }
  return  [file join $DATA_DIR $OLD_DEPTH_OVERRIDE_FILE]
}


proc SaveLastDepthOverrides {} {
  if { 0 == [file exists [FindDepthOvrdData]] } {
    ok_warn_msg "No depth-override data found in '[FindDepthOvrdData]' - not saved"
    return
  }
  # TODO: put under try{}
  file copy -force [FindDepthOvrdData] [FindOldDepthOvrdData]
  if { 1 == 1 }  {
    ok_trace_msg "Copied last used depth-override data into '[FindOldDepthOvrdData]'"
  } else {
    ok_trace_msg "Failed to copy last used depth-override data into '[FindOldDepthOvrdData]'"
  }
}

# Finds time and depth; returns 1 on success or 0 on error.
proc TopUtils_FindDepth {pureName rawPath timeList depthList \
                          globalTimeVar depthVar} {
  upvar $globalTimeVar globalTime
  upvar $depthVar depth
  global iMetaDate iMetaTime iMetaISO
  array unset imgInfoArr
  if { 0 == [GetImageAttributesByDcraw $rawPath imgInfoArr] }  {
    ok_err_msg "TopUtils_FindDepth:  cannot read RAW metadata for $pureName from '$rawPath'"
    return  0
  }
  set globalTime  [clock scan "$imgInfoArr($iMetaDate) $imgInfoArr($iMetaTime)" -format {%Y %b %d %H %M %S}]
  set depth [DepthLogFindDepthForTime $globalTime $timeList $depthList 1]
  return  1
}


# Creates a file (in predefined path) with enclosing end estimated depths for all RAWs.
proc TopUtils_GenerateDepthOverrideTemplate {logTimeList logDepthList} {
  global DEPTH_OVERRIDE_HEADER
  if { 0 == [FindRawInputsOrComplain "" allRaws] } { ; # ultimate photos are in work-dir
    return  0;  # error already printed
  }
  if { 1 == [file exists [FindDepthOvrdData]] }  {
    ok_warn_msg "Depth-override file '[FindDepthOvrdData]' exists; will not overwrite it"
    return  0
  }
  set cntGood 0
  # pure-name::{time,min-depth,max-depth,estimated-depth,depth}
  array unset dataArr
  # set header for the CSV
  set dataArr("pure-name")  $DEPTH_OVERRIDE_HEADER

  foreach rawPath $allRaws {
    set pureName [file rootname [file tail $rawPath]]
    if { 0 == [TopUtils_FindDepth $pureName $rawPath \
                              $logTimeList $logDepthList globalTime depth] }  {
      continue;  # error already printed
    }
    BisectFindRange $logTimeList $globalTime posBefore posAfter
    set depthBefore [lindex $logDepthList $posBefore]
    set depthAfter  [lindex $logDepthList $posAfter]
    set minDepth [expr min($depthBefore, $depthAfter)]
    set maxDepth [expr max($depthBefore, $depthAfter)]
    incr cntGood 1
    #set dataArr($pureName)  [list $globalTime $minDepth $maxDepth $depth $depth]
    TopUtils_PackDepthOverrideRecord dataArr $pureName \
                                  $globalTime $minDepth $maxDepth $depth $depth
  }

  #ok_trace_msg "going to write ultimate-photos' depth-override data into '[FindDepthOvrdData]'"
  ok_write_array_of_lists_into_csv_file dataArr [FindDepthOvrdData] \
                                        "pure-name" " "
  ok_info_msg "Depth-override data for $cntGood image(s) printed into '[FindDepthOvrdData]'"
  return  $cntGood
}


proc TopUtils_PackDepthOverrideRecord {depthOvrdArr pureName \
                        globalTime minDepth maxDepth estimatedDepth depth} {
  upvar $depthOvrdArr arr
  set arr($pureName)  [list $globalTime \
                      [format "%2.2f" $minDepth] [format "%2.2f" $maxDepth] \
                      [format "%2.2f" $estimatedDepth] [format "%2.2f" $depth]]
}


# Reads from 'depthOvrdArr' into output parameters the record for 'pureName'.
# Returns 1 on success, 0 if inexistent or invalid.
proc TopUtils_ParseDepthOverrideRecord {depthOvrdArr pureName \
                            globalTime minDepth maxDepth estimatedDepth depth} {
  #   pure-name::{global-time,min-depth,max-depth,estimated-depth,depth}
  upvar $depthOvrdArr arr
  upvar $globalTime globalTimeV
  upvar $minDepth minDepthV
  upvar $maxDepth maxDepthV
  upvar $estimatedDepth estimatedDepthV
  upvar $depth depthV
  if { 0 == [info exists arr($pureName)] }  {
    return  0
  }
  set rec $arr($pureName)
  if { 5 > [llength $rec] } {;  # TODO: if >5, tail elements should be empty
    return  0
  }
  _TopUtils_ParseDepthOverrideRecord $rec \
                        globalTimeV minDepthV maxDepthV estimatedDepthV depthV
  set err [CheckDepthOverrideNoNameRecord $rec]
  if { $err != "" } { ok_err_msg "$err" }
  return  [expr {"" == $err}]
}


# Parses record: {global-time,min-depth,max-depth,estimated-depth,depth}
proc _TopUtils_ParseDepthOverrideRecord {recAsList \
                            globalTime minDepth maxDepth estimatedDepth depth} {
  upvar $globalTime globalTimeV
  upvar $minDepth minDepthV
  upvar $maxDepth maxDepthV
  upvar $estimatedDepth estimatedDepthV
  upvar $depth depthV
  set globalTimeV     [lindex $recAsList 0]
  set minDepthV       [lindex $recAsList 1]
  set maxDepthV       [lindex $recAsList 2]
  set estimatedDepthV [lindex $recAsList 3]
  set depthV          [lindex $recAsList 4]
}


# Checks record: {purename,global-time,min-depth,max-depth,estimated-depth,depth}
proc CheckDepthOverrideRecord {recAsList}  {
  return  [CheckDepthOverrideNoNameRecord [lrange $recAsList 1 end]]
}

# Checks record: {global-time,min-depth,max-depth,estimated-depth,depth}
proc CheckDepthOverrideNoNameRecord {recAsList}  {
  #ok_trace_msg "CheckDepthOverrideNoNameRecord {$recAsList}"
  if { 5 > [llength $recAsList] } {; #TODO: if >5, tail elements should be empty
    return  "Too few fields"
  }
  _TopUtils_ParseDepthOverrideRecord $recAsList \
                            globalTime minDepth maxDepth estimatedDepth depth
  if { 0 == [string is integer -strict $globalTime] }  {
    return "Invalid global-time field '$globalTime'"
  }
  if { 0 == [ValidateUltimateDepthString $minDepth] }  {
    return "Invalid min-depth field '$minDepth'"
  }
  if { 0 == [ValidateUltimateDepthString $maxDepth] }  {
    return "Invalid max-depth field '$maxDepth'"
  }
  if { 0 == [ValidateUltimateDepthString $estimatedDepth] }  {
    return "Invalid estimated-depth field '$estimatedDepth'"
  }
  if { 0 == [ValidateUltimateDepthString $depth] }  {
    return "Invalid final-depth field '$depth'"
  }
  return  "" ;  # no error found
}


# Reads ultimate-photos' depth-override data into array 'dataArrVar'.
# 'oldOrNew'==0 for that of the previous run; 'oldOrNew'==1 - for the newest
# Returns 1 on success, 0 on non-fatal error, -1 on fatal error.
proc TopUtils_ReadIntoArrayDepthOverrideCSV {dataArrVar {oldOrNew 1}} {
  upvar $dataArrVar dataArr
  if { $oldOrNew == 0 }   {   set dataPath [FindOldDepthOvrdData]
  } else {                    set dataPath [FindDepthOvrdData]  }
  return [TopUtils_ReadIntoArrayDepthOverrideFromGivenCSV dataArr $dataPath]
}


# Reads ultimate-photos' depth-override from 'dataPath' into array 'dataArrVar'.
# Returns 1 on success, 0 on non-fatal error, -1 on fatal error.
proc TopUtils_ReadIntoArrayDepthOverrideFromGivenCSV {dataArrVar dataPath} {
  upvar $dataArrVar dataArr
  if { 0 == [file exists $dataPath] } {
    ok_info_msg "No depth-override data found in '$dataPath'"
    return  0
  }
  if { 0 == [ok_read_csv_file_into_array_of_lists dataArr $dataPath " " \
                                                "CheckDepthOverrideRecord"] } {
    ok_err_msg "Failed reading depth-override data from '$dataPath'"
    return  -1
  }
  ok_info_msg "Read depth-override data from '$dataPath'"
  return  1
}


proc TopUtils_RemoveHeaderFromDepthOverrideArray {dataArrVar} {
  upvar $dataArrVar dataArr
  array unset dataArr "pure-name"
}


# Replaces 'depth' elements in the records of depth-override array 'dataArrVar'
# by the corresponding values from 'purenameToDepthArrVar' - if present
# dataArrVar = pure-name::{global-time,min-depth,max-depth,estimated-depth,depth}
# dataArrVar includes the header, while purenameToDepthArrVar does not
# Returns 1 if no errors or at least one override succeeded; otherwise returns 0
proc TopUtils_UpdateDepthOverrideArray {dataArrVar purenameToDepthArrVar}  {
  upvar $dataArrVar dataArr
  upvar $purenameToDepthArrVar purenameToDepthArr
  set cntErr 0; set cntAttempts 0; set cntChanged 0
  foreach pureName [array names dataArr] {
    if { 0 == [info exists purenameToDepthArr($pureName)] }  {
      continue ;  # no override for this image
    }
    incr cntAttempts 1
    if { 0 == [ValidateUltimateDepthString $purenameToDepthArr($pureName)] }  {
      set str "Invalid depth override field '$purenameToDepthArr($pureName)' for '$pureName'"
      ok_err_msg $str;  incr cntErr 1;  continue;   # invalid override
    }
    if { 0 == [TopUtils_ParseDepthOverrideRecord dataArr $pureName \
                    globalTime minDepth maxDepth estimatedDepth depth] }  {
      set str "Invalid depth-override record for '$pureName': '$dataArr($pureName)'"
      ok_err_msg $str;  incr cntErr 1;  continue;   # invalid original data
    }
    if { $depth != $purenameToDepthArr($pureName) }  { incr cntChanged 1 }
    set depth $purenameToDepthArr($pureName)
    TopUtils_PackDepthOverrideRecord dataArr $pureName \
                      $globalTime $minDepth $maxDepth $estimatedDepth $depth
  }
  # TODO: more discriminate message - maybe cmp with estimatedDepth?
  set msg1 "Depth-override from the input form affected $cntChanged image(s)"
  if { $cntErr == 0 } {
    ok_info_msg $msg1
  } else {
    ok_err_msg "$msg1. $cntErr error(s) occured; please see the log"
  }
  #return  [expr {($cntErr == 0) || ($cntAttempts > $cntErr)}]
  return  [expr {($cntErr == 0)}]
}


# Reads ultimate-photos' depth-override purename::depth into the two arrays.
# If 'alternativeOldOvrdPath' given, reads old data from it, otherwise from std location
# Returns 1 on success, 0 on non-fatal error, -1 on fatal error.
proc TopUtils_ReadDepthsFromDepthOverrideCSVs {headerPattern \
              nameToDepthOldVar nameToDepthNewVar {alternativeOldOvrdPath ""}} {
  upvar $nameToDepthOldVar nameToDepthOld
  upvar $nameToDepthNewVar nameToDepthNew
  array unset dataArrOld;   array unset dataArrNew
  if { $alternativeOldOvrdPath != "" } {
    set oldOvrdRes [TopUtils_ReadIntoArrayDepthOverrideFromGivenCSV \
                                            dataArrOld $alternativeOldOvrdPath]
  } else {
    set oldOvrdRes [TopUtils_ReadIntoArrayDepthOverrideCSV dataArrOld 0]
  }
  if { $oldOvrdRes <= 0 }  {  return  $oldOvrdRes  } ;  # error already printed
  set ovrdRes [TopUtils_ReadIntoArrayDepthOverrideCSV dataArrNew 1]
  if { $ovrdRes <= 0 } {
    return  $ovrdRes;  # error already printed
  }
  set cntErr 0
  foreach pureName [array names dataArrOld] {
    if { 1 == [regexp $headerPattern $pureName] } { continue }; # skip the header
    if { 0 == [TopUtils_ParseDepthOverrideRecord dataArrOld $pureName \
                    globalTime minDepth maxDepth estimatedDepth depth] }  {
      set str "Invalid old depth-override record for '$pureName': '$dataArrOld($pureName)'"
      ok_err_msg $str;        incr cntErr 1;      continue
    }
    set nameToDepthOld($pureName) $depth
  }
  foreach pureName [array names dataArrNew] {
    if { 1 == [regexp $headerPattern $pureName] } { continue }; # skip the header
    if { 0 == [TopUtils_ParseDepthOverrideRecord dataArrNew $pureName \
                    globalTime minDepth maxDepth estimatedDepth depth] }  {
      set str "Invalid new depth-override record for '$pureName': '$dataArrNew($pureName)'"
      ok_err_msg $str;        incr cntErr 1;      continue
    }
    set nameToDepthNew($pureName) $depth
  }
  return  [expr {($cntErr == 0)? 1 : 0}]
}
    