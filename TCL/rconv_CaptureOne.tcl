# rconv_CaptureOne.tcl

##################### A mandatory set of 'global' declarations: ################
### 'global' declarations here allow to 'source' this code from within a proc ##
# directory where settings (sidecar) files are stored; "" if they are near RAWs
global SETTINGS_DIR
## per-converter color-parameters' names
global WBPARAM_NAMES
## per-converter color-parameter keywords in conversion settings files
global WBPARAM123_PATTERN WBPARAM1_PATTERN WBPARAM2_PATTERN WBPARAM3_PATTERN
global WBPARAM1_SUBMATCH_INDEX WBPARAM2_SUBMATCH_INDEX WBPARAM3_SUBMATCH_INDEX
global WBPARAM123_FORMAT WBPARAM1_FORMAT WBPARAM2_FORMAT WBPARAM3_FORMAT
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

# optional helper callback to assist in testing
# takes 2 lists of WB-params; returns 1/0 (==/!=)
set WBPARAMS_EQU_OPTIONAL_CALLBACK 0
################################################################################


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]
source [file join $SCRIPT_DIR   "common_utils.tcl"]

# settings files stored in a standard dir
global env ;  # needed since we load it from within a proc
if { 0 == [info exist env(LOCALAPPDATA)] }  {
  set msg {CaptureOne requires environment variable LOCALAPPDATA; please define it in the OS. (Example (Win8.1): 'C:\Users\oleg_2\AppData\Local'}
  ok_err_msg $msg;  error $msg
}
set _localAppDir  [file normalize $env(LOCALAPPDATA)]
set SETTINGS_DIR  [file join $_localAppDir "CaptureOne" "Styles50"]

set WBPARAM_NAMES {"color-temperature" "color-tint" ""}

set WBPARAM123_PATTERN  "" ;  # indicate it's unused
## (color-temperature line)   <E K="WhiteBalanceTemperature" V="24946.438" />
set WBPARAM1_PATTERN   {K="WhiteBalanceTemperature" V="([.0-9]+)"}
set WBPARAM1_SUBMATCH_INDEX 1
## (color-tint line)          <E K="WhiteBalanceTint" V="4.731" />
set WBPARAM2_PATTERN   {K="WhiteBalanceTint" V="(-?[.0-9]+)"}
set WBPARAM2_SUBMATCH_INDEX 1
set WBPARAM3_PATTERN  {}
set WBPARAM3_SUBMATCH_INDEX -1

set WBPARAM123_FORMAT  "" ; # indicate it's unused
set WBPARAM1_FORMAT  {K="WhiteBalanceTemperature" V="%.3f"}
set WBPARAM2_FORMAT  {K="WhiteBalanceTint" V="%.3f"}
set WBPARAM3_FORMAT  {}

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
proc _AreGraySamplesConsistent_CaptureOne {dataList1 dataList2}  {
  # 'dataList1'/'dataList2': {pure-name depth time colorTemp colorTint [-1]}
  ParseDepthColorRecord $dataList1 n1 time1 depth1 colorTemp1 colorTint1 tint21
  ParseDepthColorRecord $dataList2 n2 time2 depth2 colorTemp2 colorTint2 tint22
  if { ($depth2 > ($depth1 + [GetDepthResolution])) && \
        ($colorTemp2 >= $colorTemp1) && ($colorTint2 <= $colorTint1) } {
    #ok_trace_msg "_AreGraySamplesConsistent_CaptureOne: {$depth1/$colorTemp1/$colorTint1} and {$depth2/$colorTemp2/$colorTint2} are consistent"
    return  1
  }
  return  0
}
set IS_SAMPLE_ADJACENT_CALLBACK _AreGraySamplesConsistent_CaptureOne


set EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK 0; # use generic proc
set EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK 0; # use generic proc


proc SettingsFileName {pureName} {
  global RAW_EXTENSION
  return  "$pureName.costyle"
}


proc FindSettingsFile {pureName rawDir {checkExist 1}} {
  global SETTINGS_DIR RAW_EXTENSION
  return  [FindFilePath $SETTINGS_DIR $pureName \
                        "costyle" "Settings" \
                        $checkExist]
}

#~ proc SettingsFileNameToPurename {settingsName} {
  #~ global RAW_EXTENSION
  #~ return  [file rootname $settingsName]
#~ }


# ?TODO?
proc MassageColorParamsForConverter {wbParamListVar} {
  upvar $wbParamListVar wbParamList
  ParseWBParamsForConverter $wbParamList wbParam1 wbParam2 dummyParam3
  # the results should be consistent with the format spec
  set wbParam1M [string trim [format "%.3f" $wbParam1]];  # restrict precision
  set wbParam2M [string trim [format "%.3f" $wbParam2]];  # restrict precision
  set wbParamList [PackWBParamsForConverter $wbParam1M $wbParam2M $dummyParam3]
  return
}
