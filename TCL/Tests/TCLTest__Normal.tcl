# TCLTest__Normal.tcl
# Invocation examples:
#  source c:/Oleg/Work/UW_Image_Depth/TCL/Tests/TCLTest__Normal.tcl;  TCLTest__Normal c:/tmp/UWIC c:/Oleg/Work/UW_Image_Depth/Test/Inputs/ 160914_Eilat_UW PHOTO-NINJA
#  set _SRCD D:/Work/UW_image_depth ; source [file join $_SRCD TCL Tests TCLTest__Normal.tcl];  set _WRD "d:/ANY/tmp/UWIC";  set _DVN "160914_Eilat_UW";  file delete -force [file join $_WRD $_DVN];  TCLTest__Normal $_WRD [file join $_SRCD Test Inputs] $_DVN PHOTO-NINJA
#  set _SRCD c:/Oleg/Work/UW_image_depth ; source [file join $_SRCD TCL Tests TCLTest__Normal.tcl];  set _WRD "c:/tmp/UWIC";  set _DVN "160914_Eilat_UW";  file delete -force [file join $_WRD $_DVN];  TCLTest__Normal $_WRD [file join $_SRCD Test Inputs] $_DVN PHOTO-NINJA

set TESTS_DIR [file dirname [info script]]
set TESTCODE_DIR [file join $TESTS_DIR "Code"]

set UWIC_DIR [file join $TESTS_DIR ".."]

source [file join $UWIC_DIR     "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$TESTCODE_DIR' ----"

##source [file join $UWIC_DIR     "gui.tcl"]
source [file join $TESTCODE_DIR "test_arrange.tcl"]
source [file join $TESTCODE_DIR "test_run.tcl"]
source [file join $TESTCODE_DIR "AssertExpr.tcl"]


proc TCLTest__Normal {workRoot storeRoot diveName rawConvName} {
  set inputSelectSpec ""
  if { 0 == [MakeWorkArea $workRoot $storeRoot $diveName $inputSelectSpec] } {
    return  0;  # error already printed
  }
  set workDir [file join $workRoot $diveName]
  ok_info_msg "Finished preparaion for TCLTest__Normal under '$workRoot'"
  if { 0 == [TestFullFlow $workDir $rawConvName] }  {
    ok_err_msg "Failed test TCLTest__Normal"
    return  0
  }
  ok_info_msg "Succeeded test TCLTest__Normal"
  return  1
}

