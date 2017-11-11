# color_math.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]

set MAX_MULT 32766 ;  # maximum value of color multiplier
#set MAX_MULT 255 ;  # maximum value of color multiplier

set MAX_CURVE_XY 255 ;  # for 8bit curve - rightmost point of the curve

set MAX_PIXEL_REAIDNG 65535 ; # 16bit




# 'wbParamVal' is the value of color-parameter to check;
# 'wbParamIdx' is its index in (for example) {temperature,tint1,tint2(or -1)} list.
# Returns the new value of this color-parameter
proc AdjustColorParameterToConverterLimits {wbParamVal wbParamIdx depth} {
  # per-converter color-parameters' limits
  global WBPARAM1_MIN WBPARAM1_MAX WBPARAM2_MIN WBPARAM2_MAX
  global WBPARAM3_MIN WBPARAM3_MAX
  global WBPARAM_NAMES
  set loLimits [list $WBPARAM1_MIN $WBPARAM2_MIN $WBPARAM3_MIN]
  set hiLimits [list $WBPARAM1_MAX $WBPARAM2_MAX $WBPARAM3_MAX]
  set pName [lindex $WBPARAM_NAMES $wbParamIdx]
  set pMin [lindex $loLimits $wbParamIdx]
  set pMax [lindex $hiLimits $wbParamIdx]
  if { $wbParamVal < $pMin }  {
    ok_warn_msg "Extrapolation of $pName for depth=$depth will be truncated to lower converter-limit of $pMin"
    return  $pMin
  }
  if { $wbParamVal > $pMax }  {
    ok_warn_msg "Extrapolation of $pName for depth=$depth will be truncated to upper converter-limit of $pMax"
    return  $pMax
  }
  return  $wbParamVal
}



# Puts into multR/multG/multB normalized to MAX_MULT versions of mR1/mG1/mB1
proc NomalizeMultipliers {mR1 mG1 mB1  multR multG multB} {
  global MAX_MULT
  upvar $multR mR
  upvar $multG mG
  upvar $multB mB
  ok_trace_msg "NomalizeMultipliers($mR1 $mG1 $mB1)"
  if { $mR1 == 0.0 }  { set $mR1 0.0001 }
  if { $mG1 == 0.0 }  { set $mG1 0.0001 }
  if { $mB1 == 0.0 }  { set $mB1 0.0001 }
  set norm [expr min( [expr 1.0* $MAX_MULT/$mR1], [expr 1.0* $MAX_MULT/$mG1], [expr 1.0* $MAX_MULT/$mB1] )]
  set mR [expr round($mR1 * $norm)]
  set mG [expr round($mG1 * $norm)]
  set mB [expr round($mB1 * $norm)]
}


# Puts into multR/multG/multB color multipliers that convert greyR/greyG/greyB pixel into neutral
proc CalcNeutralizingMultipliers {greyR greyG greyB  multR multG multB} {
  global MAX_PIXEL_REAIDNG
  upvar $multR mR
  upvar $multG mG
  upvar $multB mB
  if { $greyR < 1.0 }  { set greyR 1.0 }
  if { $greyG < 1.0 }  { set greyG 1.0 }
  if { $greyB < 1.0 }  { set greyB 1.0 }
  #set maxV1 [expr {max($greyR, $greyG, $greyB)}]
  set maxV1 $MAX_PIXEL_REAIDNG
  set mR1 [expr 1.0 * $maxV1 / $greyR] ;  # not normalized, probably < 1
  set mG1 [expr 1.0 * $maxV1 / $greyG] ;  # not normalized, probably < 1
  set mB1 [expr 1.0 * $maxV1 / $greyB] ;  # not normalized, probably < 1
  NomalizeMultipliers $mR1 $mG1 $mB1  mR mG mB
}


#  Corrects multpliers obtained for Cloudy WB for use under Sunny light
proc CompensateMultipliersForCloudy {inR inG inB outR outG outB} {
  global MAX_MULT g_camPresets
  upvar $outR oR
  upvar $outG oG
  upvar $outB oB
  set sunnyR [lindex $g_camPresets(Sunny) 0]
  set sunnyG [lindex $g_camPresets(Sunny) 1]
  set sunnyB [lindex $g_camPresets(Sunny) 2]
  set cloudyR [lindex $g_camPresets(Cloudy) 0]
  set cloudyG [lindex $g_camPresets(Cloudy) 1]
  set cloudyB [lindex $g_camPresets(Cloudy) 2]
  set oR1 [expr round(1.0 * $inR * $sunnyR / $cloudyR)]
  set oG1 [expr round(1.0 * $inG * $sunnyG / $cloudyG)]
  set oB1 [expr round(1.0 * $inB * $sunnyB / $cloudyB)]
  NomalizeMultipliers $oR1 $oG1 $oB1  oR oG oB
}


# Puts into yR/yG/yB ordinates for X==MAX_CURVE_XY of linear color-curves
# that convert greyR/greyG/greyB pixel into neutral
proc TODO_CalcNeutralizingCurvePoints {greyR greyG greyB  xR yR  xG yG  xB yB} {
  global MAX_PIXEL_REAIDNG MAX_CURVE_XY
  upvar $yR yyR
  upvar $yG yyG
  upvar $yB yyB
  upvar $xR xxR
  upvar $xG xxG
  upvar $xB xxB
  if { $greyR < 1.0 }  { set greyR 1.0 }
  if { $greyG < 1.0 }  { set greyG 1.0 }
  if { $greyB < 1.0 }  { set greyB 1.0 }
  #set maxV1 [expr {max($greyR, $greyG, $greyB)}]
  set maxV1 $MAX_PIXEL_REAIDNG
  # ? yAverage = greyR*yR/MAX_CURVE_XY = greyG*yG/MAX_CURVE_XY = greyB*yB/MAX_CURVE_XY
  # ? --> y = yAverage * MAX_X / greyOld
  # (intention)       x1 = greyOld;  y1 = yAverage
  # (x-normalzation)  x = MAX_CURVE_XY;  y = y1 * MAX_CURVE_XY / x1
  # -->   x = MAX_CURVE_XY;  y = MAX_CURVE_XY * yAverage / greyOld
  # TODO:   avoid  y > MAX_CURVE_XY
  set yAverage [expr ($greyR + $greyG + $greyB) / 3.0];  # so far x==MAX_CURVE_XY
  set yR1 [expr 1.0 * $MAX_CURVE_XY* $yAverage / $greyR] ;  # not normalized, probably < 1
  set yG1 [expr 1.0 * $MAX_CURVE_XY* $yAverage / $greyG] ;  # not normalized, probably < 1
  set yB1 [expr 1.0 * $MAX_CURVE_XY* $yAverage / $greyB] ;  # not normalized, probably < 1
  # unlike the case with color multipliers, here we shouldn't normalize Y-s alone
  #TODO
  if { $yR1 <= $MAX_CURVE_XY }  {     set yyR $yR1;           set xxR $MAX_CURVE_XY
  } else                        {     set yyR $MAX_CURVE_XY;  set xxR $yR1  } #???
}

