# rconv_PhotoNinja.tcl

##################### A mandatory set of 'global' declarations: ################
### 'global' declarations here allow to 'source' this code from within a proc ##
# directory where settings (sidecar) files are stored; "" if they are near RAWs
global SETTINGS_DIR
## per-converter color-parameters' names
global WBPARAM_NAMES
## per-converter color-parameter keywords in conversion settings files
global WBPARAM123_PATTERN WBPARAM1_PATTERN WBPARAM2_PATTERN WBPARAM3_PATTERN
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

# optional helper callback to assist in testing
# takes 2 lists of WB-params; returns 1/0 (==/!=)
set WBPARAMS_EQU_OPTIONAL_CALLBACK 0
################################################################################


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]
source [file join $SCRIPT_DIR   "common_utils.tcl"]

set SETTINGS_DIR    ""  ; # settings files stored together with RAWs

set WBPARAM_NAMES {"red-divider" "green-divider" "blue-divider"}

# in PhotoNinja we need to override "RGB dividers" that come in one line;
## example: <pn:WBRawWhite>74.9752 189.989 119.195</pn:WBRawWhite>
##  
# color-temperature and tint lines exist but aren't read
# ( open-brace indices                  12       3  4           56       7  8           9 )
set _COMMON_WB_PATTERN  {<pn:WBRawWhite>(([0-9]+)(\.([0-9]+))?) (([0-9]+)(\.([0-9]+))?) (([0-9]+)(\.([0-9]+))?)</pn:WBRawWhite>}
set WBPARAM123_PATTERN  "" ;  # indicate it's unused
set WBPARAM1_PATTERN   $_COMMON_WB_PATTERN
set WBPARAM1_SUBMATCH_INDEX 1
set WBPARAM2_PATTERN   $_COMMON_WB_PATTERN
set WBPARAM2_SUBMATCH_INDEX 5
set WBPARAM3_PATTERN  $_COMMON_WB_PATTERN
set WBPARAM3_SUBMATCH_INDEX 9

set WBPARAM123_FORMAT  "" ; # indicate it's unused
set WBPARAM1_FORMAT  {<pn:WBRawWhite>%.4f \5 \9</pn:WBRawWhite>}
set WBPARAM2_FORMAT  {<pn:WBRawWhite>\1 %.4f \9</pn:WBRawWhite>}
set WBPARAM3_FORMAT {<pn:WBRawWhite>\1 \5 %.4f</pn:WBRawWhite>}

# TODO: MAKE IT PER-FILTER ARRAY
set WBPARAM1_SURFACE   4370
set WBPARAM2_SURFACE   1.155
set WBPARAM3_SURFACE  1.000

## per-converter color-parameters' limits
set WBPARAM1_MIN       0.01
set WBPARAM1_MAX       99.99
set WBPARAM2_MIN       0.01
set WBPARAM2_MAX       99.99
set WBPARAM3_MIN      0.01
set WBPARAM3_MAX      99.99


set GREY_TARGET_DATA_HEADER_RCONV [list "global-time" "depth" "red" "green" "blue"] ;  # multipliers ?or sample readings?

set IMAGE_DATA_HEADER_RCONV [list "global-time" "depth" "red" "green" "blue"] ;  # multipliers ?or sample readings?

# Returns 1 if the two samples could be used together
proc _AreGraySamplesConsistent_PhotoNinja {dataList1 dataList2}  {
  # 'dataList1'/'dataList2': {pure-name depth time wbParamR_ wbParamB_ wbParamG_}
  # looks like the values are RBG
  ParseDepthColorRecord $dataList1 n1 time1 depth1 wbParamR_1 wbParamB_1 wbParamG_1
  ParseDepthColorRecord $dataList2 n2 time2 depth2 wbParamR_2 wbParamB_2 wbParamG_2
  # safely assume none of the G or B color-values is zero
  #set rgRatio_1 [expr 1.0 * $wbParamR_1 / $wbParamG_1]
  set rbRatio_1 [expr 1.0 * $wbParamR_1 / $wbParamB_1]
  #set rgRatio_2 [expr 1.0 * $wbParamR_2 / $wbParamG_2]
  set rbRatio_2 [expr 1.0 * $wbParamR_2 / $wbParamB_2]
  #set bgRatio_1 [expr 1.0 * $wbParamB_1 / $wbParamG_1]
  #set bgRatio_2 [expr 1.0 * $wbParamB_2 / $wbParamG_2]

  set descr "{$depth1/$wbParamR_1/$wbParamB_1/$wbParamG_1} and {$depth2/$wbParamR_2/$wbParamB_2/$wbParamG_2}"
  if { ($depth2 > ($depth1 + [GetDepthResolution])) && \
        ($rbRatio_1 > $rbRatio_2) && \
        ($wbParamR_1 > $wbParamR_2) && ($wbParamG_1 < $wbParamG_2) && \
        ($wbParamB_1 > $wbParamB_2) } {
    ok_trace_msg "++ _AreGraySamplesConsistent_PhotoNinja: $descr are consistent"
    return  1
  }
  ok_trace_msg "-- _AreGraySamplesConsistent_PhotoNinja: $descr are inconsistent"
  return  0
}
set IS_SAMPLE_ADJACENT_CALLBACK _AreGraySamplesConsistent_PhotoNinja


set EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK 0; # use generic proc
set EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK 0; # use generic proc


proc SettingsFileName {pureName} {
  global RAW_EXTENSION
  return  "$pureName.xmp"
}


proc FindSettingsFile {pureName rawDir {checkExist 1}} {
  global RAW_EXTENSION
  return  [FindFilePath $rawDir $pureName \
                        "xmp" "Settings" \
                        $checkExist]
}


#~ proc SettingsFileNameToPurename {settingsName} {
  #~ global RAW_EXTENSION
  #~ return  [file rootname $settingsName]
#~ }


# ?TODO?
proc MassageColorParamsForConverter {wbParamListVar} {
  upvar $wbParamListVar wbParamList
  ParseWBParamsForConverter $wbParamList wbParam1 wbParam2 wbParam3
  # the results should be consistent with the format spec
  set wbParam1M [string trim [format "%.4f" $wbParam1]];  # restrict precision
  set wbParam2M [string trim [format "%.4f" $wbParam2]];  # restrict precision
  set wbParam3M [string trim [format "%.4f" $wbParam3]];  # restrict precision
  set wbParamList [PackWBParamsForConverter $wbParam1M $wbParam2M $wbParam3M]
  return
}
