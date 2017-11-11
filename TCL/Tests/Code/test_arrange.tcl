# test_arrange.tcl

set SCRIPT_DIR [file dirname [info script]]

set UWIC_DIR [file join $SCRIPT_DIR ".." ".."]

source [file join $UWIC_DIR   "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"

source [file join $UWIC_DIR   "dir_file_mgr.tcl"]

## filename substrings to describe file intention
proc KeyStr_ColorTarget {}  { return "GT" }
proc KeyStr_Photo       {}  { return "PH" }
proc KeyStr_BelowRange  {}  { return "BelowRange" }
proc KeyStr_AboveRange  {}  { return "AboveRange" }
proc KeyStr_Unmatched   {}  { return "Unmatched" }

set _CAN_USE_FILE_LINKS 1 ;   # try links to bring inputs unless it fails


# Builds directory structure and puts all the inputs in place
# Invocation example:
#  set WD "D:/ANY/TMP/UWIC/160914_Eilat_UW";  file delete -force $WD;  MakeWorkArea d:/ANY/tmp/UWIC d:/Work/UW_image_depth/Test/Inputs 160914_Eilat_UW ""
proc MakeWorkArea {workRoot storeRoot diveName inputSelectSpec} {
  set workDirPath [file join $workRoot $diveName]
  if { 0 == [_InitDirStructure $workDirPath]} {
    return  0;  # error already printed
  }
  if { 0 == [_CopyDiveInputs $storeRoot $diveName $inputSelectSpec \
                             $workDirPath]} {
    return  0;  # error already printed
  }
  return  1
}


# Finds dive-related files in the work-area; returns results as a dictionary:
# DIVE-LOGS::listOfPaths PHOTOS::listOfPaths WB-TARGETS::listOfPaths
# SETTINGS-PHOTOS::listOfPaths SETTINGS-WB-TARGETS::listOfPaths
# THUMBNAILS-PHOTOS::listOfPaths THUMBNAILS-WB-TARGETS::listOfPaths
# DATAFILE-WB-TARGETS::path DATAFILE-WB-TARGETS-SORTED::path 
# DATAFILE-WB-TARGETS-FILTERED::path
# DATAFILE-DEPTH-OVRD::path
# DATAFILE-OLD-DEPTH-OVRD::path
# DATAFILE-RESULT-COLORS::path
# TRASH-DIR::path
# SETTINGS-ALL-PREV::listOfPaths
# SETTINGS-ALL-PREV-UNMATCHED::listOfPaths SETTINGS-ALL-PREV-MATCHED::listOfPaths
proc ListWorkAreaStuff {}  {
  global WORK_DIR
  global THUMB_DIR THUMB_COLORTARGET_DIR
  set inpDict 0
  if { 0 == [IsWorkDirOK] }  {
    ok_err_msg "ListWorkAreaStuff called for an invalid work-area '$WORK_DIR'"
    return  0
  }
  set inpDict [dict create]
  set inputSelectSpec "" ;  # TMP: not implemented so far
  dict set inpDict "DIVE-LOGS" [_FindDiveLogListBySpec $WORK_DIR $inputSelectSpec]
  dict set inpDict "PHOTOS"               [FindRawInputs $WORK_DIR]
  dict set inpDict "WB-TARGETS"           [FindRawColorTargets 0]
  # settings files require further filtering in case of standard settings dir
  dict set inpDict "SETTINGS-WB-TARGETS"  [FilterFilepathListByRegexp \
                      "[KeyStr_ColorTarget]" [FindRawColorTargetsSettings 0] 1]
  dict set inpDict "SETTINGS-PHOTOS"      [FilterFilepathListByRegexp \
                      "[KeyStr_Photo]" [FindUltimateRawPhotosSettings 0] 1]
  dict set inpDict "THUMBNAILS-PHOTOS"      [FindThumbnails $THUMB_DIR 0]
  dict set inpDict "THUMBNAILS-WB-TARGETS"  [FindThumbnails $THUMB_COLORTARGET_DIR 0]
  dict set inpDict "DATAFILE-WB-TARGETS"          [FindGreyData 1]
  dict set inpDict "DATAFILE-WB-TARGETS-SORTED"   [FindSortedGreyData 1]
  dict set inpDict "DATAFILE-WB-TARGETS-FILTERED" [FindFilteredGreyData 1]
  if { 1 == [file exists [set dataPath [FindDepthOvrdData]]] }  {
    dict set inpDict "DATAFILE-DEPTH-OVRD"     $dataPath
  } else { dict set inpDict "DATAFILE-DEPTH-OVRD"  "" }
  if { 1 == [file exists [set dataPath [FindOldDepthOvrdData]]] }  {
    dict set inpDict "DATAFILE-OLD-DEPTH-OVRD"     $dataPath
  } else { dict set inpDict "DATAFILE-OLD-DEPTH-OVRD"  "" }
  if { 1 == [file exists [set dataPath [FindResultData]]] }  {
    dict set inpDict "DATAFILE-RESULT-COLORS"     $dataPath
  } else { dict set inpDict "DATAFILE-RESULT-COLORS"  "" }
  set trashDir                            [GetLastTrashDirPath]
  dict set inpDict "TRASH-DIR"            $trashDir
  dict set inpDict "SETTINGS-ALL-PREV" [FindSettingsFilesInDir $trashDir 0]
  dict set inpDict "SETTINGS-ALL-PREV-UNMATCHED" [FilterFilepathListByRegexp \
                "[KeyStr_Unmatched]" [dict get $inpDict "SETTINGS-ALL-PREV"] 1]
  dict set inpDict "SETTINGS-ALL-PREV-MATCHED" [FilterFilepathListByRegexp \
                "[KeyStr_Unmatched]" [dict get $inpDict "SETTINGS-ALL-PREV"] 0]

  #~ if { 1 == [file exists [set dataPath [FindResultData]]] }  {
    #~ dict set inpDict "DATAFILE-RESULT-COLORS"     $dataPath
  #~ } else { dict set inpDict "DATAFILE-RESULT-COLORS"  "" }

  # TODO: count RAWs by type patterns
  return  $inpDict
}


proc FormatWorkAreaStuff {pathDict {preffix ""}}  {
  set str ""
  dict for {key value} $pathDict {
    set str [format "%s\n%s%s :: {%s}" $str $preffix $key $value]
  }
  return $str
}


proc FormatOldAndNewWorkAreaStuff {pathDictOld pathDictNew {preffix ""}}  {
  set strOld [FormatWorkAreaStuff $pathDictOld [format "%s(Old)" $preffix]]
  set strNew [FormatWorkAreaStuff $pathDictNew [format "%s(New)" $preffix]]
  return  [format "%s\n%s" $strOld $strNew]
}


proc CountInputs {pathDict  \
                      nTargRAWsVar nPhotoRAWsVar                           \
                      nTargSettingsVar nPhotoSettingsVar                   \
                      nUnmatchedTargRAWsVar nUnmatchedPhotoRAWsVar         \
                      nUnmatchedTargSettingsVar nUnmatchedPhotoSettingsVar } {
  upvar $nTargRAWsVar nTargRAWs
  upvar $nPhotoRAWsVar nPhotoRAWs
  upvar $nTargSettingsVar nTargSettings
  upvar $nPhotoSettingsVar nPhotoSettings
  upvar $nUnmatchedTargRAWsVar nUnmatchedTargRAWs
  upvar $nUnmatchedPhotoRAWsVar nUnmatchedPhotoRAWs
  upvar $nUnmatchedTargSettingsVar nUnmatchedTargSettings
  upvar $nUnmatchedPhotoSettingsVar nUnmatchedPhotoSettings

  set targRAWs [dict get $pathDict "WB-TARGETS"]
  set nTargRAWs [llength $targRAWs]
  set photoRAWs [dict get $pathDict "PHOTOS"]
  set nPhotoRAWs [llength $photoRAWs]
  set targSettings [dict get $pathDict "SETTINGS-WB-TARGETS"]
  set nTargSettings [llength $targSettings]
  set photoSettings [dict get $pathDict "SETTINGS-PHOTOS"]
  set nPhotoSettings [llength $photoSettings]
  set unmatchedTargRAWs [FilterFilepathListByRegexp \
                "[KeyStr_Unmatched]" $targRAWs 1]
  set nUnmatchedTargRAWs [llength $unmatchedTargRAWs]
  set unmatchedPhotoRAWs [FilterFilepathListByRegexp \
                "[KeyStr_Unmatched]" $photoRAWs 1]
  set nUnmatchedPhotoRAWs [llength $unmatchedPhotoRAWs]
  set unmatchedTargSettings [FilterFilepathListByRegexp \
                "[KeyStr_Unmatched]" $targSettings 1]
  set nUnmatchedTargSettings [llength $unmatchedTargSettings]
  set unmatchedPhotoSettings [FilterFilepathListByRegexp \
                "[KeyStr_Unmatched]" $photoSettings 1]
  set nUnmatchedPhotoSettings [llength $unmatchedPhotoSettings]
}


# Builds list of filepaths out of names matching 'namePattern' in 'dirPath'
proc BuildFilepathListFromRegexp {namePattern dirPath} {
  # build all-names' list
  set allPathList [glob -nocomplain -- [file join $dirPath "*"]]
  set matchingPaths [FilterFilepathListByRegexp $namePattern $allPathList 1]
  return  $matchingPaths
}


# If 'pickORdrop' == 1 (0), drops from list of filepaths those
#    with names not-matching (matching) 'namePattern'.
# Returns the new filtered list.
proc FilterFilepathListByRegexp {namePattern pathList pickORdrop} {
  set pickedPaths [list]
  foreach p $pathList {
    set nameNoDir [file tail $p]
    set dirNoName [file dirname $p]
    set match [regexp -nocase -- $namePattern $nameNoDir] 
    if { (($match == 1) && ($pickORdrop == 1)) || \
         (($match == 0) && ($pickORdrop == 0)) } {
      lappend pickedPaths [file join $dirNoName $nameNoDir]
    }
  }
  ok_trace_msg "Found [llength $pickedPaths] file(s) whose name(s) [expr {($pickORdrop==1)? "match" : "don't match"}] '$namePattern'"
  return  $pickedPaths
}


# Changes depth in some of the records in 'ovrdFullPath'.
# Returns list of affected purenames.
proc SimulateDepthOverride {ovrdFullPath} {
  set HEADER_PATTERN "pure-name";   # 1st token in the header line
  if { 0 == [file exists $ovrdFullPath] } {
    ok_err_msg "Missing initial depth-override file '$ovrdFullPath'."
    return  0
  }
  array unset depthOvrdArr;  # essential init-s
  if { 0 >= [TopUtils_ReadIntoArrayDepthOverrideCSV depthOvrdArr 1] } {
    ok_err_msg "Failed reading depth-override file '$ovrdFullPath'."
    return  0
  }
  if { 0 == [array size depthOvrdArr] }  {
    ok_err_msg "No records in depth-override file '$ovrdFullPath'."
    return  0
  }
  # depthOvrdArr = pure-name::{global-time,min-depth,max-depth,estimated-depth,depth}
  # depthOvrdArr includes the header
  set cntErr 0; set changedPurenames [list]; set changeCurrent 0
  foreach pureName [array names depthOvrdArr] {
    if { 1 == [regexp $HEADER_PATTERN $pureName] } { continue };  # skip header
    set changeCurrent [expr {($changeCurrent==0)? 1 : 0}]
    if { 0 == [TopUtils_ParseDepthOverrideRecord depthOvrdArr $pureName \
                    globalTime minDepth maxDepth estimatedDepth depth] }  {
      ok_err_msg "Invalid depth-override record for '$pureName': '$depthOvrdArr($pureName)'"
      return  0
    }
    if { $changeCurrent == 0 }  { continue }
    set depth [expr 1.5 * $depth]; # TODO: multipllier based on depth resolution
    lappend changedPurenames $pureName
    TopUtils_PackDepthOverrideRecord depthOvrdArr $pureName \
                      $globalTime $minDepth $maxDepth $estimatedDepth $depth
  }
  ok_info_msg "Simulated depth-override of [llength $changedPurenames] out of [array size depthOvrdArr] image(s)"
  # save the new version of depth-override data; don't touch the "previous"
  if { 0 == [ok_write_array_of_lists_into_csv_file depthOvrdArr \
                                     $ovrdFullPath $HEADER_PATTERN " "] }  {
    ok_err_msg "Failed to save new depth-override data in '$ovrdFullPath]'"
    return  0
  }
  ok_info_msg "Updated depth-override data printed into '$ovrdFullPath]'"
  return  $changedPurenames
}


proc ForcedBackupDepthOverrideIfExists {}  {
  set lastDepthOvrdPath  [FindDepthOvrdData]
  set lastTrashDir [GetLastTrashDirPath]
  set destPath [file join $lastTrashDir [file tail $lastDepthOvrdPath]]
  if { 1 == [file exists $lastDepthOvrdPath] }  {
    file copy -force $lastDepthOvrdPath $destPath
    return  $destPath
  }
  return  ""
}

proc _InitDirStructure {workRootPath} {
  global DATA_DIR
  if { [file exists $workRootPath] } {
    ok_err_msg "Test work-root directory '$workRootPath' exists. Aborting to avoid damage"
    return  0
  }
  set tclExecResult [catch {
    file mkdir $workRootPath
    file mkdir [file join $workRootPath $DATA_DIR]
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed creating work-area in '$workRootPath': $evalExecResult!"
    return  0
  }
  ok_info_msg "Created work-area in '$workRootPath'"
  return  1
}


# Copies or links if HW/SW permits
proc _CopyDiveInputs {storeRootPath diveName inputSelectSpec workRootPath} {
  global DATA_DIR RAW_EXTENSION
  set diveInpDir [file join $storeRootPath $diveName]
  set inpDataDir [file join $diveInpDir $DATA_DIR]
  set workDataDir [file join $workRootPath $DATA_DIR]
  # require existence of all directories involved
  set dirs [list $diveInpDir "Test dive-input" \
                 $inpDataDir "Test dive-input-data" \
                 $workRootPath "Test work-root" \
                 $workDataDir "Test work-data"]
  for {set i 0} {$i < [expr {[llength $dirs]-1}]} {incr i 2} {
    set path [lindex $dirs $i];  set descr [lindex $dirs [expr {$i+1}]]
    if { (0== [file exists $path]) || (0== [file isdirectory $path]) } {
      ok_err_msg "$descr directory '$path' inexisteht. Aborting."
      return  0
    }
  }
  set RAW_EXTENSION [lindex [FindRawExtensionsInDir $diveInpDir] 0]; #TODO: improve
  set rawList [_FindRAWsBySpec $diveInpDir $inputSelectSpec]
  set diveLogList [_FindDiveLogListBySpec $diveInpDir $inputSelectSpec]
  set cnt 0
  set tclExecResult [catch {
    foreach r $rawList {
      #TODO: copy all files with the purename of '$r' too (settings)
      set allForOneImage [FindAllInputsForOneRAWInDir $r $diveInpDir]
      foreach f $allForOneImage {
        set neverLink [expr {(0 == [string compare $f $r])? 0 : 1}];  # link RAW
        if { 0 == [_BringOneFile $f $workRootPath $neverLink] }  {
          return  1;  # error already printed
        }
        incr cnt 1
      }
    }
    ok_info_msg "Copied $cnt input file(s) for [llength $rawList] RAW(s) from store '$diveInpDir' into work-area '$workRootPath'"
    foreach l $diveLogList {
      file copy $l $workDataDir
    }
    ok_info_msg "Copied [llength $diveLogList] dive-log(s) from store '$inpDataDir' into work-area '$workDataDir'"
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed creating work-area in '$workRootPath': $evalExecResult!"
    return  0
  }
  return  1
}


# Overrides SETTINGS_DIR to '$workRootPath/'TEST_SETTINGS'
# and moves into this dir all settings files for the current converter
# Should run when converter is known!
proc MakeFakeSettingsDirIfNeeded {workRootPath} {
  global SETTINGS_DIR RAW_EXTENSION
  if { $SETTINGS_DIR == "" }  {
    ok_info_msg "RAW converter '[GetRAWConverterName]' does not use standard settings directory"
    return  1
  }
  set fakeSettingsDir [file join $workRootPath "TEST_SETTINGS"]
  set descr "fake settings directory '$fakeSettingsDir'"
  if { ![file exists $fakeSettingsDir] } {
    set tclExecResult [catch { file mkdir $fakeSettingsDir } evalExecResult]
    if { $tclExecResult != 0 } {
      ok_err_msg "Failed creating $descr: $evalExecResult!"
      return  0
    }
    ok_info_msg "Created $descr"
  }
  ok_info_msg "Overriding standard settings directory of RAW converter '[GetRAWConverterName]' from '$SETTINGS_DIR' to '$fakeSettingsDir'"
  set SETTINGS_DIR $fakeSettingsDir
  # if there are any settings files in 'fakeSettingsDir', consider the job done
  if { 0 != [llength [set sf [FindSettingsFilesInDir $fakeSettingsDir]]] }  {
    ok_info_msg "Found [llength $sf] settings files in $descr; consider the settings are already arranged."
    return  1
  }
  # list all input files, then pick settings file and move them
  set tclResult [catch {
    set allInputs [glob [file join $workRootPath "*.*"]] } execResult]
    if { $tclResult != 0 } { ok_err_msg "$execResult!";  return  0  }
  set cnt 0
  foreach f $allInputs {
    if { 1 == [IsSettingsFileName [file tail $f]] }  {
      set tclResult [catch {
        file rename -force $f $fakeSettingsDir } execResult]
      if { $tclResult != 0 } { ok_err_msg "$execResult!";  return  0  }
      incr cnt 1
    }
  }
  if { $cnt == 0 }  {
    ok_err_msg "No settings files moved into $descr";   return  0
  }
  ok_info_msg "Moved $cnt settings file(s) into $descr"
  return  1
}


proc _BringOneFile {srcFilePath destDirPath neverLink} {
  global _CAN_USE_FILE_LINKS
  global SETTINGS_DIR
  # support copying settings into a special dir (like for CaptureOne)
  # though when work area is prepared, converter isn't known and SETTINGS_DIR==""
  if { (1 == [IsSettingsFileName [file tail $srcFilePath]]) && \
       ($SETTINGS_DIR != "") }  { ;   # copy settings into standard dir
    set destFilePath [file join $SETTINGS_DIR [file tail $srcFilePath]]
  } else {
    set destFilePath [file join $destDirPath [file tail $srcFilePath]]
  }
  # error code not returned by file operations; exceptions happen instead
  if { ($neverLink == 0 ) && ($_CAN_USE_FILE_LINKS == 1) }  {
    set tclExecResult [catch {
      file link $destFilePath $srcFilePath
    } evalExecResult]
    if { $tclExecResult != 0 } {
      ok_err_msg "Failed to link '$srcFilePath' into '$destFilePath': $evalExecResult!"
      set _CAN_USE_FILE_LINKS 0
      ok_info_msg "Resorting to file-copy for bringing test inputs"
    } else {
      return  1;  # link succeeded
    }
  }
  file copy $srcFilePath $destDirPath
  return  1
}


proc _FindRAWsBySpec {diveInpDir inputSelectSpec} {
  set allRaws [FindRawInputs $diveInpDir]
  if { 0 == [llength $allRaws] } {
    ok_err_msg "No RAW images at all found in store '$diveInpDir'. Aborting."
    return  [list]
  }
  #TODO: implement filtering by 'inputSelectSpec'
  return  $allRaws
}


proc _FindDiveLogListBySpec {diveInpDir inputSelectSpec} {
  #TODO: implement search and filtering of several dive-log versions
  global DATA_DIR DEPTH_LOG_NAME
  set inpDataDir [file join $diveInpDir $DATA_DIR]
  set lPath [FindSavedLogInDir $inpDataDir 1]
  if { $lPath == "" } {
    ok_err_msg "No depth-log file found in directory '$inpDataDir'"
    return  [list]
  }
  #~ set lPath [file join $inpDataDir $DEPTH_LOG_NAME]
  #~ if { 0 == [file exists $lPath] } {
    #~ ok_err_msg "No depth-log file(s) not found; candidate path(s): '$lPath'"
    #~ return  [list]
  #~ }
  return [list $lPath]
}


proc SortTestRAWPathsByDepthPattern {rawPaths} {
  set depthToPath [dict create]
  foreach r $rawPaths {
    if { 0 > [set depth [TestRAWPathToDepth $r]] }  {
      ok_err_msg "Failed reading depth from RAW path '$r'"
      return  0
    }
    dict lappend depthToPath $depth $r
  }
  set depthsSorted [lsort -real [dict keys $depthToPath]]
  set pathsSorted [list]
  set tclExecResult [catch {
    foreach d $depthsSorted {
      set pl [dict get $depthToPath $d] ;   # could be a list
      foreach p $pl {
        lappend pathsSorted $p
      }
    }
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed sorting test-input paths by depth: $evalExecResult!"
    return  0
  }
  return  $pathsSorted
}


# Reads depth value from a string like "a/b/DSC03372_PH_22d13.ARW" (=> 22.13)
proc TestRAWPathToDepth {rawPath}  {
  set pattern {(_GT|_PH)_([0-9]+d[0-9]+)}
  if { 0 == [regexp -nocase $pattern $rawPath fullMatch kind depthStr] }  {
    ok_err_msg "Missing depth spec in test input file name '$rawPath'"
    return  -1;  # error
  }
  if { 1 != [regsub -nocase "d" $depthStr "." depth] } {
    ok_err_msg "Missing decimal dot in depth spec in test input file name '$rawPath'"
    return  -1;  # error
  }
  return  [expr $depth]
}


proc ListGrayTargetsAndPhotosByPatterns {workDir \
                                      allTargetsSortedVar allPhotosSortedVar} {
  global RAW_EXTENSION
  upvar $allTargetsSortedVar allTargets
  upvar $allPhotosSortedVar  allPhotos
  set patternGT [format "_%s.*\.%s\$" [KeyStr_ColorTarget] $RAW_EXTENSION]
  set allTargets [BuildFilepathListFromRegexp $patternGT $workDir]
  if { 0 == [set allTargets [SortTestRAWPathsByDepthPattern $allTargets]] }  {
    return  0;  # error already printed
  }
  set patternPH [format "_%s.*\.%s\$" [KeyStr_Photo] $RAW_EXTENSION]
  set allPhotos [BuildFilepathListFromRegexp $patternPH $workDir]
  if { 0 == [set allPhotos [SortTestRAWPathsByDepthPattern $allPhotos]] }  {
    return  0;  # error already printed
  }
  return  1
}


# For {A/b/name.ext SUFF} returns A/b/nameSUFF.ext
proc InsertSuffixIntoFilename {origFilePath outNameSuffix} {
  set pathNoExt [AnyFileNameToPurename $origFilePath]
  set ext       [string range $origFilePath [string length $pathNoExt] end]
  set newPath "$pathNoExt$outNameSuffix$ext"
  return  $newPath
}


# For {A/b/nameSUFFqq.ext SUFF} returns A/b/nameqq.ext
proc RemovePatternFromFilename {origFilePath pattern} {
  set nameNoDir [file tail $origFilePath]
  set dirNoName [file dirname $origFilePath]
  regsub -all $pattern $nameNoDir "" nameNoDir
  set newPath [file join $dirNoName $nameNoDir] 
  return  $newPath
}


proc AddSuffixToOneFile {filePath suffix renamedPathVar} {
  upvar $renamedPathVar renamedPath
  set tclExecResult [catch {
    set newF [InsertSuffixIntoFilename $filePath $suffix]
    file rename -force $filePath $newF
    ok_trace_msg "Renamed '$filePath' into '$newF'"
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed renaming file '$filePath' by adding suffix '$suffix': $evalExecResult!"
    return  0
  }
  set renamedPath $newF
  return  1
}


proc RemovePatternFromOneFile {filePath pattern} {
  set tclExecResult [catch {
    set newF [RemovePatternFromFilename $filePath $pattern]
    file rename -force $filePath $newF
    ok_trace_msg "Renamed '$filePath' into '$newF'"
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed renaming file '$filePath' by removing pattern '$pattern': $evalExecResult!"
    return  0
  }
  return  1
}

proc AddSuffixToFilesOfOneImage {rawPath suffix} {
  set rawName [file tail $rawPath];    set rawDir [file dirname $rawPath]
  ##set allForOneImage [FindAllInputsForOneRAWInDir $rawName $rawDir]
  set allForOneImage [FindAllSettingsFilesForOneRaw $rawPath 1]; # anywhere
  ok_trace_msg "Settings for RAW '[file tail $rawPath]': {$allForOneImage}]"
  lappend allForOneImage $rawPath
  set cnt 0
  set tclExecResult [catch {
    foreach f $allForOneImage {
      set newF [InsertSuffixIntoFilename $f $suffix]
      file rename -force $f $newF ;  # TODO: catch exceptions
      ok_trace_msg "Renamed '$f' into '$newF'"
      incr cnt 1
    }
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed renaming file(s) by adding suffix '$suffix': $evalExecResult!"
    return  0
  }
  return  $cnt
}


proc HideOneFile {filePath renamedPathVar}  {
  upvar $renamedPathVar renamedPath
  set tclExecResult [catch {
    file rename -force $filePath "$filePath.HIDE"
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed hiding '$filePath': $evalExecResult!"
    return  0
  }
  set renamedPath "$filePath.HIDE"
  return  1
}


proc SimulateDivelogAmbiguity {workDir origDiveLogVar}  {
  upvar $origDiveLogVar origDiveLog
  if { "" == [set origDiveLog [FindSavedLog 1]] }  {
    ok_err_msg "SimulateDivelogAmbiguity cannot find original dive-log"
    return  0
  }
  set newPath "[file rootname $origDiveLog]_TestCopy[file extension $origDiveLog]"
  set tclExecResult [catch {
    file copy -force $origDiveLog $newPath
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed duplicating dive-log '$origDiveLog' into '$newPath': $evalExecResult!"
    return  0
  }
  ok_info_msg "Success duplicating dive-log '$origDiveLog' into '$newPath'"
  return  1
}
