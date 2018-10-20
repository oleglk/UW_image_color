# setup_uw_image_depth.tcl



###############################################################################
# Do not change below this line
###############################################################################
set SCRIPT_DIR [file dirname [info script]]
set LOUD_MODE 1;  # safe here - read only once
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "Parse_CSV_65433-1.tcl"]
source [file join $SCRIPT_DIR   "topological_sort.tcl"]
source [file join $SCRIPT_DIR   "longest_path.tcl"]
source [file join $SCRIPT_DIR   "common_utils.tcl"]
source [file join $SCRIPT_DIR   "gray_sample_filter.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]
source [file join $SCRIPT_DIR   "dive_log.tcl"]
source [file join $SCRIPT_DIR   "grey_targets.tcl"]
source [file join $SCRIPT_DIR   "raw_manip.tcl"]
source [file join $SCRIPT_DIR   "read_img_metadata.tcl"]
source [file join $SCRIPT_DIR   "toplevel_utils.tcl"]
source [file join $SCRIPT_DIR   "search.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]
source [file join $SCRIPT_DIR   "color_math.tcl"]

source [file join $SCRIPT_DIR   "preferences_mgr.tcl"]
source [file join $SCRIPT_DIR   "raw_converters.tcl"]

source [file join $SCRIPT_DIR   "gui_preferences.tcl"]
source [file join $SCRIPT_DIR   "gui_depth_ovrd.tcl"]
source [file join $SCRIPT_DIR   "main.tcl"]

# load default settings if possible
if { 0 == [PreferencesReadAndApply oldValsDict] }  {
  if { $oldValsDict != 0 }  {
    ok_warn_msg "Default settings were not loaded; will restore hardcoded preferences"
    PreferencesRollback $oldValsDict
  } else {
    ok_info_msg "Preferences were not modified - hardcoded settings preserved"
  }
} else {
  # perform initializations dependent on the saved preferences
  cdToWorkdirOrComplain 0;   # inits diagnostics log too
  ok_info_msg "Default settings were loaded" ;    # into the correct log
}
SetRAWConverter $INITIAL_CONVERTER_NAME
