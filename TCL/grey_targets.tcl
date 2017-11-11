# grey_targets.tcl - neutral development of all files in dir

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "read_img_metadata.tcl"]
source [file join $SCRIPT_DIR   "Parse_CSV_65433-1.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]
source [file join $SCRIPT_DIR   "color_math.tcl"]
source [file join $SCRIPT_DIR   "raw_manip.tcl"]
source [file join $SCRIPT_DIR   "toplevel_utils.tcl"]
source [file join $SCRIPT_DIR   "dive_log.tcl"]
source [file join $SCRIPT_DIR   "raw_converters.tcl"]


array unset GREY_TARGET_DATA_ARR ; # pure-name::{time,depth,<color-representation-depending-on-mode>}

proc InitGrayTargetData {}  {
  global GREY_TARGET_DATA_ARR
  array unset GREY_TARGET_DATA_ARR
}
InitGrayTargetData



proc FindGreyData {{checkExist 0}} {
  global DATA_DIR GREY_DATA_FILE
  if { 0 == [file exists $DATA_DIR] }  { file mkdir $DATA_DIR }
  set fPath [file join $DATA_DIR $GREY_DATA_FILE]
  if { ($checkExist == 1) && (0 == [file exists $fPath]) }  { return  "" }
  return  $fPath
}

proc FindSortedGreyData {{checkExist 0}} {
  global DATA_DIR SORTED_GREY_DATA_FILE
  if { 0 == [file exists $DATA_DIR] } { file mkdir $DATA_DIR }
  set fPath  [file join $DATA_DIR $SORTED_GREY_DATA_FILE]
  if { ($checkExist == 1) && (0 == [file exists $fPath]) }  { return  "" }
  return  $fPath
}

proc FindFilteredGreyData {{checkExist 0}} {
  global DATA_DIR FILTERED_GREY_DATA_FILE
  if { 0 == [file exists $DATA_DIR] } { file mkdir $DATA_DIR }
  set fPath  [file join $DATA_DIR $FILTERED_GREY_DATA_FILE]
  if { ($checkExist == 1) && (0 == [file exists $fPath]) }  { return  "" }
  return  $fPath
}


# Sets in global 'GREY_TARGET_DATA_ARR' estimated depth and color-balance
# for images in 'settingsPathList'. Returns number of images processsed.
proc ReadWBAndMapToDepth {settingsPathList timeList depthList} {
  global GREY_TARGET_DATA_ARR GREY_TARGET_DATA_HEADER_RCONV
  global RAW_COLOR_TARGET_DIR NORMALIZED_DIR
  set cnt 0
  if { 0 == [llength $settingsPathList] }  { return  0 }
  ok_info_msg "ReadWBAndMapToDepth: started processing [llength $settingsPathList] files"
  foreach f $settingsPathList {
    set inf [file nativename $f]
    set pureName [lindex [split [file tail $f] "."] 0];  # cannot use "file root"
    set rawPath [FindRawInput $RAW_COLOR_TARGET_DIR $pureName]
    ok_info_msg "ReadWBAndMapToDepth: processing $inf ($pureName) ..."
    if { 0 == [ReadWBParamsFromSettingsFile $pureName $RAW_COLOR_TARGET_DIR \
                                                  wbParam1 wbParam2 wbParam3] }  {
      ok_err_msg "Failed reading WB parameters from '$f'"
      continue;  # error already printed
    }
    ok_trace_msg "WB parameters from '$f': {$wbParam1 $wbParam2 $wbParam3}"
    if { 0 == [TopUtils_FindDepth $pureName $rawPath \
                                  $timeList $depthList globalTime depth] }  {
      continue;  # error already printed
    }

    set tclResult [catch {
      set list4Massage [PackWBParamsForConverter $wbParam1 $wbParam2 $wbParam3]
      MassageColorParamsForConverter list4Massage
      ParseWBParamsForConverter $list4Massage wbParam1 wbParam2 wbParam3
    } execResult]
    if { $tclResult != 0 } {
      ok_err_msg "Failed 'massaging' converter WB parameters of '$f': $execResult"
      continue
    }

    # GREY_TARGET_DATA_ARR ; # pure-name::{time,depth,wbParam1,wbParam2,wbParam3}
    set GREY_TARGET_DATA_ARR($pureName)  [PackDepthColorNoNameRecord \
                                    $globalTime $depth $wbParam1 $wbParam2 $wbParam3]
    ok_trace_msg "(grey-sample) $pureName,$globalTime,$depth,$wbParam1,$wbParam2,$wbParam3"
    incr cnt 1
  }
  # set header for the CSV and write the file
  ok_info_msg "going to write grey-targets data into '[FindGreyData]'"
  set GREY_TARGET_DATA_ARR("pure-name")   $GREY_TARGET_DATA_HEADER_RCONV
  ok_write_array_of_lists_into_csv_file GREY_TARGET_DATA_ARR [FindGreyData] \
                                        "pure-name" " "
  ok_info_msg "ReadWBAndMapToDepth: finished processing $cnt (out of [llength $settingsPathList]) files"
  return  $cnt
}


# Reads from the predefined csv path correlated lists
#        of depths and {multR multG multB} records
# First line is the header - skipped
# Returns num of samples or -1 on error.
proc ReadGreyTargetResults_Dcraw {depthListName multListRGBName} {
  upvar $depthListName depthList
  upvar $multListRGBName multListRGB
  set fullList [_ChooseAndReadIntoListGrayTargetsCSV csvPath]
  if { $fullList == 0 } {
    return -1;  # error already printed
  }
  # a record in 'fullList': "pure-name",global-time,depth,mRneu,mGneu,mBneu
  ## fullList assumed to be sorted by depth
  set depthList [list ]
  set multListRGB [list ]
  for { set i 1 }  { $i < [llength $fullList] }  { incr i }  {
    set record [lindex $fullList $i]
    ParseDepthColorRecord_Mults $record name time depth mR mG mB
    set mults [PackColorMultsForConverter $mR $mG $mB]
    # was: set depth [lindex $record 2];  set mults [lrange $record 3 5]
    # ok_trace_msg "Processing record '$record':  '$depth->$mults'"
    lappend depthList $depth
    lappend multListRGB $mults
  }
  set cnt [llength $depthList]
  # ok_info_msg "Read $cnt record(s) from grey-targets' colors file '$csvPath'"
  return  $cnt
}


# Reads from the predefined csv path correlated lists
#        of depths and {wbParam1 wbParam2 [wbParam3]} records
# First line is the header - skipped
# Returns num of samples or -1 on error.
proc ReadGreyTargetResults {depthListName wbParamsListName} {
  global CONVERTER_NAME
  upvar $depthListName depthList
  upvar $wbParamsListName wbParamsList
  set fullList [_ChooseAndReadIntoListGrayTargetsCSV csvPath]
  if { $fullList == 0 } {
    return -1;  # error already printed
  }
  # a record in 'fullList':
  #     "pure-name",global-time,depth,wbParam1,wbParam2,wbParam3
  ## fullList assumed to be sorted by depth
  set depthList [list ]
  set wbParamsList [list ]
  for { set i 1 }  { $i < [llength $fullList] }  { incr i }  {
    set record [lindex $fullList $i]
    ParseDepthColorRecord $record name time depth wbParam1 wbParam2 wbParam3
    ok_trace_msg "Depth-color record: {$record}"
    set wbParam3Expected [WBParam3IsUsed]
    if { $wbParam3 != -1 } {  # wbparam3 (like additional color-tint) is present
      if { $wbParam3Expected == 0 }  {
        ok_err_msg "Depth-color record in '$csvPath' includes [WBParam3Name]; possibly comes from RAW converter other than '$CONVERTER_NAME': {$record}"
        return -1;
      }
      set colorData [list $wbParam1 $wbParam2 $wbParam3]
    } else {                  # wbParam3 (like additional color-tint) is absent
      if { $wbParam3Expected == 1 }  {
        ok_err_msg "Depth-color record in '$csvPath' lacks [WBParam3Name]; possibly comes from RAW converter other than '$CONVERTER_NAME': {$record}"
        return -1;
      }
      set colorData [list $wbParam1 $wbParam2]
    }
    # ok_trace_msg "Processing record '$record':  '$depth->$colorData'"
    lappend depthList $depth
    lappend wbParamsList $colorData
  }
  set cnt [llength $depthList]
  # ok_info_msg "Read $cnt record(s) from grey-targets' colors file '$csvPath'"
  return  $cnt
}



# Returns the list read or 0 on error.
# Puts the choosen input path into 'csvPathVar'.
proc _ChooseAndReadIntoListGrayTargetsCSV {csvPathVar} {
  upvar $csvPathVar csvPath
  set csvPathSorted [FindSortedGreyData]
  set csvPathFiltered [FindFilteredGreyData] ;  # preferrable
  set csvPath $csvPathFiltered
  if { 0 == [file exists $csvPathFiltered] } {
    ok_warn_msg "Inexistent filtered grey-targets' colors file '$csvPathFiltered'; will use the original from '$csvPathSorted'"
    set csvPath $csvPathSorted
    if { 0 == [file exists $csvPathSorted] } {
      ok_err_msg "Inexistent sorted grey-targets' colors file '$csvPathSorted'"
      return  0
    }
  }
  set fullList [ok_read_csv_file_into_list_of_lists $csvPath " " "#" \
                                                        "CheckDepthColorRecord"]
  if { $fullList == 0 } {
    ok_err_msg "Failed reading sorted grey-targets' colors file '$csvPath'"
    return  0
  }
  return  $fullList
}


# Interpolates color-multipliers at the given depth given correlated lists
#        of depths and {multR multG multB} records for gray targets
# Returns list {mR,mG,mB}
# TODO: ? Return list {mRneu,mGneu,mBneu,mRcld,mGcld,mBcld} or use 2 calls ?
proc ComputeColorMultsAtDepth {depth depthList multListRGB} {
  BisectFindRange $depthList $depth posBefore posAfter
  set depth1 [lindex $depthList $posBefore]
  set depth2 [lindex $depthList $posAfter]
  set colorMults1 [lindex $multListRGB $posBefore]
  set colorMults2 [lindex $multListRGB $posAfter]
  set colorMults [list ] ;  # will hold the resulting multipliers
  if { $depth1 == $depth2 }  {
    set colorMults $colorMults1
  } else {  # take weighted average colorMults
    set offset [expr 1.0* ($depth-$depth1) / ($depth2-$depth1)]
    foreach iColor {0 1 2} {
      set m1 [lindex $colorMults1 $iColor]; set m2 [lindex $colorMults2 $iColor]
      set m  [expr round(1.0* $m1 + $offset*($m2-$m1))]
      lappend colorMults $m
    }
  }
  # TODO: error condition?
  ok_info_msg "colorMults at $depth is $colorMults ($colorMults1 ... $colorMults2)"
  return $colorMults
}


# Interpolates WB parameters at the given depth given correlated lists
#        of depths and {2-or-3 color parameters} records for gray targets
#           (example: {colorTemp,colorTint[,colorTint2]})
# Returns list of color parameters of the same format as obtained in input
# TODO: ? Return lists for sunny and cloudy or use 2 calls ?
proc ComputeWBParamsAtDepth {depth depthList wbParamList} {
  BisectFindRange $depthList $depth posBefore posAfter
  set depth1 [lindex $depthList $posBefore]
  set depth2 [lindex $depthList $posAfter]
  set wbParams1 [lindex $wbParamList $posBefore]
  set wbParams2 [lindex $wbParamList $posAfter]
  set iColorParamMax [expr {([WBParam3IsUsed])? 2 : 1}]
  set colorParamIdxList [lrange {0 1 2} 0 $iColorParamMax]; # temperature,tint1,tint2(or -1)
  ok_trace_msg "ComputeWBParamsAtDepth: $depth in ($depth1...$depth2) -> ($wbParams1...$wbParams2)"
  set wbParams [list ] ;  # will hold the resulting color-parameters
  if { $depth1 == $depth2 }  {
    if { [llength $depthList] > 1 }  { ;  # if out of depth range, extrapolate
      if { $posAfter == 0 }  {  ; # shallower than min
        set wbParams [_ExtrapolateColorsAboveDepthRange \
                                            $depth $depthList $wbParamList]
        ok_trace_msg "Extrapolated WB parameters for depth=$depth are {$wbParams}"
      } elseif { $posBefore == [expr [llength $depthList] -1]} {;#deeper than max
        set wbParams [_ExtrapolateColorsBelowDepthRange \
                                            $depth $depthList $wbParamList]
        ok_trace_msg "Extrapolated WB parameters for depth=$depth are {$wbParams}"
      } else {
        set wbParams $wbParams1;  # not an out-of-depth-range case
      }
    }
  } else {  # take weighted average wbParams
    set offset [expr 1.0* ($depth-$depth1) / ($depth2-$depth1)]
    foreach iColorParam $colorParamIdxList { ;  # temperature, tint1, tint2(or -1)
      set p1 [lindex $wbParams1 $iColorParam]; set p2 [lindex $wbParams2 $iColorParam]
      set p  [expr 1.0* $p1 + $offset*($p2-$p1)]
      lappend wbParams $p
    }
  }
  # TODO: error condition?
  #ok_trace_msg "WB-parameters at $depth is $wbParams ($wbParams1 ... $wbParams2)"
  MassageColorParamsForConverter wbParams 
  ok_info_msg "WB-parameters at $depth is $wbParams ($wbParams1 ... $wbParams2)"
  return $wbParams
}


# Computes and returns color-parameters with a forged left boundary.
# Color-parameters represented as a 2-3 element list
proc _ExtrapolateColorsAboveDepthRange {depth depthList colorParamList}  {
  global EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK
  if { $EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK != 0 }  {
    # use converter-specific extrapolator
    return  [$EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK \
                                        $depth $depthList $colorParamList]
  }
  set colorParams [list ] ;  # will hold the resulting multipliers or temp/tint
  #~ # forge a left boundary - take weighted average colorParams with surface-shot data
  #~ set depth1 [expr -3.0 * $depth2];   # 0.0 results in undercorrection
  #~ set colorParams1 [GetSurfaceColorParamsAsList];  # temperature, tint1, tint2(or -1)
  #~ set offset [expr 1.0* ($depth-$depth1) / ($depth2-$depth1)]
  #~ foreach iColorParam $colorParamIdxList { ;  # temperature, tint1, tint2(or -1)
    #~ set p1 [lindex $colorParams1 $iColorParam]; set p2 [lindex $colorParams2 $iColorParam]
    #~ set p  [expr 1.0* $p1 + $offset*($p2-$p1)]
    #~ lappend colorParams $p
  #~ }
  set iColorParamMax [expr {([WBParam3IsUsed])? 2 : 1}]
  set colorParamIdxList [lrange {0 1 2} 0 $iColorParamMax]; # temperature,tint1,tint2(or -1)
  # forge a left boundary - half slope of the FULL range 
  set depthNext [lindex $depthList end]
  set depth2 [lindex $depthList 0]
  set colorParamsNext [lindex $colorParamList end]
  set colorParams2 [lindex $colorParamList 0]
  ok_trace_msg "Extrapolating above depth range (shallower): $depth2\(m\)/{$colorParams2} ... $depthNext\(m\)/{$colorParamsNext}"
  foreach iColorParam $colorParamIdxList { ;  # temperature, tint1, tint2(or -1)
    set p2 [lindex $colorParams2    $iColorParam]
    set pN [lindex $colorParamsNext $iColorParam]
    set slope [expr 0.5* ($pN-$p2) / ($depthNext - $depth2)]
    set p [expr 1.0* $p2 - $slope*($depth2 - $depth)]; # could be out of limits
    set p [AdjustColorParameterToConverterLimits $p $iColorParam $depth]
    lappend colorParams $p
  }
  return  $colorParams
}


# Computes and returns color-parameters with a forged right boundary.
# Color-parameters represented as a 2-3 element list
proc _ExtrapolateColorsBelowDepthRange {depth depthList colorParamList}  {
  global EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK
  if { $EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK != 0 }  {
    # use converter-specific extrapolator
    return  [$EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK \
                                        $depth $depthList $colorParamList]
  }
  # per-converter color-parameters' limits
  global WBPARAM1_MIN WBPARAM1_MAX WBPARAM2_MIN WBPARAM2_MAX
  global WBPARAM3_MIN WBPARAM3_MAX
  set loLimits [list $WBPARAM1_MIN $WBPARAM2_MIN $WBPARAM3_MIN]
  set hiLimits [list $WBPARAM1_MAX $WBPARAM2_MAX $WBPARAM3_MAX]
  set colorParams [list ] ;  # will hold the resulting multipliers or temp/tint
  set iColorParamMax [expr {([WBParam3IsUsed])? 2 : 1}]
  set colorParamIdxList [lrange {0 1 2} 0 $iColorParamMax]; # temperature,tint1,tint2(or -1)
   # forge a right boundary - half slope of the last range 
  set depthPrev [lindex $depthList [expr [llength $depthList] -2]]
  set depth1 [lindex $depthList [expr [llength $depthList] -1]]
  set colorParamsPrev [lindex $colorParamList [expr [llength $depthList] -2]]
  set colorParams1 [lindex $colorParamList [expr [llength $depthList] -1]]
  ok_trace_msg "Extrapolating below depth range (deeper): $depthPrev\(m\)/{$colorParamsPrev} ... $depth1\(m\)/{$colorParams1}"
  foreach iColorParam $colorParamIdxList { ;  # temperature, tint1, tint2(or -1)
    set p1 [lindex $colorParams1    $iColorParam]
    set pP [lindex $colorParamsPrev $iColorParam]
    set slope [expr 0.5* ($p1-$pP) / ($depth1 - $depthPrev)]
    set p [expr 1.0* $p1 + $slope*($depth - $depth1)];  # could be out of limits
    set p [AdjustColorParameterToConverterLimits $p $iColorParam $depth]
    lappend colorParams $p
  }
  return  $colorParams
}


# Sorts records of the gray-targets' datafile by depth
# First line is the header.
# Returns 1 on success, 0 on error.
proc SortGreyTargetResults {} {
  set csvPath [FindGreyData]
  set sortedCsvPath [FindSortedGreyData]
  # a gray-target record: "pure-name",global-time,depth,mRneu,mGneu,mBneu
  # TODO: how to generalize column index?
  set sortedListWithHeader [sort_csv_file_by_numeric_column $csvPath 2 \
                                                        "gray-targets' colors"]
  return  [ok_write_list_of_lists_into_csv_file $sortedListWithHeader \
                                                $sortedCsvPath " "]
}


