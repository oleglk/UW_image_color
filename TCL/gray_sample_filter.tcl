# gray_sample_filter.tcl

source [file join $SCRIPT_DIR   "longest_path.tcl"]



proc FilterGraySamples {} {
  set sortedCsvPath [FindSortedGreyData]
  if { 0 == [file exists $sortedCsvPath] } {
    ok_err_msg "Inexistent sorted gray-targets' colors file '$sortedCsvPath'"
    return  0
  }
  set fullList [ok_read_csv_file_into_list_of_lists $sortedCsvPath " " "#" \
                                                        "CheckDepthColorRecord"]
  if { $fullList == 0 } {
    ok_err_msg "Failed reading sorted gray-targets' colors file '$sortedCsvPath'"
    return  0
  }
  # 'fullList' starts with header
  # a record in 'fullList': "pure-name",global-time,depth,<color-parameters-list-depending-on-mode>
  if { 0 == [set lPath [_FilterGraySamplesInList [lrange $fullList 1 end]]] } {
    return  0;  # error already printed
  }
  set header [list [lindex $fullList 0]];  # wrapped to prepare for "concat" 
  set filteredListNoHeader [list ]
  # 'lPath' has only names
  foreach rec [lrange $fullList 1 end]  {
    ParseDepthColorRecord $rec name time depth wbParam1 wbParam2 wbParam3
    #TODO: optimize
    if { -1 != [lsearch $lPath $name] } {
      lappend filteredListNoHeader $rec
    }
  }
  # try replacing outermost vertices in 'filteredListNoHeader' with more extremes
  if { 0 == [_ExtendSamplesPathToExtremes \
                            [lrange $fullList 1 end] filteredListNoHeader] } {
    return  0;  # TODO add to error message
  }
    
  set extendedListWithHeader [concat $header $filteredListNoHeader]

  set filteredCsvPath [FindFilteredGreyData]
  return  [ok_write_list_of_lists_into_csv_file $extendedListWithHeader \
                                                $filteredCsvPath " "]
}


# Returns list of "good" samples' pure-names in the sorted grey-samples' record list
proc _FilterGraySamplesInList {samplesList} {
  global FIRST LAST
  # a record in 'samplesList': "pure-name",global-time,depth,<color-parameters-list-depending-on-mode>
  if { 0 == [set graphDict [_BuildGraySamplesGraph $samplesList]] } {
    return  0;  # error already printed
  }
  
  # find path
  set lPath [FindLongestPath $graphDict]
  puts "Longest path covers [llength $lPath] out of [expr [llength $samplesList] -1] sample(s):   {$lPath}"
  return  $lPath
}


# Builds and returns the graph for finding longest path; on error returns 0.
# 'samplesList' should be sorted by depth.
proc _BuildGraySamplesGraph {samplesList} {
  global IS_SAMPLE_ADJACENT_CALLBACK
  global FIRST LAST
  # a record in 'samplesList': "pure-name",global-time,depth,<color-parameters-list-depending-on-mode>
  set nSamples [llength $samplesList]
  set nEdges 0
  ok_trace_msg "Start building helper graph for $nSamples gray sample(s)"
  for { set i 0 }  { $i < [expr $nSamples - 1] }  { incr i } {  # last excluded
    set u [lindex $samplesList $i]
    # insert sample 'u' and all adjacent samples
    set adj [list ]
    foreach v [lrange $samplesList [expr $i+1] end]   {
      if { [$IS_SAMPLE_ADJACENT_CALLBACK $u $v] } {
        ParseDepthColorRecord $v nameV time depth wbParam1 wbParam2 wbParam3
        lappend adj $nameV
      }
    }
    ok_trace_msg "'$u' could be followed by [llength $adj] sample(s)"
    ParseDepthColorRecord $u nameU time depth wbParam1 wbParam2 wbParam3
    dict set graphDict $nameU $adj
    incr nEdges [llength $adj]
  }
  if { $nEdges < 1 }  {
    ok_err_msg "Gray-target data ($nSamples sample(s)) appears to be invalid"
    return  0
  }
  # forge start- and end vertices
  set graphDict [_ForgeFirstLast $samplesList $graphDict \
                            numAdjacentToFirst numAdjacentToLast]
  incr nEdges [expr $numAdjacentToFirst + $numAdjacentToLast]
  ok_trace_msg "Done building helper graph for $nSamples gray sample(s) - $nEdges edge(s)"
  #_PriDict $graphDict
  return  $graphDict
}


# Arranges start and end vertices.
# Returns the extended dictionary 'graphDict'.
# Puts numbers of inserted vertices into 'numAdjacentToFirstVar'/'numAdjacentToLastVar'
proc _ForgeFirstLast {samplesList graphDict numAdjacentToFirstVar numAdjacentToLastVar} {
  global IS_SAMPLE_ADJACENT_CALLBACK
  global FIRST LAST
  upvar $numAdjacentToFirstVar numAdjacentToFirst
  upvar $numAdjacentToLastVar numAdjacentToLast
  set nSamples [llength $samplesList]
  _MaxAdjacentToFirstAndLast $samplesList maxAdjacentToFirst maxAdjacentToLast
  set shallowRange [lrange $samplesList 0 [expr $maxAdjacentToFirst - 1]]
  foreach v $shallowRange {
    ParseDepthColorRecord $v nameV time depth wbParam1 wbParam2 wbParam3
    ok_trace_msg "low-range vertex '$nameV' connected to FIRST"
    dict lappend graphDict $FIRST $nameV
  }
  set deepRangeRev [lreverse \
      [lrange $samplesList [expr $nSamples - $maxAdjacentToLast] end]] 
  foreach u $deepRangeRev {
    ParseDepthColorRecord $u nameU time depth wbParam1 wbParam2 wbParam3
    ok_trace_msg "high-range vertex '$nameU' connected to LAST"
    dict set graphDict $nameU $LAST
  }
  set numAdjacentToFirst $maxAdjacentToFirst
  set numAdjacentToLast  $maxAdjacentToLast
  ok_info_msg "Will choose depth range lower limit from $numAdjacentToFirst samples"
  ok_info_msg "Will choose depth range upper limit from $numAdjacentToLast  samples"
  return  $graphDict
}


# Tries to replace first/last vertices in 'filteredSamplesList' by outer ones
# - in order to cover greater deprh range. Returns the new list.
# Both 'samplesList' and 'filteredSamplesList' should be sorted by ascending depth.
proc _ExtendSamplesPathToExtremes {samplesList filteredSamplesListVar} {
  global IS_SAMPLE_ADJACENT_CALLBACK
  global FIRST LAST
  upvar $filteredSamplesListVar filteredSamplesList
  set nSamples [llength $filteredSamplesList]
  if { $nSamples < 2 }  {
    ok_err_msg "There are too few consistent gray samples"
    return  0
  }
  set lastIdx [expr $nSamples - 1]
  set secondLo [lindex $filteredSamplesList 1]
  set secondHi [lindex $filteredSamplesList [expr $nSamples - 2]]
  _MaxAdjacentToFirstAndLast $samplesList maxAdjacentToFirst maxAdjacentToLast
  # strive to include readings at min/max depths
  set shallowRange [lrange $samplesList 0 [expr $maxAdjacentToFirst - 1]] 
  foreach v $shallowRange {
    ParseDepthColorRecord $v nameV time depth wbParam1 wbParam2 wbParam3
    # if this vertex consistent with 'secondLo', take it as the most shallow
    if { 1 == [$IS_SAMPLE_ADJACENT_CALLBACK $v $secondLo] } {
      ok_info_msg "low-range vertex '$nameV' (depth=$depth) chosen as the most shallow"
      set filteredSamplesList [lreplace $filteredSamplesList 0 0 $v]
      break
    }
  }
  set deepRangeRev [lreverse \
      [lrange $samplesList [expr $nSamples - $maxAdjacentToLast] end]] 
  foreach u $deepRangeRev {
    ParseDepthColorRecord $u nameU time depth wbParam1 wbParam2 wbParam3
    if { 1 == [$IS_SAMPLE_ADJACENT_CALLBACK $secondHi $u] } {
      ok_info_msg "high-range vertex '$nameU' (depth=$depth) chosen as the most deep"
      set filteredSamplesList [lreplace $filteredSamplesList $lastIdx $lastIdx $u]
      break
    }
  }
  return  1
}


##proc _MaxAdjacentToFirst {nSamples} { return [expr round($nSamples /4)] }
##proc _MaxAdjacentToLast  {nSamples} { return [expr round($nSamples /4)] }

# Computes how many samples to connect with start/end.
# Assumes 'samplesList' is sorted by ascending depth.
# a record in 'samplesList': "pure-name",global-time,depth,<color-parameters-list-depending-on-mode>
proc _MaxAdjacentToFirstAndLast {samplesList toFirst toLast}  {
  upvar $toFirst toF
  upvar $toLast  toL
  set nSamples [llength $samplesList]
  set firstRec [lindex $samplesList 0]
  set lastRec  [lindex $samplesList end]
  ParseDepthColorRecord $firstRec name time minDepth wbParam1 wbParam2 wbParam3
  ParseDepthColorRecord $lastRec  name time maxDepth wbParam1 wbParam2 wbParam3
  set depthRange [expr $maxDepth - $minDepth]
  set offset [expr $depthRange / 8.0]
  if { $offset < 1.0 }  { set offset 1.0 }
  set firstLimit [expr $minDepth + $offset]
  set lastLimit  [expr $maxDepth - $offset]
  # tell to connect all within the corresponding ranges or within [2 ... n/4]
  set toF 0;  set toL 0
  for {set i 0}  {$i < [expr $nSamples/4]}  {incr i 1}  {
    set rec [lindex $samplesList $i]
    ParseDepthColorRecord $rec name time depth wbParam1 wbParam2 wbParam3
    if { $depth <= $firstLimit }  { incr toF }  else  { break }
  }
  for {set i [expr $nSamples-1]}  {$i >= [expr $nSamples-$nSamples/4]}  {incr i -1}  {
    set rec [lindex $samplesList $i]
    ParseDepthColorRecord $rec name time depth wbParam1 wbParam2 wbParam3
    if { $depth >= $lastLimit }  { incr toL }  else  { break }
  }
  if { $toF < 2 }  { set toF 2 }
  if { $toL < 2 }  { set toL 2 }
  return
}

