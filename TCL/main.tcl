# main.tcl - detect colors of all files in dir

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "read_img_metadata.tcl"]
source [file join $SCRIPT_DIR   "Parse_CSV_65433-1.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]
source [file join $SCRIPT_DIR   "color_math.tcl"]

source [file join $SCRIPT_DIR   "grey_targets.tcl"]
source [file join $SCRIPT_DIR   "raw_manip.tcl"]
source [file join $SCRIPT_DIR   "toplevel_utils.tcl"]
source [file join $SCRIPT_DIR   "raw_converters.tcl"]


set IMAGE_DATA_HEADER_CMULT [list "global-time" "depth" "mRneu" "mGneu" "mBneu"] ;  # color multipliers
##set IMAGE_DATA_HEADER_CTEMP [list "global-time" "depth" "color-temp" "color-tint"] ;  # color temperature


set RESULT_DATA_FILE        "result_colors.csv"
set RESULT_DIR              "PREVIEW"

# Returns path of the file with color data for the ultimate images
proc FindResultData {} {
  global DATA_DIR RESULT_DATA_FILE
  if { 0 == [file exists $DATA_DIR] } {
    file mkdir $DATA_DIR
  }
  return  [file join $DATA_DIR $RESULT_DATA_FILE]
}


# Returns path of the directory for ultimate converted images
proc FindResultDir {} {
  global RESULT_DIR
  if { 0 == [file exists $RESULT_DIR] } {
    file mkdir $RESULT_DIR
  }
  return  $RESULT_DIR
}


# Extracts thumbnails from all RAWs in the work-dir. Returns "" on success.
# On error returns error message.
proc ExtractThumbsFromAllRaws {} {
  return  [ExtractThumbsFromRaw [FindRawInputs "."]]
 }

proc SortAllRawsByThumbnails {} {
  return  [SortRawsByThumbnails [FindRawInputs "."]]
}


# Input: dive-log and neutral-point-neutralized settings-files for gray targets
# Outputs: image-to-depth mapping, depth-to-WB mapping, depth-ovrd template
proc ProcessDepthData {{ignoreGrayTargetsFile 0}}  {
  global SETTINGS_DIR WORK_DIR
  ok_info_msg "Preconditions for gray targets' processing:"
  ok_info_msg "  (1) Gray-point neutralization performed on all WB-targets"
  ok_info_msg "  (2) The dive-log is in '[FindSavedLog 0]'"
  
  InitGrayTargetData;   # avoid including data from previous runs
  if { 0 == [DepthLogRead__SubsurfaceCSV  logTimeList logDepthList] }  {
    set msg "Aborted because of empty or unreadable dive log <[FindSavedLog]>"
    ok_err_msg $msg;    return  $msg
  }

  if { $SETTINGS_DIR == "" } { ; # per-dive - detecting unmatched settings is doable
    set trashDirPath "";  # the 1st proc involving it will choose the path
    set msg [HideUnmatchedRAWsAndSettingsFilesForGrayTargets \
                                              "Map-Depth-To-Color" trashDirPath]
    if { $msg != "" } { return  $msg } ;   # error already printed
  } else {  ;   # standard settings dir; cannot detect unmatched settings
    if { 0 < [FindUnmatchedRAWsAndSettingsFiles $WORK_DIR \
                                            unmatchedRAWs unmatchedSettings] }  {
      if { 0 != [llength $unmatchedRAWs] }  {
        set msg "Missing settings files for [llength $unmatchedRAWs] RAWs; aborting"
        ok_err_msg $msg;    return  $msg
      }
    }
  }
  set settingsPathList [FindRawColorTargetsSettingsForDive 1]
  set nSettingsFiles [llength $settingsPathList]
  set cnt [ReadWBAndMapToDepth $settingsPathList $logTimeList $logDepthList]
  if { $cnt < [expr $nSettingsFiles / 2] }  {
    set msg "Failed processing [expr $nSettingsFiles - $cnt] out of $nSettingsFiles conversion-settings file(s); please check your inputs and rerun"
    ok_err_msg $msg;    return  $msg
  }
   
  if { 0 == [SortGreyTargetResults] }   {
    set msg "Aborted because of failure to sort WB-targets' data"
    ok_err_msg $msg;    return  $msg
  }
     
  TopUtils_GenerateDepthOverrideTemplate $logTimeList $logDepthList
  
  set msg "";   # as if it succeeds
  if { ($ignoreGrayTargetsFile == 0) && \
       (1 == [file exists [FindFilteredGreyData]]) }  {
    ok_warn_msg "File with filtered gray target data pre-existed; not overriden"
  } else {
    if { 1 == [FilterGraySamples] } {
      ok_info_msg "Generated a usable subset of consistent WB readings in '[FindFilteredGreyData]' ========"    } else {
      file copy -force  [FindSortedGreyData]  [FindFilteredGreyData]
      set msg "Failed to automatically generate a usable subset of consistent WB readings"
      ok_err_msg $msg
      ok_info_msg "==== Now drop the bad readings in '[FindFilteredGreyData]' ========"
      ok_info_msg "==== Bad are readings that look unsatisfactory when normalized ========"
      ok_info_msg "==== Bad are readings that spoil a curve in gnuplot ======="
    }
  }

  ok_info_msg "====== Below are the suggested gnuplot commands that help analyzing gray target data ======"
  ok_info_msg [format {unset logscale y;  plot '%s' using 3:4 title 'WB-Param-1' with lines, '%s' using 3:4 title 'WB-Param-1-ALL'} \
                [FindFilteredGreyData] [FindSortedGreyData]]
  ok_info_msg [format {unset logscale y;  plot '%s' using 3:5 title 'WB-Param-2' with lines, '%s' using 3:5 title 'WB-Param-2-ALL'} \
                [FindFilteredGreyData] [FindSortedGreyData]]
  if { [WBParam3IsUsed] }  {
    ok_info_msg [format {unset logscale y;  plot '%s' using 3:6 title 'WB-Param-3' with lines, '%s' using 3:6 title 'WB-Param-3-ALL'} \
                  [FindFilteredGreyData] [FindSortedGreyData]]
  }
  return  $msg;   # 'msg' holds empty message on success
}


proc ProcessUltimateRAWs_Dcraw {} {
  if { 0 == [DepthLogRead__SubsurfaceCSV  logTimeList logDepthList] }  {
    ok_err_msg "Aborted because of empty dive log"
    return  0;  # error already printed
  }
  if { -1 == [ReadGreyTargetResults_Dcraw  colorDepthList colorMultListRGB] }  {
    return  0;  # error already printed
  }
  
  if { 0 == [FindAllRawColorMults $colorDepthList $colorMultListRGB \
                                $logTimeList $logDepthList]}  {
    return  0;  # error already printed
  }
  
  return  [ConvertAllRawsUsingStoredColorMults]
}


proc ProcessUltimateRAWs {{onlyChanged 0}} {
  global SETTINGS_DIR
  set actionName [expr {($onlyChanged == 0)?  "Process-All-Photos" : \
                                              "Process-Changed-Photos"}]
  if { 0 == [DepthLogRead__SubsurfaceCSV  logTimeList logDepthList] }  {
    set msg "Aborted because of empty dive log";    ok_err_msg $msg
    return  $msg;  # error already printed
  }
  if { -1 == [ReadGreyTargetResults  colorDepthList wbParamsList] }  {
    return  "Failed reading depth-to-color mapping";  # error already printed
  }

  set trashDirPath "" ;   # the 1st proc involving it will choose the path
  CleanDepthOverrideFiles $actionName trashDirPath
  ok_trace_msg "Trash/backup dir path is '$trashDirPath'"

  if { $SETTINGS_DIR == "" } { ; # per-dive, thus detecting unmatched is doable
    set msg [HideUnmatchedRAWsAndSettingsFilesForUltimatePhotos \
                                                      $actionName trashDirPath]
    if { $msg != "" } { ok_err_msg $msg;  return  $msg } 
  }  

if { 0 == [FindAllRawWBParams $colorDepthList $wbParamsList \
                                $logTimeList $logDepthList $onlyChanged]}  {
    return  "Failed computing WB settings for ultimate photos";  # error already printed
  }
  
  set res [OverrideAllRawsSettingsWithStoredWBParams trashDirPath \
                                                              $onlyChanged]
  SaveLastDepthOverrides
  return  $res
}


# Computes color-multipliers for all RAWs under the predefined dir.
# Outputs the results into a predefined CSV file.
# TODO: If a predefined depth-override CSV file exists, takes depths from there (could be a subset).
# Returns number of RAW files processed.
proc FindAllRawColorMults {colorDepthList colorMultListRGB \
                            logTimeList logDepthList} {
  global IMAGE_DATA_HEADER_CMULT
  if { 0 == [FindRawInputsOrComplain "" allRaws] } { ; # ultimate photos are in work-dir
    return  0;  # error already printed
  }
  set cntGood 0
  array unset dataArr ; # pure-name::{time,depth,mRneu,mGneu,mBneu[,mRcld,mGcld,mBcld]}
  # set header for the CSV
  set dataArr("pure-name")  $IMAGE_DATA_HEADER_CMULT

  foreach rawPath $allRaws {
    set pureName [file rootname [file tail $rawPath]]
    if { 0 == [TopUtils_FindDepth $pureName $rawPath \
                              $logTimeList $logDepthList globalTime depth] }  {
      continue;  # error already printed
    }
    incr cntGood 1
    set colorMults [ComputeColorMultsAtDepth $depth \
                                             $colorDepthList $colorMultListRGB]
    ParseColorMultsForConverter $colorMultListRGB mR mG mB
    set dataArr($pureName)  [list $globalTime $depth $mR $mG $mB]
    ok_trace_msg "(photo) $pureName,$globalTime,$depth,$mR,$mG,$mB"
  }

  ok_info_msg "going to write grey-targets data into '[FindResultData]'"
  ok_write_array_of_lists_into_csv_file dataArr [FindResultData] "pure-name" " "
  ok_info_msg "Color multipliers for $cntGood image(s) printed into '[FindResultData]'"
  return  $cntGood
}


# Computes WB params for all RAWs under the predefined dir.
# Outputs the results into a predefined CSV file.
# Returns number of RAW files processed.
proc FindAllRawWBParams {colorDepthList wbParamsList \
                            logTimeList logDepthList {onlyChanged 0}} {
  global IMAGE_DATA_HEADER_RCONV
  global iiDepthOvrdDepth iiDepthOvrdGlobalTime
  if { 0 == [FindRawInputsOrComplain "" allRaws] } { ; # ultimate photos are in work-dir
    return  0;  # error already printed
  }
  array unset depthOvrdArr; # essential init  pure-name::{global-time,min-depth,max-depth,estimated-depth,depth}
  set imagesWithChangedOvrd [_ReadDepthOverridesAndListImagesWhereChanged \
                              depthOvrdArrOld depthOvrdArr];  # msg if none
  if { ($imagesWithChangedOvrd  == -1) }  {
    return  0;  # error already printed
  }
  array unset arrChangedOvrd;   # pure-name::1; for faster search
  foreach pureName $imagesWithChangedOvrd  { set arrChangedOvrd($pureName) 1 }

  set cntGood 0
  array unset dataArr ; # pure-name::{time,depth,colorTemp,colorTint1,colorTint2}
  # set header for the CSV
  set dataArr("pure-name")  $IMAGE_DATA_HEADER_RCONV

  foreach rawPath $allRaws {
    set pureName [file rootname [file tail $rawPath]]
    if { ($onlyChanged != 0) && (0 == [info exists arrChangedOvrd($pureName)]) } {
      ok_trace_msg "'$pureName' has no change in depth-override"
      # still compute it - for simplicity
    }
    if { 1 == [TopUtils_ParseDepthOverrideRecord depthOvrdArr $pureName \
                      globalTime minDepth_ maxDepth_ estimatedDepth_ depth] }  {
      ok_info_msg "Using depth override for $pureName : $depth"
    } else {
      if { 0 == [TopUtils_FindDepth $pureName $rawPath \
                                $logTimeList $logDepthList globalTime depth] } {
        continue;  # error already printed
      }
    }
    incr cntGood 1
    set wbParamsRecord [ComputeWBParamsAtDepth $depth \
                                               $colorDepthList $wbParamsList]
    ParseWBParamsForConverter $wbParamsRecord wbParam1 wbParam2 wbParam3
    # wbParam3 == -1 if irrelevant
    # TODO: Pack
    set dataArr($pureName)  [PackDepthColorNoNameRecord \
                              $globalTime $depth $wbParam1 $wbParam2 $wbParam3]
    ok_trace_msg "(photo) $pureName,$globalTime,$depth,$wbParam1,$wbParam2,$wbParam3"
  }

  ok_info_msg "going to write ultimate images' data into '[FindResultData]'"
  ok_write_array_of_lists_into_csv_file dataArr [FindResultData] "pure-name" " "
  ok_info_msg "WB parameters for $cntGood image(s) printed into '[FindResultData]'"
  return  $cntGood
}


# Converts all RAW images in the work directory
# using color multipliers from a predefined data file.
# Returns number of images converted.
proc ConvertAllRawsUsingStoredColorMults {}  {
  global CONV_MODE_PREVIEW
  set allRaws [FindRawInputs ""];  # ultimate photos are in work-dir
  if { 0 == [llength $allRaws] } {
    ok_err_msg "No RAW inputs found in '[pwd]'"
    return  0
  }
  set dataPath [FindResultData]
  if { 0 == [file exists $dataPath] } {
    ok_err_msg "No color data found in '$dataPath'"
    return  0
  }
  if { 0 == [ok_read_csv_file_into_array_of_lists dataArr $dataPath " " \
                                                  "CheckDepthColorRecord"] } {
    ok_err_msg "Failed reading color data from '$dataPath'"
    return  0
  }
  # dataArr == pure-name::{time,depth,mRneu,mGneu,mBneu[,mRcld,mGcld,mBcld]}
  ##parray dataArr
  set cntGood 0
  set outDir [FindResultDir]
  ok_info_msg "Start converting [llength $allRaws] RAW image(s) in '[pwd]'"
  foreach rawPath $allRaws {
    set pureName [file rootname [file tail $rawPath]]
    if { 0 == [info exists dataArr($pureName)] } {
      ok_err_msg "No color data found for '$pureName'";      continue
    }
    ParseDepthColorNoNameRecord_Mults $dataArr($pureName) time depth mR mG mB
    if { 1 ==[ConvertOneRaw $CONV_MODE_PREVIEW $rawPath $outDir $mR $mG $mB] } {
      incr cntGood 1
    } ;  # else: error already printed
  }
  set msg "Converted $cntGood out of [llength $allRaws] RAW image(s) in '[pwd]'"
  if { $cntGood > 0 }  { ok_info_msg $msg } else { ok_warn_msg $msg } 
  return  $cntGood
}


# Overrides WB parameters in all RAW settings files in the work directory
# using color data from a predefined data file.
# Returns number of files processed.
proc OverrideAllRawsSettingsWithStoredWBParams {trashDirPathVar \
                                                {onlyChanged 0}}  {
  upvar $trashDirPathVar trashDirPath
  if { 0 == [FindSettingsFilesOrComplain "" allSettings] } { ; # ultimate photos are in work-dir
    return  0;  # error already printed
  }
  #~ set allSettings [FindSettingsFilesForDive "" cntMissing 1]; # ultimate photos are in work-dir
  #~ if { $cntMissing > 0 }  {
    #~ ok_err_msg "Missing settings for $cntMissing ultimate photos"
    #~ return  0
  #~ }
  set dataPath [FindResultData]
  if { 0 == [_ReadIntoArrayResultsCSV dataArr] } {
    return  0;  # error already printed
  }
  # dataArr == pure-name::{time,depth,colorTemp,colorTint1,colorTint2}
  ##parray dataArr
  # support skipping from 'allSettings' images whose depth-override data unchanged from the previous run
  if { $onlyChanged != 0 } {
    set imagesWithChangedOvrd [_ReadDepthOverridesAndListImagesWhereChanged \
                                depthOvrdArrOld depthOvrdArr];  # msg if none
    if { ($imagesWithChangedOvrd  == -1) }  {
      return  0;  # error already printed
    }
    array unset arrChangedOvrd;   # pure-name::1; for faster search
    foreach pureName $imagesWithChangedOvrd  { set arrChangedOvrd($pureName) 1 }
  }
  
  set actionName [expr {($onlyChanged == 0)?  "Process-All-Photos" : \
                                              "Process-Changed-Photos"}]
  set cntGood 0
  set outDir [FindResultDir]
  ok_info_msg "Start processing [llength $allSettings] RAW settings file(s) in '[pwd]'"
  foreach settingsPath $allSettings {
    set pureName [lindex [split [file tail $settingsPath] "."] 0];  # cannot use "rootname"
    if { 0 == [info exists dataArr($pureName)] } {
      ok_err_msg "No color data found for '$pureName'";      continue
    }
    if { ($onlyChanged != 0) && (0 == [info exists arrChangedOvrd($pureName)]) } {
      ok_trace_msg "'$pureName' had no change in depth-override - skipped"
      continue
    }
    ok_trace_msg "'$pureName' does have a change in depth-override"
    # backup the previous settings file
    if { "" != [set msg [MoveListedFilesIntoTrashDir 1 [list $settingsPath] \
                                  "RAW settings" $actionName trashDirPath]] }  {
      return  0;  # error already printed
    }

    ParseDepthColorNoNameRecord $dataArr($pureName) \
                                              time depth wbParam1 wbParam2 wbParam3
    # wbParam3==-1 if irrelevant
    if { 1 == [WriteWBParamsIntoSettingsFile $pureName "" \
                                              $wbParam1 $wbParam2 $wbParam3] } {
      incr cntGood 1
    }
  }
  ok_info_msg "Overriden $cntGood out of [llength $allSettings] RAW settings file(s) in '[pwd]'"
  return  $cntGood
}


# Reads ultimate-photos' WB data into array 'dataArrVar'.
# Returns 1 on success or 0 on error.
proc _ReadIntoArrayResultsCSV {dataArrVar} {
  upvar $dataArrVar dataArr
  set dataPath [FindResultData]
  if { 0 == [file exists $dataPath] } {
    ok_err_msg "No color data found in '$dataPath'"
    return  0
  }
  if { 0 == [ok_read_csv_file_into_array_of_lists dataArr $dataPath " " \
                                                  "CheckDepthColorRecord"] } {
    ok_err_msg "Failed reading color data from '$dataPath'"
    return  0
  }
  return  1
}


# Reads depth-override arrays into parameters.
# Returns list of pure-names for images
# whose depth-override data changed from the previous run
# If no data available, returns 0. If data is corrupted, returns -1.
proc _ReadDepthOverridesAndListImagesWhereChanged {depthOvrdArrOld depthOvrdArrNew} {
  upvar $depthOvrdArrOld depthOvrdArrOldV
  upvar $depthOvrdArrNew depthOvrdArrNewV
  # depth-override arrays:
  #   pure-name::{global-time,min-depth,max-depth,estimated-depth,depth}
  array unset depthOvrdArrOldV; # essential init  
  array unset depthOvrdArrNewV; # essential init
  set ovdrReadRes [TopUtils_ReadIntoArrayDepthOverrideCSV depthOvrdArrNewV 1]
  if { $ovdrReadRes == 0  } {
    ok_info_msg "No depth-override data available - will process all images"
    return  0
  } elseif { $ovdrReadRes < 0 } {
    set msg "Corrupted depth-override data file"
    ok_err_msg $msg;      return  -1
  }
  set allPureNames  [array names depthOvrdArrNewV]
  set ovdrReadRes [TopUtils_ReadIntoArrayDepthOverrideCSV depthOvrdArrOldV 0]
  if { $ovdrReadRes == 0 } {
    ok_info_msg "No previous-run depth-override data available - will process all images with depth-overrides"
    return  $allPureNames
  } elseif { $ovdrReadRes < 0 } {
    set msg "Corrupted previous-run depth-override data file"
    ok_err_msg $msg;      return  -1
  }
  # filter-out from 'allPureNames' images whose depth-overrides unchanged from the previous run
  set pickedPureNames [list ]
  foreach pureName $allPureNames {
    set wasInOldOvrd [info exists depthOvrdArrOldV($pureName)]
    if { $wasInOldOvrd == 0}  {
      ok_info_msg "Depth-override for '$pureName' is added"
      lappend pickedPureNames $pureName;      continue
    }
    TopUtils_ParseDepthOverrideRecord depthOvrdArrOldV $pureName \
                          globalTimeO minDepthO maxDepthO estimatedDepthO depthO
    TopUtils_ParseDepthOverrideRecord depthOvrdArrNewV $pureName \
                          globalTimeN minDepthN maxDepthN estimatedDepthN depthN

    if { $depthN != $depthO }  {
      ok_info_msg "Depth-override for '$pureName' is changed from $depthO to $depthN"
      lappend pickedPureNames $pureName
    }
  }
  ok_info_msg "Found [llength $pickedPureNames] image(s) with new or changed depth-override"
  return  $pickedPureNames
}


# Removes from new and old depth-override files records for inexistent RAWs
proc CleanDepthOverrideFiles {callerActionName trashDirPathVar}  {
  upvar $trashDirPathVar trashDirPath
  if { 0 == [FindRawInputsOrComplain "" allRaws] } { ; # ultimate photos are in work-dir
    return  0;  # error already printed
  }
  ok_info_msg "Now looking for obsolete depth-override records"
  array unset allRawPureNames ;   # will hold pureName -> rawName mapping
  foreach r $allRaws { set allRawPureNames([file rootname [file tail $r]]) $r }
  array unset depthOvrdArrOldV; # essential init  
  array unset depthOvrdArrNewV; # essential init  
  set newExists [expr 1==[TopUtils_ReadIntoArrayDepthOverrideCSV depthOvrdArrNewV 1]]
  set oldExists [expr 1==[TopUtils_ReadIntoArrayDepthOverrideCSV depthOvrdArrOldV 0]]
  set newCleaned 0;   set oldCleaned 0
  if { $newExists == 1 }  {
    foreach ovrdPureName [array names depthOvrdArrNewV] {
      if { [string equal -nocase $ovrdPureName "pure-name"] }  { continue }
      if { 0 == [info exists allRawPureNames($ovrdPureName)] }  {
        ok_trace_msg "Removed depth-override record for '$ovrdPureName'"
        unset depthOvrdArrNewV($ovrdPureName);  set newCleaned 1
      }
    }
  } else {
    ok_info_msg "No depth-override data to clean outdated records from"
  }
  if { $oldExists == 1 }  {
    foreach ovrdPureName [array names depthOvrdArrOldV] {
      if { [string equal -nocase $ovrdPureName "pure-name"] }  { continue }
      if { 0 == [info exists allRawPureNames($ovrdPureName)] }  {
        ok_trace_msg "Removed depth-override record for '$ovrdPureName'"
        unset depthOvrdArrOldV($ovrdPureName);  set oldCleaned 1
      }
    }
  } else {
    ok_info_msg "No previous-run depth-override data to clean outdated records from"
  }
  # backup old files whenever changed, then save the new versions
  set filesToBackup [list]
  if { $newCleaned }  { lappend filesToBackup [FindDepthOvrdData] }
  if { $oldCleaned }  { lappend filesToBackup [FindOldDepthOvrdData] }
  if { "" != [set msg [MoveListedFilesIntoTrashDir 0 $filesToBackup \
            "depth-override" $callerActionName trashDirPath]] }  {
    return  0;  # error already printed
  }
  ok_trace_msg "Trash/backup dir path is '$trashDirPath'"
  if { $newCleaned }  {
    ok_write_array_of_lists_into_csv_file depthOvrdArrNewV \
                                          [FindDepthOvrdData] "pure-name" " "
    ok_info_msg "Cleaned depth-override data printed into '[FindDepthOvrdData]'"
  }
  if { $oldCleaned }  { 
    ok_write_array_of_lists_into_csv_file depthOvrdArrOldV \
                                          [FindOldDepthOvrdData] "pure-name" " "
    ok_info_msg "Cleaned previous-run depth-override data printed into '[FindOldDepthOvrdData]'"
  }
  return  1
}


proc DepthColorDataFilesExist {}  {
  set greyTargetsFile         [FindGreyData 1]
  set greyTargetsSortedFile   [FindSortedGreyData 1]
  set greyTargetsFilteredFile [FindFilteredGreyData 1]
  if { ($greyTargetsFile != "") || ($greyTargetsSortedFile != "") || \
       ($greyTargetsFilteredFile != "") }  {
    return  1
  }
  return  0
}
