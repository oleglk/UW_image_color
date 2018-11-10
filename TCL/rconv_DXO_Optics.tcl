# rconv_DXO_Optics.tcl

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
################################################################################


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]
source [file join $SCRIPT_DIR   "common_utils.tcl"]

set SETTINGS_DIR    ""  ; # settings files stored together with RAWs

################################################################################
## DXO Optics stores and reads pick-color RGB measurements (not multipliers).
## Need to switch into pick-WB mode by clicking anywhere with pick-color tool.
#### Record example in the settings file:
########  Overrides = {
########  WhiteBalanceRawPreset = "ManualTemp",
########  WhiteBalanceRawInputImageColor = {
########  0.026504715904593468,
########  0.12541073560714722,
########  0.09593663364648819,
########  }
########  ,
########  }
################################################################################
set WBPARAM_NAMES {"red-sample" "green-sample" "blue-sample"}

set WBPARAM123_PATTERN {WhiteBalanceRawInputImageColor = \{\n([0-9.]+),\n([0-9.]+),\n([0-9.]+),\n\}}
set WBPARAM1_PATTERN  $WBPARAM123_PATTERN
set WBPARAM1_SUBMATCH_INDEX 1
set WBPARAM2_PATTERN  $WBPARAM123_PATTERN
set WBPARAM2_SUBMATCH_INDEX 2
set WBPARAM3_PATTERN  $WBPARAM123_PATTERN
set WBPARAM3_SUBMATCH_INDEX 3

# note, format strig enclosed in double-quotes, since curly braces mask <CR> 
set WBPARAM123_FORMAT  "WhiteBalanceRawInputImageColor = {\n%.17f,\n%.17f,\n%.17f,\n}"
set WBPARAM1_FORMAT  {}
set WBPARAM2_FORMAT  {}
set WBPARAM3_FORMAT  {}

# TODO: MAKE IT PER-FILTER ARRAY
# TODO: support upward extrapolation (EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK)
# as of now, there per-conveter surface params aren't used
set WBPARAM1_SURFACE  -1
set WBPARAM2_SURFACE  -1
set WBPARAM3_SURFACE  -1

## per-converter color-parameters' limits
set WBPARAM1_MIN       0
set WBPARAM1_MAX       7  ; # TODO: recheck
set WBPARAM2_MIN       0
set WBPARAM2_MAX       7  ; # TODO: recheck
set WBPARAM3_MIN       0
set WBPARAM3_MAX       7  ; # TODO: recheck
################################################################################

set GREY_TARGET_DATA_HEADER_RCONV [list "global-time" "depth" "red-sample" "blue-sample" "green-sample"] ;  # color-channel measurements

set IMAGE_DATA_HEADER_RCONV [list "global-time" "depth" "red-sample" "blue-sample" "green-sample"] ;  # color-channel measurements


# Returns 1 if the two samples could be used together
# TODO: make blue-sample comparison depend on green-vs-blue water setting
# TODO: for now blue-samples are ignored
proc _AreGraySamplesConsistent_DXO {dataList1 dataList2}  {
  # 'dataList1'/'dataList2': {pure-name depth time redSamp greenSamp blueSamp}
  ParseDepthColorRecord $dataList1 n1 time1 depth1 redSamp1 greenSamp1 blueSamp1
  ParseDepthColorRecord $dataList2 n2 time2 depth2 redSamp2 greenSamp2 blueSamp2
  # normalize the samples so that red value is 0.1
  set mult1  [expr {0.1 / $redSamp1}];    set mult2  [expr {0.1 / $redSamp2}]
  set red1   [expr {$mult1*$redSamp1}];   set red2   [expr {$mult2*$redSamp2}]
  set blue1  [expr {$mult1*$blueSamp1}];  set blue2  [expr {$mult2*$blueSamp2}]
  set green1 [expr {$mult1*$greenSamp1}]; set green2 [expr {$mult2*$greenSamp2}]
  if { ($depth2 > ($depth1 + [GetDepthResolution])) && \
        ($red2 <= $red1) && ($green2 >= $green1) } {
    ok_trace_msg "_AreGraySamplesConsistent_DXO: {$depth1/$redSamp1/$greenSamp1/$blueSamp1} and {$depth2/$redSamp2/$greenSamp2/$blueSamp2} are consistent"
    ok_trace_msg "_AreGraylesConsistent_DXO (normalized): {$depth1/$red1/$green1/$blue1} and {$depth2/$red2/$green2/$blue2} are consistent"
    return  1
  }
  return  0
}
set IS_SAMPLE_ADJACENT_CALLBACK _AreGraySamplesConsistent_DXO


set EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK 0; # use generic proc
set EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK 0; # use generic proc


# optional helper callback to assist in testing
# takes 2 lists of WB-params; returns 1/0 (==/!=)
proc _AreWbParamsEqu_DXO {wbParams1 wbParams2}  {
  set tolerance 0.000001
  for { set i 0 }  { $i < [expr {([WBParam3IsUsed])? 3 : 2}] }  { incr i 1 }  {
    set absdiff [expr {abs( [lindex $wbParams1 $i] - [lindex $wbParams2 $i] )}]
    if { $absdiff >= $tolerance }  { return  0 }
  }
  return  1
}
set WBPARAMS_EQU_OPTIONAL_CALLBACK  _AreWbParamsEqu_DXO


proc SettingsFileName {pureName} {
  global RAW_EXTENSION
  return  "$pureName.$RAW_EXTENSION.dop"
}


proc FindSettingsFile {pureName rawDir {checkExist 1}} {
  global RAW_EXTENSION
  return  [FindFilePath $rawDir $pureName \
                        "$RAW_EXTENSION.dop" "Settings" \
                        $checkExist]
}


#~ proc SettingsFileNameToPurename {settingsName} {
  #~ global RAW_EXTENSION
  #~ set settingsName [string toupper $settingsName]
  #~ set fullExt [string toupper ".$RAW_EXTENSION.dop"]
  #~ set idx [string first $fullExt $settingsName]
  #~ #ok_trace_msg "'$settingsName' -> '$fullExt' at \[$idx\]"
  #~ if { $idx <= 0 }  {  return  "" }
  #~ return  [string range $settingsName 0 [expr $idx-1]]
#~ }


# Does no change - for DXO Optics
proc MassageColorParamsForConverter {wbParamsListVar} {
  #~ upvar $wbParamsListVar rgb
  #~ ParseWBParamsForConverter $rgb redSamp greenSamp blueSamp
  #~ set rgb [PackWBParamsForConverter $redSampM $greenSampM $blueSampM]
}
