# rconv_CorelAfterShot.tcl

##################### A mandatory set of 'global' declarations: ################
### 'global' declarations here allow to 'source' this code from within a proc ##
# directory where settings (sidecar) files are stored; "" if they are near RAWs
global SETTINGS_DIR
## per-converter color-parameters' names
global WBPARAM_NAMES
## per-converter color-parameter keywords in conversion settings files
global WBPARAM1_PATTERN WBPARAM2_PATTERN WBPARAM3_PATTERN
global WBPARAM1_SUBMATCH_INDEX WBPARAM2_SUBMATCH_INDEX WBPARAM3_SUBMATCH_INDEX
global WBPARAM1_FORMAT WBPARAM2_FORMAT WBPARAM3_FORMAT
global WBPARAM1_SURFACE WBPARAM2_SURFACE WBPARAM3_SURFACE
## per-converter color-parameters' limits
global WBPARAM1_MIN WBPARAM1_MAX WBPARAM2_MIN WBPARAM2_MAX
global WBPARAM3_MIN WBPARAM3_MAX
## per-converter gray-target- and image-color-result file headers
global GREY_TARGET_DATA_HEADER_RCONV IMAGE_DATA_HEADER_RCONV
## per-converter callbacks
global IS_SAMPLE_ADJACENT_CALLBACK
global EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK; #shallower than min
global EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK; #deeper than max
################################################################################


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]
source [file join $SCRIPT_DIR   "common_utils.tcl"]

set SETTINGS_DIR    ""  ; # settings files stored together with RAWs

set WBPARAM_NAMES {"color-temperature" "color-tint" ""}

set WBPARAM1_PATTERN   {bopt:kelvin="([0-9]+)"}
set WBPARAM1_SUBMATCH_INDEX 1
set WBPARAM2_PATTERN   {bopt:tint="([0-9]+)"}
set WBPARAM2_SUBMATCH_INDEX 1
set WBPARAM3_PATTERN  {}
set WBPARAM3_SUBMATCH_INDEX -1

set WBPARAM1_FORMAT  {bopt:kelvin="%d"}
set WBPARAM2_FORMAT  {bopt:tint="%d"}
set WBPARAM3_FORMAT {}

# TODO: MAKE IT PER-FILTER ARRAY
set WBPARAM1_SURFACE   5002
set WBPARAM2_SURFACE   25
set WBPARAM3_SURFACE  -1

## per-converter color-parameters' limits
set WBPARAM1_MIN       1500
set WBPARAM1_MAX       25000
set WBPARAM2_MIN       -150
set WBPARAM2_MAX       210
set WBPARAM3_MIN      -1
set WBPARAM3_MAX      -1

set GREY_TARGET_DATA_HEADER_RCONV [list "global-time" "depth" "color-temp" "color-tint" "unused"] ;  # color-temperature and main tint

set IMAGE_DATA_HEADER_RCONV [list "global-time" "depth" "color-temp" "color-tint"] ;  # color temperature and main tint


# Returns 1 if the two samples could be used together
proc _AreGraySamplesConsistent_Aftershot {dataList1 dataList2}  {
  # 'dataList1'/'dataList2': {pure-name depth time colorTemp colorTint [-1]}
  ParseDepthColorRecord $dataList1 n1 time1 depth1 colorTemp1 colorTint1 tint21
  ParseDepthColorRecord $dataList2 n2 time2 depth2 colorTemp2 colorTint2 tint22
  if { ($depth2 > ($depth1 + [GetDepthResolution])) && \
        ($colorTemp2 >= $colorTemp1) && ($colorTint2 >= $colorTint1) } {
    #ok_trace_msg "_AreGraySamplesConsistent_Aftershot: {$depth1/$colorTemp1/$colorTint1} and {$depth2/$colorTemp2/$colorTint2} are consistent"
    return  1
  }
  return  0
}
set IS_SAMPLE_ADJACENT_CALLBACK _AreGraySamplesConsistent_Aftershot


set EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK 0; # use generic proc
set EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK 0; # use generic proc


proc SettingsFileName {pureName} {
  global RAW_EXTENSION
  return  "$pureName.$RAW_EXTENSION.xmp"
}


proc FindSettingsFile {pureName rawDir {checkExist 1}} {
  global RAW_EXTENSION
  return  [FindFilePath $rawDir $pureName \
                        "$RAW_EXTENSION.xmp" "Settings" \
                        $checkExist]
}


#~ proc SettingsFileNameToPurename {settingsName} {
  #~ global RAW_EXTENSION
  #~ set settingsName [string toupper $settingsName]
  #~ set fullExt [string toupper ".$RAW_EXTENSION.xmp"]
  #~ set idx [string first $fullExt $settingsName]
  #~ #ok_trace_msg "'$settingsName' -> '$fullExt' at \[$idx\]"
  #~ if { $idx <= 0 }  {  return  "" }
  #~ return  [string range $settingsName 0 [expr $idx-1]]
#~ }


# Converts values in 'wbParamsListVar' {temp, tint} into integers
proc MassageColorParamsForConverter {wbParamsListVar} {
  upvar $wbParamsListVar colorTempTint
  ParseWBParamsForConverter $colorTempTint colorTemp colorTint dummyTint2
  set colorTempM [expr round($colorTemp)]
  set colorTintM [expr round($colorTint)]
  set colorTempTint [PackWBParamsForConverter $colorTempM $colorTintM \
                                                                  $dummyTint2]
}
