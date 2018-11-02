# raw_converters.tcl

set CONVERTER_NAME_LIST [list "COREL-AFTERSHOT" "RAW-THERAPEE" \
                              "PHOTO-NINJA" "CAPTURE-ONE"]
##set INITIAL_CONVERTER_NAME "COREL-AFTERSHOT"
##set INITIAL_CONVERTER_NAME "RAW-THERAPEE"
##set INITIAL_CONVERTER_NAME "PHOTO-NINJA"
set INITIAL_CONVERTER_NAME "CAPTURE-ONE"

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]


set PICK_TARGETS  0
set PICK_PHOTOS   1
set PICK_ALL      2

# directory where settings (sidecar) files are stored; "" if they are near RAWs
set SETTINGS_DIR    ""

set WBPARAM_NAMES   {"c1" "c2" "c3"}

set WBPARAM1_PATTERN   {}
set WBPARAM2_PATTERN   {}
set WBPARAM3_PATTERN  {}

set WBPARAM1_FORMAT  {}
set WBPARAM1_SUBMATCH_INDEX 1
set WBPARAM2_FORMAT  {}
set WBPARAM2_SUBMATCH_INDEX 1
set WBPARAM3_FORMAT {}
set WBPARAM3_SUBMATCH_INDEX 1

# TODO: MAKE IT PER-FILTER ARRAY
set WBPARAM1_SURFACE   -1
set WBPARAM2_SURFACE   -1
set WBPARAM3_SURFACE   -1

## per-converter color-parameters' limits
set WBPARAM1_MIN       -1
set WBPARAM1_MAX       -1
set WBPARAM2_MIN       -1
set WBPARAM2_MAX       -1
set WBPARAM3_MIN       -1
set WBPARAM3_MAX       -1

## per-converter gray-target- and image-color-result file headers
set GREY_TARGET_DATA_HEADER_RCONV {}
set IMAGE_DATA_HEADER_RCONV       {}

set IS_SAMPLE_ADJACENT_CALLBACK  0
set EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK 0; #shallower than min
set EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK 0; #deeper than max


array unset _RCONV_CONFIG_FILES
set _RCONV_CONFIG_FILES(COREL-AFTERSHOT)  "rconv_CorelAfterShot.tcl"
set _RCONV_CONFIG_FILES(RAW-THERAPEE)     "rconv_RawTherapee.tcl"
set _RCONV_CONFIG_FILES(PHOTO-NINJA)      "rconv_PhotoNinja.tcl"
set _RCONV_CONFIG_FILES(CAPTURE-ONE)      "rconv_CaptureOne.tcl"

proc GetRAWConverterName {} {
  global CONVERTER_NAME
  return  $CONVERTER_NAME
}


# Returns 1 if joint format string for all WB parameters is specified.
# If so, all the 3 WB parameters should be written at once.
proc WBParamFormat123IsUsed {}  {
  global WBPARAM123_PATTERN WBPARAM123_FORMAT
  return  [expr { ([info exists WBPARAM123_PATTERN])  && \
                  ($WBPARAM123_PATTERN != "")         && \
                  ([info exists WBPARAM123_FORMAT])   && \
                  ($WBPARAM123_FORMAT != "") } ]
}


proc WBParam3IsUsed {}  {
  global WBPARAM3_PATTERN
  return  [expr {$WBPARAM3_PATTERN != ""}]
}


proc WBParamName {i} {
  global WBPARAM_NAMES
  set nParams [expr {([WBParam3IsUsed])? 3 : 2}]
  if { ($i < 1) || ($i > $nParams) }  { return "" }
  return [lindex $WBPARAM_NAMES [expr $i - 1]]
}
proc WBParam1Name {} {  return [WBParamName 1] }
proc WBParam2Name {} {  return [WBParamName 2] }
proc WBParam3Name {} {  return [WBParamName 3] }


proc IsSettingsFileName {fileName}  {
  set pureName [AnyFileNameToPurename $fileName]
  set settingsFileName [SettingsFileName $pureName]
  return  [expr {1 == [string equal -nocase $fileName $settingsFileName]}]
}


proc SetRAWConverter {{rcName ""}} {
  global SCRIPT_DIR CONVERTER_NAME _RCONV_CONFIG_FILES
  if { $rcName == "" }  { set rcName $CONVERTER_NAME }; # so it works through GUI
  if { [info exists _RCONV_CONFIG_FILES($rcName)] }  {
    set CONVERTER_NAME $rcName
    ok_info_msg "Selected RAW converter: '$CONVERTER_NAME'"
    set defPath [file join $SCRIPT_DIR $_RCONV_CONFIG_FILES($CONVERTER_NAME)]
    set tclResult [catch {
      uplevel 1 source $defPath
    } execResult]
    if { $tclResult != 0 } {
      ok_err_msg "Failed loading support module ($defPath) for RAW converter '$CONVERTER_NAME':  $tclResult ($execResult)"
    } else { ;  # loaded successfully
      global WBPARAM1_PATTERN WBPARAM2_PATTERN WBPARAM3_PATTERN
      global WBPARAM1_SUBMATCH_INDEX WBPARAM2_SUBMATCH_INDEX WBPARAM3_SUBMATCH_INDEX
      #ok_trace_msg "Set [WBParamName 1] pattern to '$WBPARAM1_PATTERN'"
      #TODO: keep the below print open - I saw wrong expectation of tint2 for Aftershot
      ok_trace_msg "Set 3rd WB-parameter ([WBParamName 3]) pattern to '$WBPARAM3_PATTERN', submatch-index to $WBPARAM3_SUBMATCH_INDEX"
      #tk_messageBox -message "$CONVERTER_NAME: Set [WBParamName 3] pattern to '$WBPARAM3_PATTERN'" -title DEBUG
    }
  } else {
    ok_err_msg "Unsupported RAW converter '$rcName'; please choose one of: [array names _RCONV_CONFIG_FILES]"
  }
}
SetRAWConverter $INITIAL_CONVERTER_NAME


# Returns {wbParam1, wbParam2, wbParam3(or -1)}
proc GetSurfaceColorParamsAsList {}  {
  global WBPARAM1_SURFACE WBPARAM2_SURFACE WBPARAM3_SURFACE
  return  [list $WBPARAM1_SURFACE $WBPARAM2_SURFACE $WBPARAM3_SURFACE]
}


#~ proc FindSettingsFiles {rawDir} {
  #~ set tclResult [catch {
    #~ set res [glob [file join $rawDir [SettingsFileName "*"]]] } execResult]
    #~ if { $tclResult != 0 } { ok_err_msg "$execResult!";  return  [list]  }
  #~ return  $res
#~ }


proc FindSettingsFilesOrComplain {rawDir allSettingsListVar} {
  upvar $allSettingsListVar allSettings
  ##set allSettings [FindSettingsFiles $rawDir 0]
  set allSettings [FindSettingsFilesForDive $rawDir cntMissing 0]
  if { 0 == [llength $allSettings] } {
    ok_err_msg "No converter settings-files found in '[pwd]'"
    return  0
  }
  if { $cntMissing > 0 } {
    ok_err_msg "Missing converter settings file(s) for $cntMissing RAW(s) in '[pwd]'"
    return  0
  }
  return  1
}


# Reads from settings file for 'pureName' 2-3 converter-specific color parameters
# (example: color-tempreture, standard-tint, and maybe additional-tint)
# into 'wbParam1', 'wbParam2', 'wbParam3'.
# If wbParam3 is irrelevant, sets it to -1.
# Returns 1 on success, 0 on error.
proc ReadWBParamsFromSettingsFile {pureName rawDir wbParam1 wbParam2 wbParam3} {
  upvar $wbParam1  tm
  upvar $wbParam2  tn1
  upvar $wbParam3  tn2
  if { "" == [set settingsStr [_ReadSettingsFile $pureName $rawDir]] }  {
    return  0;  # error already printed
  }
  if { 0 == [_ReadWBParamsFromSettingsString $settingsStr tm tn1 tn2] }  {
    #ok_err_msg "Failed reading WB parameters from '$pureName'"
    return  0
  }
  return  1
}



# Changes WB parameters in the settings file for 'pureName'
# to those taken from 'wbParam1', 'wbParam2' and maybe 'wbParam3'.
# Returns 1 on success, 0 on error
proc WriteWBParamsIntoSettingsFile {pureName rawDir wbParam1 wbParam2 wbParam3} {
  if { "" == [set oldSettingsStr [_ReadSettingsFile $pureName $rawDir]] }  {
    return  0;  # error already printed
  }
  if { 0 == [_WriteWBParamsIntoSettingsString $oldSettingsStr \
                                $wbParam1 $wbParam2 $wbParam3 newSettingsStr] }  {
    return  0;  # error already printed
  }
  return  [_WriteSettingsFile $pureName $rawDir $newSettingsStr]
}


# Reads and returns as one string full settings file for 'pureName'.
# On error returns "".
proc _ReadSettingsFile {pureName rawDir}  {
  set sPath [FindSettingsFile $pureName $rawDir 1]
  if { $sPath == "" }  {  return  "" };  # error already printed
  if [catch {open $sPath "r"} fileId] {
    ok_err_msg "Cannot open '$sPath' for reading: $fileId"
    return  ""
  }
  set tclExecResult [catch {set data [read $fileId]} execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed reading settings for '$pureName' from '$sPath': $execResult!"
    return  ""
  }
  close $fileId
  return $data
}


# Writes full settings from 'settingsStr' into the settings file for 'pureName'.
# Returns 1 on success, 0 on error.
proc _WriteSettingsFile {pureName rawDir settingsStr} {
  set sPath [FindSettingsFile $pureName $rawDir 0]
  if { $sPath == "" }  {  return  0 };  # error already printed
  if [catch {open $sPath "w"} fileId] {
    ok_err_msg "Cannot open '$sPath' for writting: $fileId"
    return  0
  }
  set tclExecResult [catch {puts -nonewline $fileId $settingsStr} execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed writting settings for '$pureName' into '$sPath': $execResult!"
    return  0
  }
  close $fileId
  return 1
}


# Reads from 'settingsStr' 2-3 WB parameters into 'wbParam1','wbParam2','wbParam3'
# (example: color-tempreture, standard-tint, and maybe wbParam3)
# If wbParam3 is irrelevant, sets it to -1.
# Returns 1 on success, 0 on error
proc _ReadWBParamsFromSettingsString {settingsStr wbParam1 wbParam2 wbParam3} {
  global WBPARAM1_PATTERN WBPARAM2_PATTERN WBPARAM3_PATTERN
  global WBPARAM1_SUBMATCH_INDEX WBPARAM2_SUBMATCH_INDEX WBPARAM3_SUBMATCH_INDEX
  upvar $wbParam1  tm
  upvar $wbParam2      tn1
  upvar $wbParam3      tn2
  if { 1 != [regexp $WBPARAM1_PATTERN $settingsStr full1 \
                                       s1 s2 s3 s4 s5 s6 s7 s8 s9] }  {
    ok_err_msg "Failed reading [WBParam1Name] from line '$settingsStr'"
    return  0
  }
  set subMatches [list dummy $s1 $s2 $s3 $s4 $s5 $s6 $s7 $s8 $s9]
  set tm [lindex $subMatches $WBPARAM1_SUBMATCH_INDEX]
  if { 1 != [regexp $WBPARAM2_PATTERN $settingsStr full2 \
                                       s1 s2 s3 s4 s5 s6 s7 s8 s9] }  {
    ok_err_msg "Failed reading [WBParam2Name] from line '$settingsStr'"
    return  0
  }
  set subMatches [list dummy $s1 $s2 $s3 $s4 $s5 $s6 $s7 $s8 $s9]
  set tn1 [lindex $subMatches $WBPARAM2_SUBMATCH_INDEX]
  if { [WBParam3IsUsed] } {
    if { 1 != [regexp $WBPARAM3_PATTERN $settingsStr full3 \
                                       s1 s2 s3 s4 s5 s6 s7 s8 s9] }  {
      ok_err_msg "Failed reading [WBParam3Name] from line '$settingsStr'"
      return  0
    }
    set subMatches [list dummy $s1 $s2 $s3 $s4 $s5 $s6 $s7 $s8 $s9]
    set tn2 [lindex $subMatches $WBPARAM3_SUBMATCH_INDEX]
  } else { set tn2 -1 }
  # verify validity of the WB parameters being read
  set allParams [list $tm $tn1 $tn2];  set allMatches [list $full1 $full2]
  if { [WBParam3IsUsed] } { lappend allMatches $full3 }
  for {set i 0} {$i < [expr {([WBParam3IsUsed])? 3:2}]} {incr i 1} {
    set paramAsStr [string trim [lindex $allParams $i]]
    if { 0 == [string length $paramAsStr] }  {
      ok_err_msg "Read empty [WBParamName [expr $i + 1]] from line '[lindex $allMatches $i]'"
      return  0
    }
    if { 0 == [string is double $paramAsStr] }  {
      ok_err_msg "Read invalid [WBParamName [expr $i + 1]] as '$paramAsStr' from line '$full'"
      return  0
    }
  }
  return  1
}


# Writes into 'newSettingsStr' a copy of 'oldSettingsStr'
# with WB parameters taken from 'wbParam1', 'wbParam2' and maybe 'wbParam3'.
# Returns 1 on success, 0 on error
proc _WriteWBParamsIntoSettingsString {oldSettingsStr \
                                            wbParam1 wbParam2 wbParam3 \
                                            newSettingsStr} {
  global WBPARAM1_PATTERN WBPARAM2_PATTERN WBPARAM3_PATTERN WBPARAM123_PATTERN
  global WBPARAM1_FORMAT WBPARAM2_FORMAT WBPARAM3_FORMAT WBPARAM123_FORMAT
  upvar $newSettingsStr  newSettings
  if { ![WBParamFormat123IsUsed] }  { ; # replace each WB param individually
    set newWBParam1   [ format $WBPARAM1_FORMAT $wbParam1]
    set newWBParam2   [ format $WBPARAM2_FORMAT  $wbParam2]
    set newWBParam3 [expr {([WBParam3IsUsed])? \
                      [ format $WBPARAM3_FORMAT $wbParam3] : ""}]
    if { 1 != [regsub -- $WBPARAM1_PATTERN $oldSettingsStr $newWBParam1 \
                      tmpSettings1] }  {
      ok_err_msg "Failed overriding [WBParamName 1]";  return  0
    }
    if { 1 != [regsub -- $WBPARAM2_PATTERN $tmpSettings1 $newWBParam2 \
                      tmpSettings2] }  {
      ok_err_msg "Failed overriding [WBParamName 2]";    puts $tmpSettings1
      return  0
    }
    if { [WBParam3IsUsed] }  {
      if { 1 != [regsub -- $WBPARAM3_PATTERN $tmpSettings2 $newWBParam3 \
                        newSettings] }  {

          ok_err_msg "Failed overriding [WBParamName 3]";  puts $tmpSettings2
          return  0
      }
    } else {  set newSettings $tmpSettings2 }
  } else {                            ; # replace all WB params at once
    set newWBFullSpec123 [format $WBPARAM123_FORMAT \
                                {*}[list $wbParam1 $wbParam2 \
                                [expr {([WBParam3IsUsed])? $wbParam3 : ""}]]]
    if { 1 != [regsub -- $WBPARAM123_PATTERN $oldSettingsStr $newWBFullSpec123 \
                         newSettings] }  {
      ok_err_msg "Failed overriding all [WBParamName 1], [WBParamName 2], [WBParamName 3] at once"
      return  0
    }
  }
  return  1
}


proc SafeMassageColorParamsForConverter {srcDescr cp1Var cp2Var cp3Var} {
  upvar $cp1Var cp1;  upvar $cp2Var cp2;  upvar $cp3Var cp3
  set tclResult [catch {
    set list4Massage [PackWBParamsForConverter $cp1 $cp2 $cp3]
    MassageColorParamsForConverter list4Massage
    ParseWBParamsForConverter $list4Massage cp1 cp2 cp3
  } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed 'massaging' converter WB parameters of '$srcDescr': $execResult"
    return  0
  }
  return  1
}


# Returns list of color parameters as expected by 'MassageColorParamsForConverter'
proc PackWBParamsForConverter {wbParam1 wbParam2 wbParam3}  {
  return  [list $wbParam1 $wbParam2 $wbParam3]
}


# Reads converter-specific color parameters into the supplied variables
proc ParseWBParamsForConverter {wbParamsAsList \
                                    wbParam1Var wbParam2Var wbParam3Var} {
  upvar $wbParam1Var wbParam1
  upvar $wbParam2Var wbParam2
  upvar $wbParam3Var wbParam3
  set wbParam1 [lindex $wbParamsAsList 0]
  set wbParam2 [lindex $wbParamsAsList 1]
  set wbParam3 [lindex $wbParamsAsList 2]
}


proc PackColorMultsForConverter {multR multG multB}   {
  return  [list $multR $multG $multB]
}


# Reads converter-specific color multipliers into the supplied variables
proc ParseColorMultsForConverter {colorMultsAsList multR multG multB}  {
  upvar $multR mR
  upvar $multG mG
  upvar $multB mB
  set mR [lindex $colorMultsAsList 0]
  set mG [lindex $colorMultsAsList 1]
  set mB [lindex $colorMultsAsList 2]
}


proc SettingsFilesAreConsistent {depth1 sPath1 depth2 sPath2}  {
  global IS_SAMPLE_ADJACENT_CALLBACK
  foreach sPath [list $sPath1 $sPath2] {
    if { 0 == [file exists $sPath] }  {
      ok_err_msg "SettingsFilesAreConsistent got inexistent path '$sPath'"
      return  -1
    }
  }
  set purename1 [SettingsFileNameToPurename [file tail $sPath1]]
  set dir1 [file dirname $sPath1]
  if { 0 == [ReadWBParamsFromSettingsFile $purename1 $dir1 \
                                                wbParam11 wbParam21 wbParam31] } {
    return  -1;  # error already printed
  }
  set purename2 [SettingsFileNameToPurename [file tail $sPath2]]
  set dir2 [file dirname $sPath2]
  if { 0 == [ReadWBParamsFromSettingsFile $purename2 $dir2 \
                                                wbParam12 wbParam22 wbParam32] } {
    return  -1;  # error already printed
  }
  # build dummy record for both; call IS_SAMPLE_ADJACENT_CALLBACK
  set dcRec1 [PackDepthColorRecord  $purename1 99 \
                                    $depth1 $wbParam11 $wbParam21 $wbParam31]
  set dcRec2 [PackDepthColorRecord  $purename2 99 \
                                    $depth2 $wbParam12 $wbParam22 $wbParam32]
  if { $depth1 < $depth2 } { set dcRecHi $dcRec1;  set dcRecLo $dcRec2
  } else                   { set dcRecHi $dcRec2;  set dcRecLo $dcRec1 }
  if { 0 == [$IS_SAMPLE_ADJACENT_CALLBACK $dcRecHi $dcRecLo] } {
    ok_err_msg "Inconsistent color parameter(s) for overriden depth between '$sPath1' and '$sPath2'"
    return  0
  }
  return  1
}


##### Search for settings files moved here,
#####        since some converters force standard location


# Mostly for testing
proc FindSettingsFiles {subdirName {priErr 1}} {
  global SETTINGS_DIR
  if { $SETTINGS_DIR != "" }  { set settingsDir $SETTINGS_DIR ;   # std dir
  } else                      { set settingsDir $subdirName   }
  return  [FindSettingsFilesInDir $settingsDir $priErr]
}


# Mostly for testing
proc FindSettingsFilesInDir {dirPath {priErr 1}} {
  # TODO: improve pattern - use extension for the converter or all extensions
  set fullPattern [file join $dirPath [SettingsFileName "*"]]
  set res [list]
  set tclResult [catch { set res [glob $fullPattern] } execResult]
  if { $tclResult != 0 } {
    if { $priErr != 0 }  {
      ok_err_msg "Failed searching for files matching <$fullPattern> (called by '[ok_callername]'): $execResult"
    }
    return  [list]
  }
  # filter out unnecessary files
  # we may have picked settings for other converters; filter these out
  # TODO: use [_SelectRelevantSettingsFiles $allFilePathsForOneRaw]
  set fRes [list]
  foreach sP $res {
    set settingsFileName [file tail $sP]
    set purename [SettingsFileNameToPurename $settingsFileName]
    set expSettingsName [SettingsFileName $purename]
    if { 0 == [string compare -nocase $settingsFileName $expSettingsName] } {
      lappend fRes $sP
    } else {
      ok_trace_msg "Settings file '$sP' assumed to belong to other RAW converter (pure-name=='$purename', expected-settings-name='$expSettingsName')"
    }    
  }
  return  $fRes
}


# For mainstream usage
# Returns list of settings paths for RAWs of the current dive
#    that reside under 'subdirName' (e.g. RAWs are under 'subdirName').
# Puts into 'cntMissing' number of RAWs for which no settings files found.
proc FindSettingsFilesForDive {subdirName cntMissing {priErr 1}} {
  global PICK_TARGETS PICK_PHOTOS PICK_ALL
  global WORK_DIR SETTINGS_DIR
  upvar $cntMissing cntMiss
  set cntMiss 0
  set rawPaths [FindRawInputs $subdirName]
  if { $SETTINGS_DIR != "" }  {
    set settingsDir $SETTINGS_DIR ;   # full path of standard dir
  } else {
    set settingsDir [file join $WORK_DIR $subdirName]
  }
  set settingsPaths [list]
  foreach rawPath $rawPaths {
    set rawName [file tail $rawPath]
    set allFilesForOneRaw [FindAllInputsForOneRAWInDir $rawName $settingsDir]
    set relevantSettingsFiles [_SelectRelevantSettingsFiles $allFilesForOneRaw]
    if { 0 == [llength $relevantSettingsFiles] }  {
      incr cntMiss 1
      if { $priErr == 1 }  {
        ok_err_msg "No relevant settings files found for '$rawPath' in '$settingsDir'"
      }
    } else {
      set settingsPaths [concat $settingsPaths $relevantSettingsFiles]
    }
  }
  ok_info_msg "Found [llength $settingsPaths] settings file(s) (in directory '$settingsDir') for [llength $rawPaths] RAWs in '$subdirName'"
  ##if { $cntMiss > 0 }  {error "Missing $cntMiss settings file(s) in '$settingsDir'"} ;   #OK_TMP
  return  $settingsPaths
}


proc FindAllSettingsFilesForOneRaw {rawPath {priErr 1}} {
  global WORK_DIR SETTINGS_DIR
  set rawName [file tail $rawPath]
  set rawDir  [file dirname $rawPath]
  if { $SETTINGS_DIR != "" }  {
    set settingsDir $SETTINGS_DIR ;   # full path of standard dir
  } else {
    set settingsDir $rawDir
  }
  set allFilesForOneRaw [FindAllInputsForOneRAWInDir $rawName $settingsDir]
  # the RAW itself could be included; drop it then
  for {set i 0} {$i < [llength $allFilesForOneRaw]} {incr i 1} {
    set filePath [lindex $allFilesForOneRaw $i]
    #ok_trace_msg "'$filePath' considered [expr {(1 == [IsRawImageName $filePath])? {RAW-file} : {settings-file}}]"
    if { 1 == [IsRawImageName $filePath] }  {
      set allFilesForOneRaw [lreplace $allFilesForOneRaw $i $i]
      break
    }
  }
  #ok_trace_msg "Settings file(s) for '$rawName': {$allFilesForOneRaw}"
  if { ($priErr == 1) && (0 == [llength $allFilesForOneRaw]) }  {
    ok_warn_msg "No settings file for '$rawName' found in '$settingsDir'"
  }
  return  $allFilesForOneRaw
}


proc _SelectRelevantSettingsFiles {allFilePathsForOneRaw}  {
  # filter out unnecessary files
  # we may have picked settings for other converters; filter these out
  set fRes [list]
  foreach sP $allFilePathsForOneRaw {
    set settingsFileName [file tail $sP]
    set purename [SettingsFileNameToPurename $settingsFileName]
    set expSettingsName [SettingsFileName $purename]
    if { 0 == [string compare -nocase $settingsFileName $expSettingsName] } {
      lappend fRes $sP
    } else {
      ok_trace_msg "Settings file '$sP' assumed to belong to other RAW converter (pure-name=='$purename', expected-settings-name='$expSettingsName')"
    }    
  }
  return  $fRes
}


# Mostly for testing
proc FindRawColorTargetsSettings {{priErr 1}} {
  global RAW_COLOR_TARGET_DIR
  return  [FindSettingsFiles $RAW_COLOR_TARGET_DIR $priErr]
}

# Mostly for testing
proc FindUltimateRawPhotosSettings {{priErr 1}} {
  return  [FindSettingsFiles "" $priErr]
}

# For mainstream usage
proc FindRawColorTargetsSettingsForDive {{priErr 1}} {
  global RAW_COLOR_TARGET_DIR
  return  [FindSettingsFilesForDive $RAW_COLOR_TARGET_DIR cntMissing $priErr]
}

# For mainstream usage
proc FindUltimateRawPhotosSettingsForDive {{priErr 1}} {
  return  [FindSettingsFilesForDive "" cntMissing $priErr]
}



proc ListRAWsAndSettingsFiles {subdirName \
                                purenameToRawVar purenameToSettingsVar}  {
  global WORK_DIR SETTINGS_DIR
  upvar $purenameToRawVar purenameToRaw
  upvar $purenameToSettingsVar purenameToSettings
  array unset purenameToRaw;  array unset purenameToSettings
  set rawDir  [file join $WORK_DIR $subdirName]
  set allRAws [FindRawInputs $rawDir]
  if { $SETTINGS_DIR != "" }  { ;  # settings for the RAWs; no unmatched settings
    set allSettings [FindSettingsFilesForDive $subdirName cntMissing 0]
  } else { ; # all settings in dive dir; some settings could be unmatched
    set allSettings [FindSettingsFiles $subdirName 0]
  }
  foreach f $allRAws {
    set purenameToRaw([string toupper [file rootname [file tail $f]]])  $f
  }
  ok_trace_msg "Image names for which RAWs exist: {[array names purenameToRaw]}"
  foreach f $allSettings {
    set purenameToSettings([string toupper [SettingsFileNameToPurename \
                                                      [file tail $f]]])  $f
  }
  ok_trace_msg "Image names for which settings exist: {[array names purenameToSettings]}"
}


#~ proc ListRAWsAndSettingsFilesForGrayTargets { \
                                      #~ purenameToRawVar purenameToSettingsVar}  {
  #~ global RAW_COLOR_TARGET_DIR
  #~ upvar $purenameToRawVar purenameToRaw
  #~ upvar $purenameToSettingsVar purenameToSettings
  #~ return  [ListRAWsAndSettingsFiles $RAW_COLOR_TARGET_DIR \
                                     #~ purenameToRaw purenameToSettings]
#~ }


#~ proc ListRAWsAndSettingsFilesForUltimatePhotos { \
                                      #~ purenameToRawVar purenameToSettingsVar}  {
  #~ upvar $purenameToRawVar purenameToRaw
  #~ upvar $purenameToSettingsVar purenameToSettings
  #~ return  [ListRAWsAndSettingsFiles "" \
                                     #~ purenameToRaw purenameToSettings]
#~ }
