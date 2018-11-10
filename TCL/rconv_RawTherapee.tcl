# rconv_RawTherapee.tcl

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
source [file join $SCRIPT_DIR   "color_math.tcl"]

set SETTINGS_DIR    ""  ; # settings files stored together with RAWs

set WBPARAM_NAMES {"color-temperature" "color-tint" "red-blue-ratio"}

set WBPARAM123_PATTERN  "" ;  # indicate it's unused
set WBPARAM1_PATTERN   {\nTemperature=([0-9]+)\n}
set WBPARAM1_SUBMATCH_INDEX 1
set WBPARAM2_PATTERN   {\nGreen=([.0-9]+)\n}
set WBPARAM2_SUBMATCH_INDEX 1
set WBPARAM3_PATTERN  {\nEqual=([.0-9]+)\n}
set WBPARAM3_SUBMATCH_INDEX 1

set WBPARAM123_FORMAT  "" ; # indicate it's unused
set WBPARAM1_FORMAT  "\nTemperature=%d\n"
set WBPARAM2_FORMAT  "\nGreen=%1.4f\n"
set WBPARAM3_FORMAT "\nEqual=%1.3f\n"

# TODO: MAKE IT PER-FILTER ARRAY
set WBPARAM1_SURFACE   4370
set WBPARAM2_SURFACE   1.155
set WBPARAM3_SURFACE  1.000

## per-converter color-parameters' limits
set WBPARAM1_MIN       1500
set WBPARAM1_MAX       60000
set WBPARAM2_MIN       0.020
set WBPARAM2_MAX       5.000
set WBPARAM3_MIN      0.800
set WBPARAM3_MAX      1.500


set GREY_TARGET_DATA_HEADER_RCONV [list "global-time" "depth" "color-temp" "color-tint" "red-blue"] ;  # color temperature, main tint, red-blue ratio

set IMAGE_DATA_HEADER_RCONV [list "global-time" "depth" "color-temp" "color-tint" "red-blue"] ;  # color temperature, main tint, red-blue ratio

# optional helper callback to assist in testing
# takes 2 lists of WB-params; returns 1/0 (==/!=)
set WBPARAMS_EQU_OPTIONAL_CALLBACK 0
################################################################################


# Returns 1 if the two samples could be used together
proc _AreGraySamplesConsistent_RawTherapee {dataList1 dataList2}  {
  # 'dataList1'/'dataList2': {pure-name depth time colorTemp colorTint1 colorTint2}
  ParseDepthColorRecord $dataList1 n1 time1 depth1 colorTemp1 colorTint11 colorTint12
  ParseDepthColorRecord $dataList2 n2 time2 depth2 colorTemp2 colorTint21 colorTint22
  # color-temp and main-tint are comparable only if additional tint is equal
  #TODO: protect from equal colors at different depths
  set absDiffColorTint2 [expr abs($colorTint22 - $colorTint12)]
  if { ($depth2 > [expr $depth1 + [GetDepthResolution]]) && \
        ( (($absDiffColorTint2 <= 0.02) &&
            ($colorTemp2 >= $colorTemp1) && ($colorTint21 <= $colorTint11)) ||
          ($colorTint22 > ($colorTint12 + 0.0)) ) } {
    ok_trace_msg "_AreGraySamplesConsistent_RawTherapee: {$depth1/$colorTemp1/$colorTint11/$colorTint12} and {$depth2/$colorTemp2/$colorTint21/$colorTint22} are consistent"
    return  1
  }
  return  0
}
set IS_SAMPLE_ADJACENT_CALLBACK _AreGraySamplesConsistent_RawTherapee


set EXTRAPOLATE_COLORS_ABOVE_DEPTH_RANGE_OPTIONAL_CALLBACK 0; # use generic proc


proc SettingsFileName {pureName} {
  global RAW_EXTENSION
  return  "$pureName.$RAW_EXTENSION.pp3"
}


proc FindSettingsFile {pureName rawDir {checkExist 1}} {
  global RAW_EXTENSION
  return  [FindFilePath $rawDir $pureName \
                        "$RAW_EXTENSION.pp3" "Settings" \
                        $checkExist]
}


#~ proc SettingsFileNameToPurename {settingsName} {
  #~ global RAW_EXTENSION
  #~ set settingsName [string toupper $settingsName]
  #~ set fullExt [string toupper ".$RAW_EXTENSION.pp3"]
  #~ set idx [string first $fullExt $settingsName]
  #~ #ok_trace_msg "'$settingsName' -> '$fullExt' at \[$idx\]"
  #~ if { $idx <= 0 }  {  return  "" }
  #~ return  [string range $settingsName 0 [expr $idx-1]]
#~ }


# Converts temperature value in 'wbParamsListVar' {temp, tint} into integer
proc MassageColorParamsForConverter {wbParamsListVar} {
  upvar $wbParamsListVar colorTempTint
  ParseWBParamsForConverter $colorTempTint colorTemp colorTint1 colorTint2
  # the results should be consistent with the format spec
  set colorTempM [expr round($colorTemp)]
  set colorTint1M [string trim [format "%8.4f" $colorTint1]]
  set colorTint2M [string trim [format "%8.3f" $colorTint2]]
  set colorTempTint [PackWBParamsForConverter $colorTempM $colorTint1M \
                                                                $colorTint2M]
}




# Computes and returns color-parameters with a forged right boundary.
# Color-parameters represented as a 2-3 element list
proc _ExtrapolateColorsBelowDepthRange_RawTherapee {depth depthList \
                                                    colorParamList}  {
  # per-converter color-parameters' limits
  global WBPARAM1_MIN WBPARAM1_MAX WBPARAM2_MIN WBPARAM2_MAX
  global WBPARAM3_MIN WBPARAM3_MAX
  set loLimits [list $WBPARAM1_MIN $WBPARAM2_MIN $WBPARAM3_MIN]
  set hiLimits [list $WBPARAM1_MAX $WBPARAM2_MAX $WBPARAM3_MAX]
  set colorParams [list ] ;  # will hold the resulting multipliers or temp/tint
  set colorParamIdxList [list 0 1]; # temperature,tint1; don't compute tint2
  # forge a right boundary:
  # tint2==const, temperature should GROW, tint1 should REDUCE
  # keep tint2 constant; half slope of the last range for temperature and tint1
  set depthPrev [lindex $depthList [expr [llength $depthList] -2]]; # shallower
  set depth1 [lindex $depthList [expr [llength $depthList] -1]];    # deeper
  set colorParamsPrev [lindex $colorParamList [expr [llength $depthList] -2]]
  set colorParams1 [lindex $colorParamList [expr [llength $depthList] -1]]
  ok_trace_msg "Extrapolating below depth range (deeper): $depthPrev\(m\)/{$colorParamsPrev} ... $depth1\(m\)/{$colorParams1}"
  # interpolate temperature
  set tm1 [lindex $colorParams1    0];  # color-temperature is at index 0
  set tmP [lindex $colorParamsPrev 0];  # color-temperature is at index 0
  set slope [expr 0.5* abs($tm1-$tmP) / ($depth1 - $depthPrev)] ;  # slope > 0
  set tm [expr 1.0* $tm1 + $slope*($depth - $depth1)];  # could be out of limits
  set tm [AdjustColorParameterToConverterLimits $tm 0 $depth]; #color-temp at #0
  lappend colorParams $tm
  # interpolate temperature and tint1

  set tn11 [lindex $colorParams1    1];  # color-tint1 is at index 1
  set tn1P [lindex $colorParamsPrev 1];  # color-tint1 is at index 1
  set slope [expr 0.5* abs($tn11-$tn1P) / ($depth1 - $depthPrev)];  # slope > 0
  set tn1 [expr 1.0* $tn11 - $slope*($depth - $depth1)];  # could be out of limits
  set tn1 [AdjustColorParameterToConverterLimits $tn1 1 $depth]; #color-tint1 at #1
  lappend colorParams $tn1

  set tn2 [lindex $colorParams1 2];   lappend colorParams $tn2
  return  $colorParams
}
set EXTRAPOLATE_COLORS_BELOW_DEPTH_RANGE_OPTIONAL_CALLBACK \
                                  _ExtrapolateColorsBelowDepthRange_RawTherapee
