# dir_file_mgr.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]


set DIAGNOSTICS_FILE_NAME "uwic_diagnostics.txt"
set PREFERENCES_FILE_NAME "uwic_ini.csv"

set RAW_COLOR_TARGET_DIR  "RawColorTargets"
set GREY_CROP_DIR         "GreyCrop"
set DATA_DIR              "Data"
##set NEUTRAL_DIR           "Neutral"
set NEUTRAL_DIR           [file join $RAW_COLOR_TARGET_DIR "TIFF16_Adobe"]

set THUMB_DIR             "Thumbnails"
set THUMB_COLORTARGET_DIR [file join $THUMB_DIR "RawColorTargets"]


##set NORMALIZED_DIR        "Normalized"
set NORMALIZED_DIR        [file join $RAW_COLOR_TARGET_DIR "Normalized_dcraw"]
set AS_IF_CLOUDY_DIR      "AsIfCloudy"
set AS_IF_SUNNY_DIR       "AsIfSunny"

set TRASH_ROOT_NAME       "TRASH"

set CONVERT  [file nativename "C:/Program Files/ImageMagick-6.8.6-8/convert.exe"]


set GREY_DATA_FILE          "grey_targets.csv"
set SORTED_GREY_DATA_FILE   "grey_targets_sorted.csv"
set FILTERED_GREY_DATA_FILE "grey_targets_filtered.csv"

set DEPTH_LOG_NAME_PATTERN   "dive_log*.csv"  ;   # glob pattern for dive-log
set DEPTH_LOG_NAME           "UnsetDepthlogName"
set DEPTH_LOG_DEFAULT_NAME   "dive_log.csv"

set DEPTH_OVERRIDE_FILE     "result_depth_override.csv"
set OLD_DEPTH_OVERRIDE_FILE "result_depth_override_prev.csv"


set _LAST_TRASH_DIR_PATH  "" ;  # full path of the last trash/backup dir created

proc GetLastTrashDirPath {}  {
  global _LAST_TRASH_DIR_PATH;  return  $_LAST_TRASH_DIR_PATH
}


proc FindFilePath {dirPath pureName ext descr {checkExist 0}} {
  set fPath [file join $dirPath "$pureName.$ext"]
  if { $checkExist != 0 } {
    if { 0 == [file exists $fPath] } {
      ok_err_msg "$descr file $fPath not found"
      return ""
    }
  }
  return $fPath
}

################################################################################


proc FindPreferencesFile {{checkExist 1}}  {
  global PREFERENCES_FILE_NAME
  set pPath [file join [file normalize "~"] $PREFERENCES_FILE_NAME]
  if { $checkExist && (0 == [file exists $pPath]) } {
    ok_err_msg "Preferences file $pPath not found"
    return ""
  }
  return $pPath
}


# If 'checkExist' ==0, returns the intended location of the dive log.
# If 'checkExist' ==1, and the log inexistent, returns "".
# If 'checkExist' ==1, searches for existing candidate files;
# returns the path if a single candidate found.
# If several candidate dive-logs found (ambiguity), returns "".
proc FindSavedLog {{checkExist 1}} {
  global DATA_DIR
  return  [FindSavedLogInDir $DATA_DIR $checkExist]
}

# If 'checkExist' ==0, returns the intended location of the dive log.
# If 'checkExist' ==1, and the log inexistent, returns "".
# If 'checkExist' ==1, searches for existing candidate files;
# returns the path if a single candidate found.
# If several candidate dive-logs found (ambiguity), returns "".
proc FindSavedLogInDir {logDir checkExist} {
  global DEPTH_LOG_NAME DEPTH_LOG_NAME_PATTERN
  set fullPattern [file join $logDir $DEPTH_LOG_NAME_PATTERN]
  set res [list]
  set tclResult [catch {
    set res [glob -nocomplain -directory $logDir $DEPTH_LOG_NAME_PATTERN]
  } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed searching for dive-log file in directory '$logDir' (pattern: '$DEPTH_LOG_NAME_PATTERN'): $execResult"
    return  ""
  }
  if { 0 == [llength $res] } {
    if { $checkExist } {
      ok_err_msg "Depth-log file not found in directory '$logDir' (name should match '$DEPTH_LOG_NAME_PATTERN')"
      return ""
    }
    set DEPTH_LOG_NAME $DEPTH_LOG_DEFAULT_NAME
    return  [file join $logDir $DEPTH_LOG_DEFAULT_NAME];  # intended location
  }
  if { 1 < [llength $res] } {
    ok_err_msg "Found [llength $res] candidate depth-log files in directory '$logDir' (names match '$DEPTH_LOG_NAME_PATTERN'): {$res}. Please resolve the ambiguity"
    return ""
  }
  set DEPTH_LOG_NAME [lindex $res 0]
  ok_info_msg "Found one candidate depth-log file in directory '$logDir': '$DEPTH_LOG_NAME'"
  return  $DEPTH_LOG_NAME
}


proc IsRawImageName {filePath} {
  global RAW_EXTENSION
  set ext [string range [file extension $filePath] 1 end]; # without leading dot
  if { 0 == [string compare -nocase $ext $RAW_EXTENSION] }  { return 1
  } else {                                                    return 0  }
}


proc FindRawInputs {rawDir} {
  global RAW_EXTENSION
  set tclResult [catch {
    set res [glob [file join $rawDir "*.$RAW_EXTENSION"]] } execResult]
    if { $tclResult != 0 } { ok_err_msg "$execResult!";  return  [list]  }
  return  $res
}


proc FindRawInputsOrComplain {rawDir allRawsListVar} {
  upvar $allRawsListVar allRaws
  set allRaws [FindRawInputs $rawDir]
  if { 0 == [llength $allRaws] } {
    ok_err_msg "No RAW inputs found in '[pwd]'"
    return  0
  }
  return  1
}


proc FindRawInput {rawDir pureName} {
  global RAW_EXTENSION
  set rPath [file join $rawDir "$pureName.$RAW_EXTENSION"]
  if { 1 == [file exists $rPath] } {
    return $rPath
  }
  ok_err_msg "RAW file $rPath not found"
  return ""
}


proc FindRawColorTargets {{priErr 1}} {
  global RAW_COLOR_TARGET_DIR  RAW_EXTENSION
  set tclResult [catch {
    set res [glob [file join $RAW_COLOR_TARGET_DIR "*.$RAW_EXTENSION"]] } execResult]
    if { $tclResult != 0 } {
      if { $priErr != 0 } { ok_err_msg "$execResult!" }
      return  [list]
    }
  return  $res
}


proc SettingsFileNameToPurename {settingsName} {
  return  [AnyFileNameToPurename $settingsName]
}

proc RAWFileNameToPurename {rawName} {
  return  [AnyFileNameToPurename $rawName]
}


proc RAWFileNameToGlobPattern {rawName} {
  set pureName [RAWFileNameToPurename $rawName]
  return  "$pureName.*"
}


# Returns list of files related to RAW 'rawName' in directory 'rawDirPath'
proc FindAllInputsForOneRAWInDir {rawName rawDirPath} {
  set fullPattern [file join $rawDirPath [RAWFileNameToGlobPattern $rawName]]
  set res [list]
  set tclResult [catch { set res [glob $fullPattern] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed searching for input files associated with RAW '$rawName' (pattern: '$fullPattern': $execResult"
    return  [list]
  }
  ok_trace_msg "Found [llength $res] files related to RAW '$rawName'; pattern: '$fullPattern'"
  return  $res
}


#~ proc FindAllInputsForOneRAW {rawName rawDirPath} {
#~ }


# A generic function that returns the name (path portion) before the first dot
proc AnyFileNameToPurename {fileName} {
  set nmp [file rootname $fileName]
  while { 1 }  {
    set nmn [file rootname $nmp]
    if { $nmp == $nmn }  { break; }
    set nmp $nmn
  }
  return  $nmp
}


proc HideUnmatchedRAWsAndSettingsFilesForGrayTargets {actionName \
                                                      trashDirPathVar}  {
  global RAW_COLOR_TARGET_DIR
  upvar $trashDirPathVar trashDir
  return  [_HideUnmatchedRAWsAndSettingsFiles \
                      $actionName $RAW_COLOR_TARGET_DIR "gray target" trashDir]
}


proc HideUnmatchedRAWsAndSettingsFilesForUltimatePhotos {actionName \
                                                        trashDirPathVar}  {
  upvar $trashDirPathVar trashDir
  return  [_HideUnmatchedRAWsAndSettingsFiles \
                      $actionName "" "ultimate photo" trashDir]
}


# Hides unmatched settings-files from 'dirPath' under 'trashDirPathVar';
# if 'trashDirPathVar'=="", set it to generated name.
# Requests abort if unmatched RAW files found.
# Returns "" if everything good, error message if abort requested.
proc _HideUnmatchedRAWsAndSettingsFiles {actionName dirPath imageTypeDescr \
                                         trashDirPathVar}  {
  upvar $trashDirPathVar trashDir
  ok_trace_msg "action: $actionName, directory: '$dirPath'"
  array unset unmatchedRAWs;  array unset unmatchedSettings
  if { 0 == [FindUnmatchedRAWsAndSettingsFiles $dirPath \
                                          unmatchedRAWs unmatchedSettings] }  {
    return  "";   # no problem found
  }
  # list the conflicts, move some files, maybe abort
  foreach f $unmatchedSettings {
    ok_warn_msg "Missing RAW file for $imageTypeDescr converter-settings file '$f'; assuming intentional deletion"
  }

  # do not: set trashDir ""
  if { "" != [set msg [MoveListedFilesIntoTrashDir 0 $unmatchedSettings \
                    "$imageTypeDescr settings" $actionName trashDir]] }  {
    return  $msg
  }
##   if { 0 != [llength $unmatchedSettings] } {
 #     set trashDir [ProvideTrashDir $actionName $trashDir]
 #     if { $trashDir == "" }  { return  "Cannot create backup directory" }
 #     if { 0 > [MoveListedFiles 0 $unmatchedSettings $trashDir] }  {
 #       set msg "Failed to hide $imageTypeDescr unmatched settings file(s) in '$trashDir'"
 #       ok_err_msg $msg;    return  $msg
 #     }
 #     ok_info_msg "[llength $unmatchedSettings] unmatched $imageTypeDescr settings file(s) moved into '$trashDir'"
 #   }
 ##
  if { 0 != [llength $unmatchedRAWs] } {  
    foreach f $unmatchedRAWs {
      ok_err_msg "Missing converter-settings file for $imageTypeDescr RAW file '$f'"
    }
    set msg "Please provide settings file(s) for RAW(s) listed in the log box, then retry"
    ok_info_msg $msg;   # info to avoid inclusion in error count
    return $msg
  }
  return  ""
}


# Finds under WORK_DIR/'subdirName' and lists in the two lists
# RAWs without settings and settings without RAWs
# Returns 1 if anything found; otherwise returns 0.
proc FindUnmatchedRAWsAndSettingsFiles {subdirName \
                                      unmatchedRAWsVar unmatchedSettingsVar}  {
  upvar $unmatchedRAWsVar unmatchedRAWs
  upvar $unmatchedSettingsVar unmatchedSettings
  array unset purenameToRaw;  array unset purenameToSettings
  set unmatchedRAWs [list];  set unmatchedSettings [list]
  ListRAWsAndSettingsFiles $subdirName purenameToRaw purenameToSettings
  foreach name [array names purenameToRaw] {
    if { 0 == [info exists purenameToSettings($name)] }  {
      ok_trace_msg "Unmatched RAW-file for '$name'"
      lappend unmatchedRAWs $purenameToRaw($name)
    }
  }
  foreach name [array names purenameToSettings] {
    if { 0 == [info exists purenameToRaw($name)] }  {
      ok_trace_msg "Unmatched settings-file for '$name'"
      lappend unmatchedSettings $purenameToSettings($name)
    }
  }
  set nNames [expr max( [array size purenameToRaw], \
                        [array size purenameToSettings] )]
  set unRAWs [llength $unmatchedRAWs]; set unSettings [llength $unmatchedSettings]
  set dirPath [file join [GetWorkDirFullPath] $subdirName]
  ok_trace_msg "Out of $nNames image(s) in '$dirPath', $unRAWs RAW(s) and $unSettings settings-file(s) unmatched"
  return  [expr {(0 != $unRAWs) || (0 != $unSettings)}]
}


proc FindUnmatchedRAWsAndSettingsFilesForGrayTargets { \
                                      unmatchedRAWsVar unmatchedSettingsVar}  {
  global RAW_COLOR_TARGET_DIR
  upvar $unmatchedRAWsVar unmatchedRAWs
  upvar $unmatchedSettingsVar unmatchedSettings
  return  [FindUnmatchedRAWsAndSettingsFiles $RAW_COLOR_TARGET_DIR \
                                      unmatchedRAWs unmatchedSettings]
}


proc FindUnmatchedRAWsAndSettingsFilesForUltimatePhotos { \
                                      unmatchedRAWsVar unmatchedSettingsVar}  {
  upvar $unmatchedRAWsVar unmatchedRAWs
  upvar $unmatchedSettingsVar unmatchedSettings
  return  [FindUnmatchedRAWsAndSettingsFiles "" \
                                      unmatchedRAWs unmatchedSettings]
}

################################################################################

# Safely attempts to switch dir to 'WORK_DIR'; returns "" on success.
# On error returns error message.
proc cdToWorkdirOrComplain {closeOldDiagnostics}  {
  global WORK_DIR DATA_DIR DIAGNOSTICS_FILE_NAME
  if { 0 == [IsWorkDirOK] }  {
    set msg "<$WORK_DIR> is not a valid working directory"
    return  $msg
  }
  set tclResult [catch { set res [cd $WORK_DIR] } execResult]
  if { $tclResult != 0 } {
    set msg "Failed changing work directory to <$WORK_DIR>: $execResult!"
    ok_err_msg $msg
    return  $msg
  }
  if { $closeOldDiagnostics }  {
    ok_finalize_diagnostics;  # if old file was open, close it
  }
  ok_init_diagnostics [file join $WORK_DIR $DATA_DIR $DIAGNOSTICS_FILE_NAME]
  ok_info_msg "Working directory set to '$WORK_DIR'"
  return  ""
}


################################################################################

proc GetWorkDirFullPath {}  {
  global WORK_DIR DATA_DIR
  return $WORK_DIR
}


proc GetDataDirFullPath {}  {
  global WORK_DIR DATA_DIR
  return [file join $WORK_DIR $DATA_DIR]
}


proc GetGrayTargetsDirFullPath {}  {
  global WORK_DIR RAW_COLOR_TARGET_DIR
  return [file join $WORK_DIR $RAW_COLOR_TARGET_DIR]
}

# Returns 1 if 'WORK_DIR' is a directory suitable for work-area
proc IsWorkDirOK {}  {
  global WORK_DIR
  set bad [expr {($WORK_DIR == "") || (0 == [file exists $WORK_DIR]) || \
                 (0 == [file isdirectory $WORK_DIR])}]
  return  [expr {$bad == 0}]
}


# Returns 1 if 'WORK_DIR' is a directory suitable for work-area
# AND it contains the essential inputs.
# Detects RAW extension for the work-area
proc CheckWorkArea {}  {
  global WORK_DIR RAW_EXTENSION
  if { 0 == [IsWorkDirOK] }  {  return  0  }
  if { "" == [FindSavedLog] }  {  return  0  }
  if { 1 != [llength [set rawExtList [FindRawExtensionsInDir $WORK_DIR]]] } {
    ok_err_msg "Directory '$WORK_DIR' has file(s) with [llength $rawExtList] known RAW extension(s): {$rawExtList}; should be exactly one - all images should come from one camera"
    return  0
  }
  set RAW_EXTENSION [lindex $rawExtList 0]
  ok_info_msg "RAW extension in directory '$WORK_DIR' is '$RAW_EXTENSION'"
  if { 0 == [llength [FindRawInputs $WORK_DIR]] } {  return  0  }
  return  1
}


proc CanWriteFile {fPath}  {
  if { $fPath == "" }  { return  0 }
  if { 0 == [file exists $fPath] }  { return  1 }
  if { 1 == [file isdirectory $fPath] }  { return  0 }
  if { 0 == [file writable $fPath] }  { return  0 }
  return  1
}


# On success returns empty string
proc MoveListedFilesIntoTrashDir {preserveSrc pathList \
                                  fileTypeDescr actionName trashDirVar} {
  upvar $trashDirVar trashDir
  if { 0 != [llength $pathList] } {
    ok_trace_msg "MoveListedFilesIntoTrashDir for '$actionName' called with trashDir='$trashDir'"
    set trashDir [ProvideTrashDir $actionName $trashDir]
    if { $trashDir == "" }  { return  "Cannot create backup directory" }
    if { 0 > [MoveListedFiles $preserveSrc $pathList $trashDir] }  {
      set msg "Failed to hide $fileTypeDescr file(s) in '$trashDir'"
      ok_err_msg $msg;    return  $msg
    }
    ok_info_msg "[llength $pathList] $fileTypeDescr file(s) moved into '$trashDir'"
  }
  return  ""
}


# Moves/copies files in 'pathList' into 'destDir' - if 'preserveSrc' == 0/1.
# Destination directory 'destDir' should preexist.
# On success returns number of files moved;
# on error returns negative count of errors
proc MoveListedFiles {preserveSrc pathList destDir} {
  set action [expr {($preserveSrc == 1)? "copy" : "rename"}]
  if { ![file exists $destDir] } {
    ok_err_msg "MoveListedFiles: no directory $destDir"
    return  -1
  }
  if { ![file isdirectory $destDir] } {
    ok_err_msg "MoveListedFiles: non-directory $destDir"
    return  -1
  }
  set cntGood 0;  set cntErr 0
  foreach pt $pathList {
    set tclExecResult [catch { file $action -- $pt $destDir } evalExecResult]
    if { $tclExecResult != 0 } {
      ok_err_msg "$evalExecResult!";  incr cntErr 1
    } else {                          incr cntGood 1  }
  }
  return  [expr { ($cntErr == 0)? $cntGood : [expr -1 * $cntErr] }]
}


proc ProvideTrashDir {callerAction {trashDirPath ""}}  {
  global WORK_DIR TRASH_ROOT_NAME _LAST_TRASH_DIR_PATH
  if { ($trashDirPath != "") && (1 == [file exists $trashDirPath]) }  {
    return  $trashDirPath
  }
  set trashRootDir [file join $WORK_DIR $TRASH_ROOT_NAME]
  if { ![file exists $trashRootDir] } { ;   # create root-dir at first use
    set tclExecResult [catch { file mkdir $trashRootDir } evalExecResult]
    if { $tclExecResult != 0 } {
      ok_err_msg "Failed creating backup root directory '$trashRootDir': $evalExecResult!"
      return  ""
    }
    ok_info_msg "Created root directory for trash/backup: '$trashRootDir'"
  }
  set nAttempts 4;  # will try up to 'nAttempts' different names
  for {set i 1} {$i <= $nAttempts} {incr i 1}  {
    set timeStr [clock format [clock seconds] -format "%Y-%m-%d_%H-%M-%S"]
    set idStr [format "%s__%s__%d" $timeStr $callerAction $i]
    set trashDirPath [file join $trashRootDir $idStr]
    if { 1 == [file exists $trashDirPath] }  {
      ok_trace_msg "Directory named '$trashDirPath' exists; cannot use it for backup"
      set trashDirPath "";  continue
    }
    set _LAST_TRASH_DIR_PATH "" ;  # to avoid telling old path on failure
    set tclExecResult [catch { file mkdir $trashDirPath } evalExecResult]
    if { $tclExecResult != 0 } {
      ok_err_msg "Failed creating backup directory '$trashDirPath' (attempt $i): $evalExecResult!"
      return  ""
    }
    ok_info_msg "Created directory for trash/backup: '$trashDirPath'"
    set _LAST_TRASH_DIR_PATH [file normalize $trashDirPath]
    break;  # created with path '$trashDirPath'
    set trashDirPath "";  # indicates failure to create dir so far
    after 1000;  # pause for 1 sec, so that next attempt picks different name
  }
  
  if { $trashDirPath == "" }  {
    ok_err_msg "Failed to create directory for trash/backup for '$callerAction'"
  }
  return  $trashDirPath
}


# Returns -1 if 'path1' is older than 'path2', 1 if newer, 0 if same time.
proc CompareFileDates {path1 path2} {
  # fill attr arrays for old and new files:
  #      atime, ctime, dev, gid, ino, mode, mtime, nlink, size, type, uid
  set tclExecResult [catch {
    file stat $path1 p1Stat
    file stat $path2 p2Stat
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed reading attributes of settings file(s) '$path1' and/or '$path2': $evalExecResult!"
    return  0;  # TODO: invent some error indication
  }
  ok_trace_msg "Dates of '$path1':\t atime=$p1Stat(atime)\t ctime=$p1Stat(ctime)\t mtime=$p1Stat(mtime)"
  ok_trace_msg "Dates of '$path2':\t atime=$p2Stat(atime)\t ctime=$p2Stat(ctime)\t mtime=$p2Stat(mtime)"
  # compare ??? time
  if { $p1Stat(mtime) <  $p2Stat(mtime) }  { return  -1 }
  if { $p1Stat(mtime) >  $p2Stat(mtime) }  { return   1 }
  return  0;  # times are equal
}


# Returns list of known RAW extensions (no dot) in directory 'dirPath'
proc FindRawExtensionsInDir {dirPath} {
  global KNOWN_RAW_EXTENSIONS_DICT
  set allExtensions [FindSingleDotExtensionsInDir $dirPath]
  set rawExtensions [list]
  foreach ext $allExtensions {
    if { 1 == [dict exists $KNOWN_RAW_EXTENSIONS_DICT $ext] }  {
      lappend rawExtensions $ext
    }
  }
  ok_info_msg "Found [llength $rawExtensions] known RAW file extension(s) in '$dirPath': {$rawExtensions}"
  return  $rawExtensions
}


# Returns list of extensions (no dot) for files matching "[^./]+\.([^./]+)"
proc FindSingleDotExtensionsInDir {dirPath} {
  set pattern {[^./]+\.([^./]+)$}
  set candidates [glob -nocomplain -directory $dirPath -- "*.*"]
  array unset extensionsArr
  foreach f $candidates {
    #(?slow?) if { 1 == [regexp $pattern $f fullMatch ext] }  {}
    set ext [file extension $f]
    if { 1 < [string length $ext] }  { ;  # includes leading .
      ok_trace_msg "Candidate RAW extension: '$ext'"
      if { 0 < [string length [set ext [string range $ext 1 end]]] }  {
        set extensionsArr([string tolower $ext])  1
      }
    }
  }
  set extensions [array names extensionsArr]
  return  $extensions
}


proc BuildSortedPurenamesList {pathList} {
  set purenames [list]
  foreach p $pathList {
    lappend purenames [AnyFileNameToPurename [file tail $p]]
  }
  return  [lsort $purenames]
}

