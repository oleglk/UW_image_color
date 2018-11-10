# test_run.tcl

set TESTCODE_DIR [file dirname [info script]]

set UWIC_DIR [file join $TESTCODE_DIR ".." ".."]

source [file join $UWIC_DIR     "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$TESTCODE_DIR' ----"

source [file join $UWIC_DIR     "gui.tcl"]
source [file join $TESTCODE_DIR "test_arrange.tcl"]
source [file join $TESTCODE_DIR "AssertExpr.tcl"]

#TODO: use firstStepIdx, lastStepIdx; any goto?
# incr iStep 1
# if { $iStep < $firstStepIdx }  { goto <next-step> }
# if { $iStep > $lastStepIdx }  { return $lastResult }

#TODO: pass pathDict to flow-step functions


proc TestFullFlow {workDir rawConvName} {
  set pathDict1 [FlowStep_InitSession $workDir $rawConvName]
  if { $pathDict1 == 0 }  { return  0 }

  set pathDict2 [FlowStep_SeparateThumbnails $workDir $rawConvName]
  if { $pathDict2 == 0 }  { return  0 }
  
  set pathDict3 [FlowStep_SortAllRawsByThumbnails $workDir $rawConvName]
  if { $pathDict3 == 0 }  { return  0 }
  
  set pathDict4 [FlowStep_MapDepthToColor $workDir $rawConvName]
  if { $pathDict4 == 0 }  { return  0 }
  if { 0 == [VerifyInputsPreserved $pathDict3 $pathDict4 1 1] }  { return  0 }
  
  set pathDict5 [FlowStep_ProcAllRAWs $workDir $rawConvName]
  if { $pathDict5 == 0 }  { return  0 }
  if { 0 == [VerifyInputsPreserved $pathDict4 $pathDict5 1 1] }  { return  0 }
  
  set pathDict6 [FlowStep_ProcChangedRAWs $workDir $rawConvName]
  if { $pathDict6 == 0 }  { return  0 }
  if { 0 == [VerifyInputsPreserved $pathDict5 $pathDict6 1 1] }  { return  0 }

  return  1
}

######################## BEGIN: Flow stages ####################################
proc FlowStep_InitSession {workDir rawConvName}  {
  ok_info_msg "\n=========\nChoose working directory, choose RAW-converter\n=========\n"
  if { "" != [set msg [_GUI_SetDir $workDir]] }  {
    ok_err_msg "Failed to set work-dir: $msg";  return  0
  }
  SetRAWConverter $rawConvName
  if { $rawConvName != [GetRAWConverterName] } {;   # verify converter choice
    ok_err_msg "Failed to choose RAW-converter '$rawConvName'";  return  0
  }
  # for converter with std settings dir the next action will move settings files
  if { 0 == [MakeFakeSettingsDirIfNeeded $workDir] } { return 0 };# error printed
  if { 0 == [set pathDict [ListWorkAreaStuff]] } {  return  0 }; # error printed
  return  $pathDict
}


proc FlowStep_SeparateThumbnails {workDir rawConvName}  {
  ok_info_msg "\n=========\nExtract thumbnails and separate those of WB-targets\n=========\n"
  if { 0 == [GUI_ExtractThumbnails] }  {
    ok_err_msg "Failed to extract thumbnails";  return  0
  }
  if { 0 == [MoveColorTargetThumbnails $workDir] }  {
    return  0;  # error already printed
  }
  if { 0 == [set pathDict [ListWorkAreaStuff]] } {  return  0 }; # error printed
  return  $pathDict
}


proc FlowStep_SortAllRawsByThumbnails {workDir rawConvName}  {
  ok_info_msg "\n=========\nSort RAWs by thumbnails; verify results\n=========\n"
  if { "" != [set msg [SortAllRawsByThumbnails]] }  {
    ok_err_msg "Failed to sort RAWs by thumbnails: $msg";  return  0
  }
  if { 0 == [set pathDict [ListWorkAreaStuff]] } {  return  0 }; # error printed
  if { 0 == [CheckRAWByThumbnailSorting $pathDict] } { return  0};# error printed
  return  $pathDict
}


proc FlowStep_MapDepthToColor {workDir rawConvName}  {
  ok_info_msg "\n=========\nProcess depth-color data; verify results\n=========\n"
  ok_info_msg "Verify that dive-log ambiguity results in abort. TODO: move into a separate test"
  if { 0 == [SimulateDivelogAmbiguity $workDir origDiveLog] }  {  return  0  }
  if { 1 == [GUI_MapDepthToColor] }  {
    ok_err_msg "Map depth to color did not fail because of dive-log ambiguity"
    return  0
  }
  ok_info_msg "Map depth to color failed because of dive-log ambiguity - as expected"
  file delete -force $origDiveLog ;  # TODO: put into try{}
  ok_info_msg "Removed the original dive-log '$origDiveLog' to eliminate ambiguity"
  if { 0 == [set pathDictOld [ListWorkAreaStuff]] } {  return  0 }
  if { 0 == [GUI_MapDepthToColor] }  {
    ok_err_msg "Failed to map depth to color";  return  0
  }
  if { 0 == [set pathDict [ListWorkAreaStuff]] } {  return  0 }; # error printed
  if { 0 == [CheckDepthToColorMapSanity $pathDict] } { return  0};# error printed
  if { 0 == [CheckUnmatchedInputsTreatment $pathDictOld $pathDict 1 0] } {return 0}
  return  $pathDict
}


proc FlowStep_ProcAllRAWs {workDir rawConvName}  {
  ok_info_msg "\n=========\nProcess ultimate RAWs; verify results\n=========\n"
  if { 0 == [set pathDictOld [ListWorkAreaStuff]] } {  return  0 }
  if { 0 == [GUI_ProcAllRAWs] }  {
    ok_err_msg "Failed to override WB in converter settings file(s)";  return  0
  }
  if { 0 == [set pathDict [ListWorkAreaStuff]] } {  return  0 }; # error printed
  if { 0 == [CheckUltimateWBData $pathDict] } { return  0 };  # error printed
  if { 0 == [CheckUnmatchedInputsTreatment $pathDictOld $pathDict 1 1] } {return 0}
  ###### verify RAW colors override in the settings files
  if { 0 == [CompareUltimatePhotosSettingsWithWBData $pathDict] }  { return  0 }
  return  $pathDict
}


proc FlowStep_ProcChangedRAWs {workDir rawConvName}  {
  if { 0 == [set pathDict [ListWorkAreaStuff]] } {  return  0 }; # error printed
  ok_info_msg "\n=========\nOverride depth for some RAWs; process changed RAWs; verify results\n=========\n"
  set lastDepthOvrdBU [ForcedBackupDepthOverrideIfExists];  # no auto back-up
  if { 0 == [set ovrdPurenames [_SimulateDepthOverride $pathDict]] } { return 0 }
  if { 0 == [set pathDictOld [ListWorkAreaStuff]] } {  return  0 }
  if { 0 == [GUI_ProcChangedRAWs] }  {
    ok_err_msg "Failed to override WB in converter settings file(s) for overriden depth "
    return  0
  }
  if { 0 == [set pathDict [ListWorkAreaStuff]] } {  return  0 }; # error printed
  if { 0 == [CheckUnmatchedInputsTreatment $pathDictOld $pathDict 0 1] } {return 0}
  if { 0 == [CheckUltimateWBData $pathDict] } { return  0 };  # error printed
  # verify RAW colors override in the settings files (after processing changed RAW(s))
  if { 0 == [CheckChangedUltimatePhotosSettings $pathDict $lastDepthOvrdBU  \
                                                  $ovrdPurenames] }  {
    return  0
  }
  # verify depth and colors have been changed
  if { 0 == [CheckDepthOvrdInUltimateWBData $pathDict $ovrdPurenames] }  {
    return  0
  }
  if { 0 == [CompareUltimatePhotosSettingsWithWBData $pathDict] }  { return  0 }
  return  $pathDict
}
######################## END:   Flow stages ####################################


proc MoveColorTargetThumbnails {workDir} {
  global THUMB_DIR THUMB_COLORTARGET_DIR
  set thumbPath [file join $workDir $THUMB_DIR]
  set thumbColorTargetPath [file join $workDir $THUMB_COLORTARGET_DIR]
  set pattern [format "_%s.*\.jpg" [KeyStr_ColorTarget]]
  set allTargets [BuildFilepathListFromRegexp $pattern $thumbPath]
  # TODO: what if exist at dest; currently - error
  if { 0 > [MoveListedFiles 0 $allTargets $thumbColorTargetPath] }  {
    set msg "Failed to move color-target thumbnail(s) into '$thumbColorTargetPath'"
    ok_err_msg $msg;    return  0
  }
  ok_info_msg "Moved [llength $allTargets] color-target thumbnail(s) into '$thumbColorTargetPath'"
  return  1
}


proc CheckRAWByThumbnailSorting {pathDict} {
  set purenamesRAWPhoto [BuildSortedPurenamesList \
                                 [dict get $pathDict "PHOTOS"]]
  set purenamesRAWTarg  [BuildSortedPurenamesList \
                                 [dict get $pathDict "WB-TARGETS"]]
  set purenamesThumbPhoto [BuildSortedPurenamesList \
                                 [dict get $pathDict "THUMBNAILS-PHOTOS"]]
  set purenamesThumbTarg  [BuildSortedPurenamesList \
                                 [dict get $pathDict "THUMBNAILS-WB-TARGETS"]]
  set purenamesSettingsPhoto [BuildSortedPurenamesList \
                                 [dict get $pathDict "SETTINGS-PHOTOS"]]
  set purenamesSettingsTarg  [BuildSortedPurenamesList \
                                 [dict get $pathDict "SETTINGS-WB-TARGETS"]]
  ok_trace_msg "RAW of PHOTOS: {$purenamesRAWPhoto}"
  ok_trace_msg "THUMBNAILS of PHOTOS: {$purenamesThumbPhoto}"
  ok_trace_msg "RAW of WB-TARGETS: {$purenamesRAWTarg}"
  ok_trace_msg "THUMBNAILS of WB-TARGETS: {$purenamesThumbTarg}"
  set pOk [_SortedListsEQU $purenamesRAWPhoto $purenamesThumbPhoto]
  set tOk [_SortedListsEQU $purenamesRAWTarg $purenamesThumbTarg]
  if { $pOk == 0 } {
    ok_err_msg "Mismatch in presense of RAW ultimate photos vs their thumbnails"
  }
  if { $tOk == 0 } {
    ok_err_msg "Mismatch in presense of RAW WB targets vs their thumbnails"
  }
  set spOk [_SortedListsEQU $purenamesSettingsPhoto $purenamesThumbPhoto]
  set stOk [_SortedListsEQU $purenamesSettingsTarg $purenamesThumbTarg]
  if { $spOk == 0 } {
    ok_err_msg "Mismatch in presense of RAW-settings for ultimate photos vs their thumbnails"
  }
  if { $stOk == 0 } {
    ok_err_msg "Mismatch in presense of RAW-settings for WB targets vs their thumbnails"
  }
  set isOk [expr {($pOk == 1) && ($tOk == 1) && ($spOk == 1) && ($stOk == 1)}]
  if { $isOk == 1} {
    ok_info_msg "RAW by thumbnail sorting is correct"
  }
  return  $isOk
}


proc CheckDepthToColorMapSanity {pathDict} {
  set purenamesRAWTarg  [BuildSortedPurenamesList \
                                 [dict get $pathDict "WB-TARGETS"]]
  set wbTargDataPath [dict get $pathDict "DATAFILE-WB-TARGETS"]
  set wbTargSortedDataPath [dict get $pathDict "DATAFILE-WB-TARGETS-SORTED"]
  set wbTargFilteredDataPath [dict get $pathDict "DATAFILE-WB-TARGETS-FILTERED"]
  ######### check original gray-targets datafile
  if { "" == $wbTargDataPath } {
    ok_err_msg "Missing WB targets datafile";  return  0
  }
  set keys_targData [lsort [ok_read_csv_file_keys $wbTargDataPath " " "#"]]
  set targDataOk [_SortedListsEQU $purenamesRAWTarg $keys_targData]
  if { $targDataOk == 0 } {
    ok_err_msg "Name mismatch in WB targets datafile '$wbTargDataPath'"
    return  0
  }
  ######### check sorted gray-targets datafile
  if { "" == $wbTargSortedDataPath } {
    ok_err_msg "Missing sorted WB targets datafile";  return  0
  }
  # check keys (filenames) in sorted data
  set keys_targDataSorted [lsort [ok_read_csv_file_keys $wbTargSortedDataPath " " "#"]]
  set targDataSortedOk [_SortedListsEQU $purenamesRAWTarg $keys_targDataSorted]
  if { $targDataSortedOk == 0 } {
    ok_err_msg "Name mismatch in sorted WB targets datafile '$wbTargSortedDataPath'"
    return  0
  }
  # verify sorting by depth - by a custom proc
  set targDataSortedOk [_CheckGrayTargetSortingByDepth $wbTargSortedDataPath]
  if { $targDataSortedOk == 0 } {
    ok_err_msg "Bad sorting of WB targets; datafile '$wbTargSortedDataPath'"
    return  0
  }
  ######### check filtered gray-targets datafile
  if { "" == $wbTargFilteredDataPath } {
    ok_err_msg "Missing filtered WB targets datafile";  return  0
  }
  if { "" == $wbTargFilteredDataPath } {
    ok_err_msg "Missing filtered WB targets datafile";  return  0
  }
  # check keys (filenames) in filtered data
  set keys_targDataFiltered [ok_read_csv_file_keys $wbTargFilteredDataPath " " "#"]
  set targDataFilteredOk [_FilteredListIsSubset $keys_targDataFiltered \
                                                $purenamesRAWTarg]
  if { $targDataFilteredOk == 0 } {
    ok_err_msg "Wrong name(s) in filtered WB targets datafile '$wbTargFilteredDataPath'"
    return  0
  }
  #TODO: check consistency of filtered data
  set targDataFilteredOk [_CheckFilteredGrayTargetsConsistency \
                                                    $wbTargFilteredDataPath]
  ok_info_msg "Depth-to-color-mapping is correct"
  return  1
}


proc _SortedListsEQU {ls1 ls2} {
  set n [llength $ls1]
  if { $n != [llength $ls2] } {
    ok_trace_msg "@TMP@ Length mismatch: [llength $ls1] vs [llength $ls2]\t({$ls1} vs {$ls2})"
    return 0
  }
  for {set i 0} {$i < $n} {incr i} {
    if { [lindex $ls1 $i] != [lindex $ls2 $i] }  {
      ok_trace_msg "@TMP@ At $i: '[lindex $ls1 $i]' vs '[lindex $ls2 $i]'"
      return  0
    }
  }
  return  1
}


proc _FilteredListIsSubset {subSetList superSetListSorted}  {
  foreach fName $subSetList {
    if { 0 > [lsearch -exact -sorted $superSetListSorted $fName] } {
      return  0
    }
  }
  return 1
}


proc _CheckGrayTargetSortingByDepth {fullPath} {
  set listOfLists [ok_read_csv_file_into_list_of_lists $fullPath " " "#" \
                                                        "CheckDepthColorRecord"]
  set isSorted 1
  set prevDepth 0.0
  # comments dropped; do skip header
  for {set i 1} {$i < [llength $listOfLists]} {incr i} {
    set record [lindex $listOfLists $i]
    if { 0 == [ParseDepthColorRecord $record name time depth cp1 cp2 cp3] }  {
      ok_err_msg "Invalid line $i in '$fullPath'";  return  0
    }
    if { $depth < $prevDepth }  {
      ok_err_msg "Sorting broken at line $i (depth $depth) in '$fullPath'"
      return  0
    }
    set prevDepth $depth
  }
  ok_info_msg "Sorting by depth is correct in '$fullPath'"
  return  1
}


proc _CheckFilteredGrayTargetsConsistency {fullPath} {
  # expect being sorted by depth
  set targDataSortedOk [_CheckGrayTargetSortingByDepth $fullPath]
  if { $targDataSortedOk == 0 } {
    ok_err_msg "Bad sorting of filtered WB targets; datafile '$fullPath'"
    return  0
  }
  set listOfLists [ok_read_csv_file_into_list_of_lists $fullPath " " "#" 0]
  set listOfListsNoHdr [lrange $listOfLists 1 end]
  return  [_CheckSortedDepthColorRecordsConsistency $listOfListsNoHdr \
                            "filtered WB targets (datafile '$fullPath')"]
}


proc _CheckSortedDepthColorRecordsConsistency {listOfLists descr} {
  global IS_SAMPLE_ADJACENT_CALLBACK
  if { 2 > [llength $listOfLists]  } { ; # need >=2 records
    ok_err_msg "Too few records of $descr"
    return  0
  }
  # go over pairs; comments and header already dropped
  for {set i 0} {$i < [expr [llength $listOfLists] -1]} {incr i} {
    set record1 [lindex $listOfLists $i]
    set record2 [lindex $listOfLists [expr $i+1]]
    if { 0 == [ParseDepthColorRecord $record1 \
                                      name1 time1 depth1 cp11 cp21 cp31] }  {
      ok_err_msg "Invalid record '$record1' in $descr";  return  0
    }
    if { 0 == [ParseDepthColorRecord $record2 \
                                      name2 time2 depth2 cp12 cp22 cp32] }  {
      ok_err_msg "Invalid record '$record2' in $descr";  return  0
    }
    set depthDiff [expr $depth2 - $depth1]
    if { 0 == [string compare $depth2 $depth1] } { ;  # require exact match
      ##if { ($cp11 != $cp12) && ($cp21 != $cp22) && ($cp31 != $cp32) } {}
      if {  (0 != [string compare $cp11 $cp12]) || \
            (0 != [string compare $cp21 $cp22]) || \
            (0 != [string compare $cp31 $cp32]) } {
        ok_err_msg "Inconsistent equal-depth records '$record1' and '$record2' in $descr"
        return  0
      }
      continue;   # records are absolutely identical
    } elseif { $depthDiff <= [GetDepthResolution] } {
      ok_trace_msg "Records '$record1' and '$record2' too close; cannot compare"
      incr i 1;   continue
    }
    if { 0 == [$IS_SAMPLE_ADJACENT_CALLBACK $record1 $record2] } {
      ok_err_msg "Inconsistent records '$record1' and '$record2' in $descr (depth-difference = $depthDiff)"
      return  0
    }
  }
  ok_info_msg "$descr data are consistent"
  return  1
}


proc CheckUltimateWBData {pathDict {changedPurenames 0}}  {
  # - Check file-list in result-colors datafile
  set purenamesRAWPhoto [BuildSortedPurenamesList \
                                 [dict get $pathDict "PHOTOS"]]
  set wbResultsDataPath [dict get $pathDict "DATAFILE-RESULT-COLORS"]
  if { 0 == [file exists $wbResultsDataPath] }  {
    ok_trace_msg "Work-dir files in 'CheckUltimateWBData':\n{[FormatWorkAreaStuff $pathDict]}"
    ok_err_msg "Result colors datafile '$wbResultsDataPath' inexistent."
    return  0
  }
  set keys_wbData [lsort [ok_read_csv_file_keys $wbResultsDataPath " " "#"]]
  if { 0 == [_SortedListsEQU $purenamesRAWPhoto $keys_wbData] } {
    ok_err_msg "Mismatch in presense of RAW ultimate photos vs their WB data"
    ok_err_msg "RAW files for photos: {$purenamesRAWPhoto}"
    ok_err_msg "WB parameters available for photos: {$keys_wbData}"
    return  0
  }
  ok_info_msg "List of WB overrides in '$wbResultsDataPath' matches ultimate RAW photos"
  # - Mix photos and selected consistent targets together, sort by depth,
  #       and then check mutual consistency while going from shallow to the deep
  set wbTargFilteredDataPath [dict get $pathDict "DATAFILE-WB-TARGETS-FILTERED"]
  if { 0 == [set allWBlistNoHdr [_MixUltimatePhotosAndWBTargetsData \
                                $wbResultsDataPath $wbTargFilteredDataPath]] } {
    ok_err_msg "Failed merging WB data of ultimate photos and WB targets"
    return  0
  }
  # TODO: it fails at close depths because of CB restriction made for targets
  return  [_CheckSortedDepthColorRecordsConsistency $allWBlistNoHdr \
                        "merged WB records of ultimate photos and WB targets"]
}


proc CompareUltimatePhotosSettingsWithWBData {pathDict}  {
  global CONVERTER_NAME SETTINGS_DIR
  global WBPARAMS_EQU_OPTIONAL_CALLBACK
  set rawPaths [dict get $pathDict "PHOTOS"]
  set purenamesRAWPhoto [BuildSortedPurenamesList $rawPaths]
  ok_trace_msg "RAW of PHOTOS: {$purenamesRAWPhoto}"
  set settingsPathsAll [dict get $pathDict "SETTINGS-PHOTOS"]
  if { $SETTINGS_DIR != "" }  { ;   # unmatched settings  are not  hidden
    set settingsPaths [FilterFilepathListByRegexp \
                                      "[KeyStr_Unmatched]" $settingsPathsAll 0]
  } else { ;                        # unmatched settings should be hidden
    set settingsPaths $settingsPathsAll
  }
  set purenamesSettings [BuildSortedPurenamesList $settingsPaths]
  # verify there's settings file for each RAW
  if { 0 == [_SortedListsEQU $purenamesRAWPhoto $purenamesSettings] }  {
    ok_err_msg "Mismatch in presense of RAW ultimate photos vs their converter settings' files for '$CONVERTER_NAME': {$purenamesRAWPhoto} vs {$purenamesSettings}"
    return  0
  }
  set wbResultsDataPath [dict get $pathDict "DATAFILE-RESULT-COLORS"]
  array unset dataArr
  if { 0 == [ok_read_csv_file_into_array_of_lists dataArr \
                            $wbResultsDataPath " " "CheckDepthColorRecord"] } {
    ok_err_msg "Failed reading color data from '$dataPath'"
    return  0
  }
  # dataArr == pure-name::{time,depth,cp1,cp2,cp3}
  # compare color parameters in existing settings files with WB datafile
  foreach sP $settingsPaths {
    set pureName [lindex [split [file tail $sP] "."] 0];  # cannot use "rootname"
    if { 0 == [info exists dataArr($pureName)] } {
      ok_err_msg "No color data found for '$pureName'";      return  0
    }
    if { 0 == [ParseDepthColorNoNameRecord $dataArr($pureName) \
                                      time depth cp1 cp2 cp3] }  {
      ok_err_msg "Invalid record '$dataArr($pureName)' for '$pureName' in '$wbResultsDataPath'"
      return  0
    }
    ok_info_msg "ReadWBAndMapToDepth: processing '$sP' ($pureName) ..."
    if { 0 == [ReadWBParamsFromSettingsFile $pureName "" \
                                                  scp1 scp2 scp3] }  {
      ok_err_msg "Failed reading WB parameters from settings file of '$pureName' ($sP)"
      return  0
    }
    if { 0 == [SafeMassageColorParamsForConverter $wbResultsDataPath \
                                                  cp1 cp2 cp3] }  {
      ok_err_msg "Failed massaging color parameters in record '$dataArr($pureName)' for '$pureName' in '$wbResultsDataPath'"
      return  0
    }

    if { $WBPARAMS_EQU_OPTIONAL_CALLBACK != 0 }  {
      set wbParams1 [list $cp1 $cp2]
      if { [WBParam3IsUsed] }  { lappend wbParams1 $cp3 }
      set wbParams2 [list $scp1 $scp2]
      if { [WBParam3IsUsed] }  { lappend wbParams2 $scp3 }
      set allEqu [$WBPARAMS_EQU_OPTIONAL_CALLBACK $wbParams1 $wbParams2]
    } else {
      set allEqu [expr { ($cp1 == $scp1) && ($cp2 == $scp2) && \
                         ((0 == [WBParam3IsUsed]) || ($cp3 == $scp3)) }]
    }
    if { $allEqu == 0 }   {
      ok_err_msg "Mismatch in WB parameters for '$pureName': {$cp1 $cp2 $cp3} in the datafile ($wbResultsDataPath) vs {$scp1 $scp2 $scp3} in the settings file ($sP)"
      return  0
    }
  }
  ok_info_msg "WB parameters match between converter settings ([llength $settingsPaths] file(s)) and datafile"
  return  1
}


# Verifies new settings files for images with overriden depth
proc CheckChangedUltimatePhotosSettings {pathDict oldDepthOvrdPath \
                                          changedPurenames}  {
  global CONVERTER_NAME
  set newDepthOvrdPath [dict get $pathDict     "DATAFILE-DEPTH-OVRD"]
  set newSettingsPaths [dict get $pathDict     "SETTINGS-PHOTOS"]
  set lastTrashDir     [dict get $pathDict     "TRASH-DIR"]
  array unset nameToDepthOld;   array unset nameToDepthNew
  if { 0 >= [TopUtils_ReadDepthsFromDepthOverrideCSVs "pure-name" \
                          nameToDepthOld nameToDepthNew $oldDepthOvrdPath] }  {
    return  0;  # error already printed
  }
  set purenamesNewSettings [BuildSortedPurenamesList $newSettingsPaths]
  # additional filtering for the case of std settings dir (all settings together)
  set oldSettingsPaths [FilterFilepathListByRegexp "[KeyStr_Photo]" \
                            [dict get $pathDict "SETTINGS-ALL-PREV-MATCHED"] 1]
  set purenamesOldSettings [BuildSortedPurenamesList $oldSettingsPaths]
  set purenamesChangedDepths [lsort $changedPurenames]
  if { 0 == [_SortedListsEQU $purenamesChangedDepths $purenamesOldSettings] }  {
    ok_err_msg "Name list mismatch between changed-depth- {$purenamesChangedDepths} and before-override- settings files {$purenamesOldSettings}; old settings read from '$lastTrashDir'"
    return  0
  }
  # check counts, especially for > 0
  if { (0 < [llength $oldSettingsPaths]) && (0 == [llength $newSettingsPaths]) } {
    ok_err_msg "No new settings files after processing depth override"
    return  0
  }
  # verify there's new settings file for each old one, and the former is newer
  set newSettingsDir [file dirname [lindex $newSettingsPaths 0]]; # same for all
  foreach oS $oldSettingsPaths {
    set nameAndExt [file tail $oS]
    set purename [AnyFileNameToPurename $nameAndExt]
    #set pattern [file join $newSettingsDir $nameAndExt]
    set pattern "*$nameAndExt*";  # TODO: or maybe use $purename
    # search for name with "glob" works; for path with "exact" fails on "./<name>"
    set nSIdx [lsearch -glob $newSettingsPaths $pattern]; # slow; OK for test 
    if { $nSIdx < 0 }  {
      ok_err_msg "No new setting file (converter: $CONVERTER_NAME) after processing depth override for '$purename' (expected: '$nameAndExt')"
      ok_trace_msg "New setting file(s): {$newSettingsPaths}"
      return  0      
    }
    set nS [lindex $newSettingsPaths $nSIdx]
    # compare access time - the order of events is: (1) move-old, (2) modify-new
    set timeCmp [CompareFileDates $oS $nS]
    if { $timeCmp > 0 }  {
      ok_err_msg "Settings file before-override ('$oS') is newer than its peer after-override ('$nS')"
      return  0
    }
    # 
    if { 0 == [info exists nameToDepthOld($purename)] }  {
      ok_err_msg "Missing old depth-override record for '$purename'"
      return  0
    }
    if { 0 == [info exists nameToDepthNew($purename)] }  {
      ok_err_msg "Missing new depth-override record for '$purename'"
      return  0
    }
    set oDepth $nameToDepthOld($purename);  set nDepth $nameToDepthNew($purename)
    if { 1 != [SettingsFilesAreConsistent $oDepth $oS $nDepth $nS] } { return 0 }
  }
  ok_info_msg "All [llength $oldSettingsPaths] settings file(s) before-override are older than their peer(s) after-override and change in colors is consistent with change in depth."
  return  1
}


proc _MixUltimatePhotosAndWBTargetsData {photoDatafilePath targDatafilePath} {
  # both lists should be sorted by depths; results' file is not
  # a result record: "pure-name,global-time,depth,wb1,wb2[,wb3]"
  # TODO: how to generalize column index?
  set listPh [sort_csv_file_by_numeric_column $photoDatafilePath 2 \
                                              "gray-targets' colors"]
  set listTr [ok_read_csv_file_into_list_of_lists $targDatafilePath " " "#" \
                                                        "CheckDepthColorRecord"]

  set iPh 1; set iTr 1;  # comments dropped; indices start from 1 to skip header
  set HUGE_DEPTH 99999.99
  set merged [list];  # or, to have a header:  [list [lindex $listPh 0]]
  while { ($iPh < [llength $listPh]) || ($iTr < [llength $listTr]) }  {
    # append to result the record with smallest depth among the two lists
    if { $iPh < [llength $listPh] } {
      set nextRecPh [lindex $listPh $iPh]
      if { 0== [ParseDepthColorRecord $nextRecPh nmP tmP depthP c1P c2P c3P] } {
        ok_err_msg "Invalid line $iPh in '$photoDatafilePath'";  return  0
      }
    } else {
      set depthP $HUGE_DEPTH;  # too large to be picked
    }
    if { $iTr < [llength $listTr] } {
      set nextRecTr [lindex $listTr $iTr]
      if { 0== [ParseDepthColorRecord $nextRecTr nmT tmT depthT c1T c2T c3T] } {
        ok_err_msg "Invalid line $iTr in '$targDatafilePath'";  return  0
      }
    } else {
      set depthT $HUGE_DEPTH;  # too large to be picked
    }
    if { ($depthP < $depthT) && ($depthP < $HUGE_DEPTH) } {
      lappend merged $nextRecPh;  incr iPh 1
    } elseif { $depthT < $HUGE_DEPTH } {
      lappend merged $nextRecTr;  incr iTr 1
    }
  }
  ok_trace_msg "Merged list of photos and WB-targets has [llength $merged] elements"
  return  $merged
}


proc _SimulateDepthOverride {pathDict} {
  set depthOvrdDataPath [dict get $pathDict "DATAFILE-DEPTH-OVRD"]
  set ovrdPurenamesOrZero [SimulateDepthOverride $depthOvrdDataPath]
  return  $ovrdPurenamesOrZero
}


proc CheckDepthOvrdInUltimateWBData {pathDict changedPurenames}  {
  set wbResultsDataPath [dict get $pathDict "DATAFILE-RESULT-COLORS"]
  set resDataList [ok_read_csv_file_into_list_of_lists $wbResultsDataPath " " \
                                                                          "#" 0]
  if { $resDataList == 0 }  {
    ok_err_msg "Failed reading ultimate WB data from '$wbResultsDataPath'"
    return  0
  }
  set depthOvrdDataPath [dict get $pathDict "DATAFILE-DEPTH-OVRD"]
  # depth-override array:
  #   pure-name::{global-time,min-depth,max-depth,estimated-depth,depth}
  array unset depthOvrdArr; # essential init
  if { 0 == [ok_read_csv_file_into_array_of_lists depthOvrdArr \
                          $depthOvrdDataPath " " "CheckDepthOverrideRecord"] } {
    ok_err_msg "Failed reading depth-override data from '$depthOvrdDataPath'"
    return  0
  }
  # verify that the resulting depth is either as estimated or as overriden
  foreach rec [lrange $resDataList 1 end]  { ;  # skip header
    if { 0 == [ParseDepthColorRecord $rec purename tm depth c1 c2 c3] } {
      ok_err_msg "Invalid line '$rec' in '$wbResultsDataPath'";  return  0
    }
    set listedAsChanged [expr {0 <= [lsearch -exact $changedPurenames $purename]}]
    set isOverriden 0
    if { 1 == [info exists depthOvrdArr($purename)] }  {
      TopUtils_ParseDepthOverrideRecord depthOvrdArr $purename \
                          globalTime minDepth maxDepth estimatedDepth ovrdDepth
      if { $ovrdDepth != $estimatedDepth }  { ; # overriden in depth-ovrd file
        set isOverriden 1
        if { $depth != $ovrdDepth }  {
          ok_err_msg "Depth-override to $ovrdDepth ignored for '$purename' (got $depth instead)"
          return  0
        }
      } elseif { $listedAsChanged == 1 }  {
        ok_err_msg "Depth-override for '$purename' not found in '$depthOvrdDataPath'"
        return  0
      }
    }
  } ;  # foreach rec
  # TODO: if the old version of the result-colors datafile become preserved, check consistency vs it
  ok_info_msg "Depth-override did affect correctly the result-colors data"
  return  1
}


# Checks that unmatched inputs are hidden (for per-dive settings dir)
# or preserved (for standard settings dir).
proc CheckUnmatchedInputsTreatment {pathDictOld pathDictNew \
                                      verifyTargets verifyPhotos} {
  global SETTINGS_DIR
  if { $SETTINGS_DIR == "" }  { ;   #  per-dive settings dir
    return  [_VerifyUnmatchedInputsAreHidden    $pathDictOld $pathDictNew \
                                                $verifyTargets $verifyPhotos]
  } else {  ;   # standard settings dir
    return  [_VerifyUnmatchedInputsArePreserved $pathDictOld $pathDictNew \
                                                $verifyTargets $verifyPhotos]
  }
}


# Intended for RAW converters with per-dive settings directory
# 1) Settings files with "[KeyStr_Unmatched]" in the name must not appear
#  in raw-phtoo directory and gray-target directory.
# 2) RAW files with "[KeyStr_Unmatched]" in the name must not appear
#  in raw-photo directory and gray-target directory; otherwise UWIC aborts.
# 3) All files (in trash-dir) with "[KeyStr_Unmatched]" in the name are settings files
# 4) All settings files that were unmatched appear in trash-dir
proc _VerifyUnmatchedInputsAreHidden {pathDictOld pathDictNew \
                                      verifyTargets verifyPhotos} {
  # (1)
  set allGTSettings [dict get $pathDictNew "SETTINGS-WB-TARGETS"]
  set allPHSettings [dict get $pathDictNew "SETTINGS-PHOTOS"]
  if { 0 == [_VerifyNoUnmatchedInputsInWorkArea $allGTSettings $allPHSettings \
                              "settings file" $verifyTargets $verifyPhotos] }  {
    return  0;  # error already printed
  }
  # (2)
  set allGTRAWs [dict get $pathDictNew "WB-TARGETS"]
  set allPHRAWs [dict get $pathDictNew "PHOTOS"]
  if { 0 == [_VerifyNoUnmatchedInputsInWorkArea $allGTRAWs $allPHRAWs \
                              "RAW file" $verifyTargets $verifyPhotos] }  {
    return  0;  # error already printed
  }
  # (3)
  set trashDir [dict get $pathDictNew "TRASH-DIR"]
  set trashDirDescr "trash/backup directory '$trashDir'"
  set allUnmatchedInTrash [BuildFilepathListFromRegexp  "[KeyStr_Unmatched]" \
                                                        $trashDir]
  foreach f $allUnmatchedInTrash {
    if { 0 == [IsSettingsFileName [file tail $f]] }  {
      ok_err_msg "Unmatched input file '$f' in $trashDirDescr is not a settings file"
      return  0
    }
  }
  if { 0 < [llength $allUnmatchedInTrash] }  {
    ok_info_msg "All [llength $allUnmatchedInTrash] unmatched input file(s) in $trashDirDescr is/are settings file(s)"
  } else {
    ok_info_msg "No unmatched input file(s) found in $trashDirDescr"
  }
  # (4)
  set allSettingsOld [_PickRelevantSettingsFiles $pathDictOld \
                                                  $verifyTargets $verifyPhotos]
  set allUnmatchedSettingsOld [BuildSortedPurenamesList \
            [FilterFilepathListByRegexp "[KeyStr_Unmatched]" $allSettingsOld 1]]
  set allUnmatchedSettingsTrash [BuildSortedPurenamesList \
            [dict get $pathDictNew "SETTINGS-ALL-PREV-UNMATCHED"]]
  if { 0 == [_SortedListsEQU  $allUnmatchedSettingsOld \
                              $allUnmatchedSettingsTrash] } {
    ok_err_msg "Mismatch in presense of unmatched settings files - before action vs $trashDirDescr"
    ok_err_msg "Unmatched settings files - before action: {$allUnmatchedSettingsOld}"
    ok_err_msg "Unmatched settings files - in $trashDirDescr: {$allUnmatchedSettingsTrash}"
    return  0
  }
  ok_info_msg "Unmatched input file(s) is/are properly stored in $trashDirDescr"
  return  1
}


# Intended for RAW converters with standard settings directory
# 1) All settings files that were unmatched still appear in the settings dir
# 2) ?not-needed? All files (in settings dir) with "[KeyStr_Unmatched]"
#    in the name are settings files
proc _VerifyUnmatchedInputsArePreserved {pathDictOld pathDictNew \
                                      verifyTargets verifyPhotos} {
  global SETTINGS_DIR
  set allSettingsOld [_PickRelevantSettingsFiles $pathDictOld \
                                                  $verifyTargets $verifyPhotos]
  set allUnmatchedSettingsOld [BuildSortedPurenamesList \
            [FilterFilepathListByRegexp "[KeyStr_Unmatched]" $allSettingsOld 1]]
  set allSettingsNew [_PickRelevantSettingsFiles $pathDictNew \
                                                  $verifyTargets $verifyPhotos]
  set allUnmatchedSettingsNew [BuildSortedPurenamesList \
            [FilterFilepathListByRegexp "[KeyStr_Unmatched]" $allSettingsNew 1]]
  if { 0 == [llength $allUnmatchedSettingsOld] }  {
    ok_info_msg "There were no unmatched settings files before the last action"
  } else {
    if { 0 == [_FilteredListIsSubset \
                        $allUnmatchedSettingsOld $allUnmatchedSettingsNew] }  {
      ok_err_msg "Mismatch in presense of unmatched settings files - before- vs after the last action"
      ok_err_msg "Unmatched settings files - before action: {$allUnmatchedSettingsOld}"
      ok_err_msg "Unmatched settings files - after action: {$allUnmatchedSettingsNew}"
      return  0
    }
  }
  # TODO? (2)
  return  1
}


proc _PickRelevantSettingsFiles {pathDict listTargets listPhotos}  {
  set allGTSettings [dict get $pathDict "SETTINGS-WB-TARGETS"]
  set allPHSettings [dict get $pathDict "SETTINGS-PHOTOS"]
  set allSettings [expr {($listTargets == 1)? $allGTSettings : [list]}]
  if { $listPhotos == 1 }  {
    set allSettings [concat $allSettings $allPHSettings]
  }
  return  $allSettings
}


# 'allGTInputs' 'allPHInputs' are lists of all RAWs or settings
# Verifies that inputs (RAWs or settings)
# with "[KeyStr_Unmatched]" in the name do not appear
#  in raw-phtoo directory and gray-target directory.
# 'rawORsettingsDescr' == "RAW file" or "settings file"
proc _VerifyNoUnmatchedInputsInWorkArea {allGTInputs allPHInputs \
                               rawORsettingsDescr verifyTargets verifyPhotos} {
  global SETTINGS_DIR
  set descrSingle $rawORsettingsDescr
  set descrPlural [format "%s(s)" $rawORsettingsDescr]
  if { $verifyTargets != 0 }  {
    if { 0 == [llength $allGTInputs] } {
      ok_err_msg "_VerifyNoUnmatchedInputsInWorkArea got no gray-target $descrPlural"
      return  0
    }
    set unmatchedGTInputs [FilterFilepathListByRegexp \
                                          "[KeyStr_Unmatched]" $allGTInputs 1]
    if { 0 != [llength $unmatchedGTInputs] } {
      if { ($SETTINGS_DIR != "") && \
           ([string equal -nocase $rawORsettingsDescr "settings file"]) }  {
        ok_info_msg "Presense of [llength $unmatchedGTInputs] gray-target $descrPlural is valid for converter '[GetRAWConverterName]' with standard settings directory '$SETTINGS_DIR'"
      } else {
        ok_err_msg "_VerifyNoUnmatchedInputsInWorkArea found [llength $unmatchedGTInputs] gray-target $descrPlural: {$unmatchedGTInputs}"
        return  0
      }
    }
    ok_info_msg "No unmatched gray-target $descrPlural found in the work-directory"
  }
  if { $verifyPhotos != 0 }  {
    if { 0 == [llength $allPHInputs] } {
      ok_err_msg "_VerifyNoUnmatchedInputsInWorkArea got no ultimate-photo $descrPlural"
      return  0
    }
    set unmatchedPHInputs [FilterFilepathListByRegexp \
                                          "[KeyStr_Unmatched]" $allPHInputs 1]
    if { 0 != [llength $unmatchedPHInputs] } {
      if { ($SETTINGS_DIR != "") && \
           ([string equal -nocase $rawORsettingsDescr "settings file"]) }  {
        ok_info_msg "Presense of [llength $unmatchedPHInputs] ultimate-photo $descrPlural is valid for converter '[GetRAWConverterName]' with standard settings directory '$SETTINGS_DIR'"
      } else {
        ok_err_msg "_VerifyNoUnmatchedInputsInWorkArea found [llength $unmatchedPHInputs] ultimate-photo $descrPlural: {$unmatchedPHInputs}"
        return  0
      }
    }
    ok_info_msg "No unmatched ultimate-photo $descrPlural found in the work-directory"
  }
  return  1
}


proc VerifyInputsPreserved {pathDictOld pathDictNew verifyTargets verifyPhotos} {
  global SETTINGS_DIR
  CountInputs $pathDictOld  \
                      nTargRAWsOld nPhotoRAWsOld                           \
                      nTargSettingsOld nPhotoSettingsOld                   \
                      nUnmatchedTargRAWsOld nUnmatchedPhotoRAWsOld         \
                      nUnmatchedTargSettingsOld nUnmatchedPhotoSettingsOld
  CountInputs $pathDictNew  \
                      nTargRAWsNew nPhotoRAWsNew                           \
                      nTargSettingsNew nPhotoSettingsNew                   \
                      nUnmatchedTargRAWsNew nUnmatchedPhotoRAWsNew         \
                      nUnmatchedTargSettingsNew nUnmatchedPhotoSettingsNew
  # hide differences for non-requested inputs
  if { $verifyTargets == 0 }  {
    set nTargRAWsOld 0;           set nTargSettingsOld 0
    set nUnmatchedTargRAWsOld 0;  set nUnmatchedTargSettingsOld 0
    set nTargRAWsNew 0;           set nTargSettingsNew 0
    set nUnmatchedTargRAWsNew 0;  set nUnmatchedTargSettingsNew 0
  }
  if { $verifyPhotos == 0 }  {
    set nPhotoRAWsOld 0;           set nPhotoSettingsOld 0
    set nUnmatchedPhotoRAWsOld 0;  set nUnmatchedPhotoSettingsOld 0
    set nPhotoRAWsNew 0;           set nPhotoSettingsNew 0
    set nUnmatchedPhotoRAWsNew 0;  set nUnmatchedPhotoSettingsNew 0
  }
  if { $SETTINGS_DIR == "" }  {  ;  # settings are in work-area (per-dive)
    # unmatched settings should have disappeared
    if { ($nUnmatchedTargSettingsNew !=0) || ($nUnmatchedPhotoSettingsNew !=0) } {
      ok_err_msg "Unmatched settings file(s) found in work directory - $nUnmatchedTargSettingsNew for gray-targets, $nUnmatchedPhotoSettingsNew for ultimate photos"
      ok_err_msg  [FormatOldAndNewWorkAreaStuff $pathDictOld $pathDictNew]
      return  0
    }
    ok_info_msg "No unmatched settings file(s) found in work directory; removed unmatched settings: $nUnmatchedTargSettingsOld for gray-targets, $nUnmatchedPhotoSettingsOld for ultimate photos"
  } else {  ; # settungs are in standard dir (all)
    # unmatched settings are undetectable; should have been preserved
    if { ($nUnmatchedTargSettingsOld !=0 ) && 
         ($nUnmatchedTargSettingsNew != $nUnmatchedTargSettingsOld) } {
      ok_err_msg "Unmatched settings file(s) for gray-targets disappeared from '$SETTINGS_DIR' - $nUnmatchedTargSettingsOld before vs $nUnmatchedTargSettingsNew after"
      ok_err_msg  [FormatOldAndNewWorkAreaStuff $pathDictOld $pathDictNew]
      return  0
    }
    if { ($nUnmatchedPhotoSettingsOld !=0 ) && 
         ($nUnmatchedPhotoSettingsNew != $nUnmatchedPhotoSettingsOld) } {
      ok_err_msg "Unmatched settings file(s) for ultimate photos disappeared from '$SETTINGS_DIR' - $nUnmatchedPhotoSettingsOld before vs $nUnmatchedPhotoSettingsNew after"
      ok_err_msg  [FormatOldAndNewWorkAreaStuff $pathDictOld $pathDictNew]
      return  0
    }
  }
  # everything "matched" should have been preserved
  set nMatchedTargRAWsOld [expr $nTargRAWsOld - $nUnmatchedTargRAWsOld]
  set nMatchedPhotoRAWsOld [expr $nPhotoRAWsOld - $nUnmatchedPhotoRAWsOld]
  set nMatchedTargSettingsOld [expr $nTargSettingsOld - $nUnmatchedTargSettingsOld]
  set nMatchedPhotoSettingsOld [expr $nPhotoSettingsOld - $nUnmatchedPhotoSettingsOld]
  set nMatchedTargRAWsNew [expr $nTargRAWsNew - $nUnmatchedTargRAWsNew]
  set nMatchedPhotoRAWsNew [expr $nPhotoRAWsNew - $nUnmatchedPhotoRAWsNew]
  set nMatchedTargSettingsNew [expr $nTargSettingsNew - $nUnmatchedTargSettingsNew]
  set nMatchedPhotoSettingsNew [expr $nPhotoSettingsNew - $nUnmatchedPhotoSettingsNew]
  if { $nMatchedTargRAWsNew != $nMatchedTargRAWsOld }  {
    ok_err_msg "Mismatched count of gray-target RAW files for which settings files should exist: new=$nMatchedTargRAWsNew, old=$nMatchedTargRAWsOld"
    ok_err_msg  [FormatOldAndNewWorkAreaStuff $pathDictOld $pathDictNew]
    return  0
  }
  if { $nMatchedPhotoRAWsNew != $nMatchedPhotoRAWsOld }  {
    ok_err_msg "Mismatched count of ultimate photo RAW files for which settings files should exist: new=$nMatchedPhotoRAWsNew, old=$nMatchedPhotoRAWsOld"
    ok_err_msg  [FormatOldAndNewWorkAreaStuff $pathDictOld $pathDictNew]
    return  0
  }
  if { $nMatchedTargSettingsNew != $nMatchedTargSettingsOld }  {
    ok_err_msg "Mismatched count of gray-target settings files for which RAW files should exist: new=$nMatchedTargSettingsNew, old=$nMatchedTargSettingsOld"
    ok_err_msg  [FormatOldAndNewWorkAreaStuff $pathDictOld $pathDictNew]
    return  0
  }
  if { $nMatchedPhotoSettingsNew != $nMatchedPhotoSettingsOld }  {
    ok_err_msg "Mismatched count of ultimate photo settings files for which RAW files should exist: new=$nMatchedPhotoSettingsNew, old=$nMatchedPhotoSettingsOld"
    ok_err_msg  [FormatOldAndNewWorkAreaStuff $pathDictOld $pathDictNew]
    return  0
  }
  ok_info_msg "Counts of all RAW and settings files where RAW and settings should match are preserved"
  return  1
}