# TCLTest__Out_Of_Depth_Range.tcl
# Invocation examples:
#  source c:/Oleg/Work/UW_Image_Depth/TCL/Tests/TCLTest__Out_Of_Depth_Range.tcl;  TCLTest__Out_Of_Depth_Range c:/tmp/UWIC c:/Oleg/Work/UW_Image_Depth/Test/Inputs/ 160914_Eilat_UW PHOTO-NINJA
#  set _SRCD D:/Work/UW_image_depth ; source [file join $_SRCD TCL Tests TCLTest__Out_Of_Depth_Range.tcl];  set _WRD "d:/ANY/tmp/UWIC";  set _DVN "160914_Eilat_UW";  file delete -force [file join $_WRD $_DVN];  TCLTest__Out_Of_Depth_Range $_WRD [file join $_SRCD Test Inputs] $_DVN PHOTO-NINJA
#  set _SRCD c:/Oleg/Work/UW_image_depth ; source [file join $_SRCD TCL Tests TCLTest__Out_Of_Depth_Range.tcl];  set _WRD "c:/tmp/UWIC";  set _DVN "160914_Eilat_UW";  file delete -force [file join $_WRD $_DVN];  TCLTest__Out_Of_Depth_Range $_WRD [file join $_SRCD Test Inputs] $_DVN PHOTO-NINJA

set TESTS_DIR [file dirname [info script]]
set TESTCODE_DIR [file join $TESTS_DIR "Code"]

set UWIC_DIR [file join $TESTS_DIR ".."]

source [file join $UWIC_DIR     "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$TESTCODE_DIR' ----"

##source [file join $UWIC_DIR     "gui.tcl"]
source [file join $TESTCODE_DIR "test_arrange.tcl"]
source [file join $TESTCODE_DIR "test_run.tcl"]
source [file join $TESTCODE_DIR "AssertExpr.tcl"]


proc TCLTest__Out_Of_Depth_Range {workRoot storeRoot diveName rawConvName} {
  set inputSelectSpec ""
  if { 0 == [MakeWorkArea $workRoot $storeRoot $diveName $inputSelectSpec] } {
    return  0;  # error already printed
  }
  SetRAWConverter $rawConvName; # this test's preparation depends on RAW converter
  if { $rawConvName != [GetRAWConverterName] } {;   # verify converter choice
    ok_err_msg "Failed to choose RAW-converter '$rawConvName'";  return  0
  }
  set workDir [file join $workRoot $diveName]
  # for converter with std settings dir the next action will move settings files
  if { 0 == [MakeFakeSettingsDirIfNeeded $workDir] } { return 0 };# error printed
  if { 0 == [_HideExtremeDepthGrayTargets $workDir] } {
    return  0;  # error already printed
  }
  ok_info_msg "Finished preparaion for TCLTest__Out_Of_Depth_Range under '$workRoot'"
  if { 0 == [TestFullFlow $workDir $rawConvName] }  {
    ok_err_msg "Failed test TCLTest__Out_Of_Depth_Range"
    return  0
  }
  ##ok_err_msg "OK_TMP: Simulated error";  return  0
  ##ok_err_msg "OK_TMP: Simulated crash om $qqNoSuchVar"
  ok_info_msg "Succeeded test TCLTest__Out_Of_Depth_Range"
  return  1
}


proc _HideExtremeDepthGrayTargets {workDir} {
  global RAW_EXTENSION
  if { 0 == [ListGrayTargetsAndPhotosByPatterns $workDir \
                                                allTargets allPhotos] } {
    ok_err_msg "Aborted _HideExtremeDepthGrayTargets under '$workDir'"
    return  0
  }
  set nTargets [llength $allTargets];  set nTargetsInitial $nTargets
  set nPhotos  [llength $allPhotos]
  ok_trace_msg "Targets ($nTargets) by depth: {$allTargets}"
  ok_trace_msg "Photos ($nPhotos) by depth: {$allPhotos}"
  if { $nTargets < 3 } {
    ok_err_msg "Too few ($nTargets) color targets under '$workDir' for _HideExtremeDepthGrayTargets"
    return  0
  }
  if { $nPhotos < 2 } {
    ok_err_msg "Too few ($nPhotos) ultimate photos under '$workDir' for _HideExtremeDepthGrayTargets"
    return  0
  }
  # madeHi/madeLo tell whether deep/shallow photo left out of measured depth range
  set madeLo 0;  set madeHi 0;  set cntRemovedLo 0;  set cntRemovedHi 0
  # reading depths from filenames is already safe - checked earlier by sort
  set depthPhLo [TestRAWPathToDepth [lindex $allPhotos 0]];   # the shallowest
  set depthPhHi [TestRAWPathToDepth [lindex $allPhotos end]]; # the deepest
  set depthTgLo [TestRAWPathToDepth [lindex $allTargets 0]]
  set depthTgHi [TestRAWPathToDepth [lindex $allTargets end]]
  while { $nTargets >= 2 }  {
    if { $depthTgLo <= $depthPhLo }  {  # target above the shallowest photo
      if { 0 == [_DropShallowestGrayTarget allTargets $allPhotos] }  {
        ok_err_msg "Failed to drop shallowest wb-target - targets by depth: {$allTargets};       photos by depth: {$allPhotos}"
        return  0;  # error already printed
      }
      set depthTgLo [TestRAWPathToDepth [lindex $allTargets 0]]
      incr nTargets -1;  incr cntRemovedLo 1
    }
    if { $depthTgHi >= $depthPhHi }  {  # target below the deepest photo
      if { 0 == [_DropDeepestGrayTarget allTargets $allPhotos] }  {
        ok_err_msg "Failed to drop deepest wb-target - targets by depth: {$allTargets}; photos by depth: {$allPhotos}"
        return  0;  # error already printed
      }
      set depthTgHi [TestRAWPathToDepth [lindex $allTargets end]]
      incr nTargets -1;   incr cntRemovedHi 1
    }
    set madeLo [expr $depthPhLo < $depthTgLo]; # no target above shallowest photo
    set madeHi [expr $depthPhHi > $depthTgHi]; # no target below deepest photo
    if { ($madeHi == 1) && ($madeLo == 1) }  { break; } ;  # done both
    ok_trace_msg "Continue dropping targets after removed $cntRemovedLo shallow and $cntRemovedHi deep target(s)"
  }
  if { $madeLo == 1 } {
    ok_info_msg "Arranged some above-depth-range photo(s); had to remove $cntRemovedLo shallow gray target(s)"
  }
  if { $madeHi == 1 } {
    ok_info_msg "Arranged some below-depth-range photo(s); had to remove $cntRemovedHi deep gray target(s)"
  }
  if { ($madeHi == 0) && ($madeLo == 0) } {
    ok_err_msg "Failed to arrange out-of-depth-range photo(s) despite removing $cntRemovedLo shallow- and $cntRemovedHi deep gray target(s)"
    return  0
  }
  return  1
}


# Hides the first gray-target file in 'allTargetsSorted' (RAW and settings)
# and renames all files in 'allPhotosSorted' whose depth is less
# than that of the hidden gray-target (RAW-s and settings-s).
# Returns 1 on success, 0 on error.
proc _DropShallowestGrayTarget {allTargetsSortedVar allPhotosSorted}  {
  upvar $allTargetsSortedVar allTargetsSorted
  set targPath [lindex $allTargetsSorted 0]
  ok_trace_msg "Going to drop '$targPath' as the shallowest target"
  if { 0 == [_HideOneTargetFiles $targPath] }  {
    ok_err_msg "Failed to hide shallow wb-target '$targPath'"
    return  0;  # error already printed
  }
  set allTargetsSorted [lreplace $allTargetsSorted 0 0];  # del the 1st element
  set nextTargPath [lindex $allTargetsSorted 0]; # next after the hidden one
  if { 0 > [set targDepth [TestRAWPathToDepth $nextTargPath]] }  { return 0 }
  if { 0 > [set numShallower [_RenameAsSpecialPhotosBeforeGivenDepth \
                                      $allPhotosSorted $targDepth 0]] }  {
    return  0;  # error already printed
  }
  ok_trace_msg "Finished dropping '$targPath' as the shallowest target"
  return  1
}


# Hides the last gray-target file in 'allTargetsSorted' (RAW and settings)
# and renames all files in 'allPhotosSorted' whose depth is bigger
# than that of the hidden gray-target (RAW-s and settings-s).
# Returns 1 on success, 0 on error.
proc _DropDeepestGrayTarget {allTargetsSortedVar allPhotosSorted}  {
  upvar $allTargetsSortedVar allTargetsSorted
  set targPath [lindex $allTargetsSorted end]
  ok_trace_msg "Going to drop '$targPath' as the deepest target"
  if { 0 == [_HideOneTargetFiles $targPath] }  {
    ok_err_msg "Failed to hide shallow wb-target '$targPath'"
    return  0;  # error already printed
  }
  set allTargetsSorted [lreplace $allTargetsSorted end end];# del the last element
  set nextTargPath [lindex $allTargetsSorted end]; # next after the hidden one
  if { 0 > [set targDepth [TestRAWPathToDepth $nextTargPath]] }  { return 0 }
  if { 0 > [set numDeeper [_RenameAsSpecialPhotosBeforeGivenDepth \
                                    $allPhotosSorted $targDepth 1]] }  {
    return  0;  # error already printed
  }
  ok_trace_msg "Finished dropping '$targPath' as the deepest target"
  return  1
}


proc _HideOneTargetFiles {targPath} {
  set rawName [file tail $targPath];    set rawDir [file dirname $targPath]
  ##set allForOneImage [FindAllInputsForOneRAWInDir $rawName $rawDir]
  set allForOneImage [FindAllSettingsFilesForOneRaw $targPath 1]; # anywhere
  lappend allForOneImage $targPath
  set cnt 0
  foreach f $allForOneImage {
    if { 0 == [HideOneFile $f renamedPath] }  { return  0 };  # error printed
    incr cnt 1
  }
  ok_trace_msg "Done hiding $cnt file(s) for '$targPath'"
  return  $cnt
}


# Finds and renames ultimate photos above/below 'depth'. Returns their number.
# 'depthSmallerOrLarger': 0==target-is-deeper;  1==photo-is-deeper
proc _RenameAsSpecialPhotosBeforeGivenDepth {allPhotosSorted depth \
                                              depthSmallerOrLarger} {
  if { $depthSmallerOrLarger == 0 } {
    set firstI 0; set incrI 1; set lastI [llength $allPhotosSorted]
    set depthDiffSignToStop 1;   # e.g. stop when photo is deeper than target
    set suffix "_[KeyStr_BelowRange]"
  } else {
    set firstI [expr [llength $allPhotosSorted] -1]; set incrI -1; set lastI -1
    set depthDiffSignToStop -1;  # e.g. stop when target is deeper than photo
    set suffix "_[KeyStr_AboveRange]"
  }
  set cnt 0
  for {set i $firstI} {$i != $lastI} {incr i $incrI}  {
    set photoPath [lindex $allPhotosSorted $i]
    if { 0 > [set photoDepth [TestRAWPathToDepth $photoPath]] }  { return 0 }
    set depthDiffSign [expr $photoDepth - $depth]
    if { [expr $depthDiffSign * $depthDiffSignToStop] >= 0 } { break }
    # rename the photo's related files to indicate it became outside of depth range
    if { 2 > [set cnt4One [AddSuffixToFilesOfOneImage $photoPath $suffix]] }  {
      ok_err_msg "Only $cnt4One input file(s) for '$photoPath' - required 1 RAW and >=1 settings-files"
      return  -1
    }
    ok_trace_msg "Renamed $cnt4One file(s) related to '$photoPath' by adding suffix '$suffix' (depth=$photoDepth, threshold-depth=$depth)"
    incr cnt
  }
  ok_trace_msg "Renamed $cnt file(s) for photos before depth $depth"
  return  $cnt
}
