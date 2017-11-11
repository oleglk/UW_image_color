# TCLTest__Unmatched_Inputs.tcl
# Invocation examples:
#  source c:/Oleg/Work/UW_Image_Depth/TCL/Tests/TCLTest__Unmatched_Inputs.tcl;  TCLTest__Unmatched_Inputs c:/tmp/UWIC c:/Oleg/Work/UW_Image_Depth/Test/Inputs/ 160914_Eilat_UW PHOTO-NINJA
#  set _SRCD D:/Work/UW_image_depth ; source [file join $_SRCD TCL Tests TCLTest__Unmatched_Inputs.tcl];  set _WRD "d:/ANY/tmp/UWIC";  set _DVN "160914_Eilat_UW";  file delete -force [file join $_WRD $_DVN];  TCLTest__Unmatched_Inputs $_WRD [file join $_SRCD Test Inputs] $_DVN PHOTO-NINJA
#  set _SRCD c:/Oleg/Work/UW_image_depth ; source [file join $_SRCD TCL Tests TCLTest__Unmatched_Inputs.tcl];  set _WRD "c:/tmp/UWIC";  set _DVN "160914_Eilat_UW";  file delete -force [file join $_WRD $_DVN];  TCLTest__Unmatched_Inputs $_WRD [file join $_SRCD Test Inputs] $_DVN PHOTO-NINJA


# TODO: gray-targerts renamed in the beginning aren't recognized at all; split flow into steps and hide after gray-targerts' separation


set TESTS_DIR [file dirname [info script]]
set TESTCODE_DIR [file join $TESTS_DIR "Code"]

set UWIC_DIR [file join $TESTS_DIR ".."]

source [file join $UWIC_DIR     "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$TESTCODE_DIR' ----"

##source [file join $UWIC_DIR     "gui.tcl"]
source [file join $TESTCODE_DIR "test_arrange.tcl"]
source [file join $TESTCODE_DIR "test_run.tcl"]
source [file join $TESTCODE_DIR "AssertExpr.tcl"]


proc TCLTest__Unmatched_Inputs {workRoot storeRoot diveName rawConvName} {
  set inputSelectSpec ""
  if { 0 == [MakeWorkArea $workRoot $storeRoot $diveName $inputSelectSpec] } {
    return  0;  # error already printed
  }
  set workDir [file join $workRoot $diveName]

  if { 0 == [_TestCustomFlow $workDir $rawConvName] }  {
    ok_err_msg "Failed test TCLTest__Unmatched_Inputs"
    return  0
  }
  ok_info_msg "Succeeded test TCLTest__Unmatched_Inputs"
  return  1
}


proc _TestCustomFlow {workDir rawConvName} {
  set pathDict1 [FlowStep_InitSession $workDir $rawConvName]
  if { $pathDict1 == 0 }  { return  0 }

  set pathDict2 [FlowStep_SeparateThumbnails $workDir $rawConvName]
  if { $pathDict2 == 0 }  { return  0 }
  
  set pathDict3 [FlowStep_SortAllRawsByThumbnails $workDir $rawConvName]
  if { $pathDict3 == 0 }  { return  0 }
  
  
  ################# Map-Depth-To-Color #########################################
  # hide some settings files; flow-stage should fail
  if { 0 == [_HideSomeInputs $workDir $pathDict3 1 renamedPaths] } {
    return  0;  # error already printed
  }
  if { 0 == [set pathDict4 [ListWorkAreaStuff]] }  { return  0 }; #error printed
  set pathDict5 [FlowStep_MapDepthToColor $workDir $rawConvName]; # should abort
  if { $pathDict5 != 0 }  {
    ok_err_msg "Map-Depth-To-Color action did not abort despite absense of some settings files"
    return  0;  # not aborted, which is wrong
  }
  ok_info_msg "Map-Depth-To-Color aborted as expected when some settings files were missing\n\n"
  if { 0 == [_RestoreAllHiddenInputNames $workDir $renamedPaths] }  {
    return  0;  # error already printed
  }
  
  # hide some RAW files (targets and photos); flow-stage should pass
  if { 0 == [_HideSomeInputs $workDir $pathDict3 0 renamedPaths] } {; # hide RAWs
    return  0;  # error already printed
  }
  if { 0 == [set pathDict4 [ListWorkAreaStuff]] }  { return  0 }; #error printed
  ok_info_msg "Finished preparation for first stage of TCLTest__Unmatched_Inputs in '$workDir'\n\n"
  
  set pathDict5 [FlowStep_MapDepthToColor $workDir $rawConvName]
  if { $pathDict5 == 0 }  { return  0 }
  if { 0 == [VerifyInputsPreserved $pathDict4 $pathDict5 1 0] }  { return  0 }


  ################# Process-All-Photos #########################################
  # hide some settings files; flow-stage should fail
  if { 0 == [_HideSomeInputs $workDir $pathDict5 1 renamedPaths] } {
    return  0;  # error already printed
  }
  if { 0 == [set pathDict6 [ListWorkAreaStuff]] }  { return  0 }; #error printed
  set pathDict6 [FlowStep_ProcAllRAWs $workDir $rawConvName]  ;  # should abort
  if { $pathDict6 != 0 }  {
    ok_err_msg "Process-All-Photos action did not abort despite absense of some settings files"
    return  0;  # not aborted, which is wrong
  }
  ok_info_msg "Process-All-Photos aborted as expected when some settings files were missing\n\n"
  if { 0 == [_RestoreAllHiddenInputNames $workDir $renamedPaths] }  {
    return  0;  # error already printed
  }

  # flow-stage should pass despite that some RAWs are hidden
  set pathDict6 [FlowStep_ProcAllRAWs $workDir $rawConvName]
  if { $pathDict6 == 0 }  { return  0 }
  if { 0 == [VerifyInputsPreserved $pathDict5 $pathDict6 1 1] }  { return  0 }
  
  
  ################# Process-Changed-Photos #####################################
  # hide some settings files; flow-stage should fail
  if { 0 == [_HideSomeInputs $workDir $pathDict6 1 renamedPaths] } {
    return  0;  # error already printed
  }
  if { 0 == [set pathDict7 [ListWorkAreaStuff]] }  { return  0 }; #error printed
  set pathDict8 [FlowStep_ProcChangedRAWs $workDir $rawConvName]
  if { $pathDict8 != 0 }  {
    ok_err_msg "Process-Changed-Photos action did not abort despite absense of some settings files"
    return  0;  # not aborted, which is wrong
  }
  ok_info_msg "Process-Changed-Photos aborted as expected when some settings files were missing\n\n"
  if { 0 == [_RestoreAllHiddenInputNames $workDir $renamedPaths] }  {
    return  0;  # error already printed
  }
  
  # hide some RAW files (targets (unimportant) and photos); flow-stage should pass
  if { 0 == [_HideSomeInputs $workDir $pathDict6 0 renamedPaths] } {; # hide RAWs
    return  0;  # error already printed
  }
  if { 0 == [set pathDict7 [ListWorkAreaStuff]] }  { return  0 }; #error printed
  ok_info_msg "Finished preparation for last stage of TCLTest__Unmatched_Inputs in '$workDir'\n\n"
  
  # flow-stage should pass; no inputs are hidden; TODO: hide a photo RAW
  set pathDict8 [FlowStep_ProcChangedRAWs $workDir $rawConvName]
  if { $pathDict8 == 0 }  { return  0 }
  if { 0 == [VerifyInputsPreserved $pathDict7 $pathDict8 0 1] }  { return  0 }

  return  1
}


# If 'hideRawOrSettings' == 0/1, hides one gray-target RAW/settings-file(s)
# and one ultimate-photo RAW/settings-file(s).
# Renames corresponding settings-file(s)/RAW(s)
# to indicate that they are now unmatched.
# Puts into 'renamedPathsVar' resulting paths of renamed files.
proc _HideSomeInputs {workDir pathDict hideRawOrSettings renamedPathsVar} {
  global SETTINGS_DIR
  upvar $renamedPathsVar renamedPaths
  #~ if { ($SETTINGS_DIR != "") && ($hideRawOrSettings == 1) }  {
    #~ ok_err_msg "Hiding settings files cannot be supported for RAW converters with standard settings directory"
    #~ return  0
  #~ }
  set allTargets [dict get $pathDict "WB-TARGETS"]  ; # RAW paths
  set allPhotos  [dict get $pathDict "PHOTOS"]      ; # RAW paths
  set nTargets [llength $allTargets];  set nTargetsInitial $nTargets
  if { $nTargets < 3 } {
    ok_err_msg "Too few ([$nTargets) color targets under '$workDir' for _HideSomeInputs"
    return  0
  }
  set nPhotos [llength $allPhotos]
  if { $nPhotos < 2 } {
    ok_err_msg "Too few ($nPhotos) ultimate photos under '$workDir' for _HideSomeInputs"
    return  0
  }
  # drop one gray-target RAW and one ultimate-photo RAW
  if { 0 == [_DropOneImageFiles [lindex $allTargets 0] $hideRawOrSettings \
                                renamedPathsTargets] }  {
    return  0
  }
  if { 0 == [_DropOneImageFiles [lindex $allPhotos  0] $hideRawOrSettings \
                                renamedPathsPhotos] }  {
    return  0
  }
  set renamedPaths [concat $renamedPathsTargets $renamedPathsPhotos]
  return  1
}


# If 'hideRawOrSettings'==0, hides RAW of 'rawPath'
#    and marks all its settings files as unmatched.
# If 'hideRawOrSettings'==1, hides all settings files of 'rawPath'
#    and marks 'rawPath' as unmatched.
# Puts into 'renamedPathsVar' resulting paths of renamed files.
proc _DropOneImageFiles {rawPath hideRawOrSettings renamedPathsVar} {
  upvar $renamedPathsVar renamedPaths
  set renamedPaths [list]
  set which [expr {($hideRawOrSettings==0)? "RAW" : "settings"}]
  set rawName [file tail $rawPath];    set rawDir [file dirname $rawPath]
  ok_info_msg "Commanded to drop $which of '$rawName' under '$rawDir'"
  ##set allForOneImage [FindAllInputsForOneRAWInDir $rawName $rawDir]
  set allForOneImage [FindAllSettingsFilesForOneRaw $rawPath 1]; # anywhere
  lappend allForOneImage $rawPath
  foreach f $allForOneImage {
    set toHide [expr {(([IsRawImageName $f]) && ($hideRawOrSettings == 0)) || \
                      (![IsRawImageName $f]) && ($hideRawOrSettings == 1)} ]
    if { $toHide } {
      if { 0 == [HideOneFile $f renamedPath] }  { return  0 };  # error already printed
    } else {
      if { 0 == [AddSuffixToOneFile $f "_[KeyStr_Unmatched]" renamedPath] }  {
        return  0;  # error already printed
      }
    }
    lappend renamedPaths $renamedPath
  }
  return  1
}


# Restores names of the input files under the workarea.
# Will not work with standard settings directory.
proc _RestoreAllHiddenInputNames {workDir renamedPaths} {
  global RAW_COLOR_TARGET_DIR
  set targetDir [file join $workDir $RAW_COLOR_TARGET_DIR]
  set patternHidden     ".HIDE$"
  set patternUnmatched  "_[KeyStr_Unmatched]"
  # detect pattern in each filename 
  set hiddenFiles  [FilterFilepathListByRegexp $patternHidden $renamedPaths 1]
  set madeUnmatchedFiles  [FilterFilepathListByRegexp \
                                              $patternUnmatched $renamedPaths 1]
  ok_info_msg "Going to restore hidden input(s): {$hiddenFiles}"
  foreach f $hiddenFiles {
    if { 0 == [RemovePatternFromOneFile $f $patternHidden] }  { return  0 }
  }
  ok_info_msg "Finished restoring [llength $hiddenFiles] hidden input(s)"
  ok_info_msg "Going to restore renamed-as-unmatched input(s): {$madeUnmatchedFiles}"
  foreach f $madeUnmatchedFiles {
    if { 0 == [RemovePatternFromOneFile $f $patternUnmatched] }  { return  0 }
  }
  ok_info_msg "Finished restoring [llength $madeUnmatchedFiles] renamed-as-unmatched input(s)"
  return  1
}
