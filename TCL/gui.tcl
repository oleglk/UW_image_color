# gui.tcl - UWID gui

package require Tk

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "setup_uw_image_depth.tcl"]

### Sketch of the GUI #####
# |                 |                |                    |                    | |
# +----------------------------------------------------------------------------+-+
# |Raw Converter:   |CBX rawConv     |BTN settings        |BTN help            | |
# +----------------------------------------------------------------------------+-+
# |BTN chooseDir    |                 ENT workDir                              | |
# +----------------------------------------------------------------------------+-+
# |BTN extractThumbs|BTN sortByThumbs|BTN mapDepthColor   |BTN procAllRAWs     | |
# +----------------------------------------------------------------------------+-+
# |BTN quit         |PGB progressBar |BTN showDepthOvrd   |BTN procChangedRAWs | |
# +----------------------------------------------------------------------------+-+
# |               TXT logBox                                                   |^|
# |                                                                            |v|
# +----------------------------------------------------------------------------+-+

set APP_TITLE "Underwater Image Color"


################################################################################
proc _CleanLogText {}  {
  set tclResult [catch {
    .top.logBox configure -state normal
    .top.logBox  delete 0.0 end
  } execResult]
  if { $tclResult != 0 } {
    set msg "Failed changing log text: $execResult!"
    puts $msg;  tk_messageBox -message "-E- $msg" -title $APP_TITLE
  }
  .top.logBox configure -state disabled
}

proc _AppendLogText {str {tags ""}}  {
  global APP_TITLE
  set tclResult [catch {
    .top.logBox configure -state normal
    if { [.top.logBox index "end-1c"] != "1.0" }  {.top.logBox insert end "\n"}
    set res [.top.logBox  insert end "$str" "$tags"]
    .top.logBox see end
  } execResult]
  if { $tclResult != 0 } {
    set msg "Failed changing log text: $execResult!"
    puts $msg;  tk_messageBox -message "-E- $msg" -title $APP_TITLE
  }
  .top.logBox configure -state disabled
}


proc _ReplaceLogText {str}  {
  _CleanLogText;  _AppendLogText $str
}
################################################################################


################################################################################
proc _InitValuesForGUI {}  {
  global PROGRESS WORK_DIR INITIAL_WORK_DIR
  global INITIAL_CONVERTER_NAME CONVERTER_NAME
  ok_trace_msg "Setting hardcoded GUI preferences"
  set PROGRESS "...Idle..."
  set CONVERTER_NAME $INITIAL_CONVERTER_NAME
  set WORK_DIR $INITIAL_WORK_DIR
  set msg [cdToWorkdirOrComplain 0]
  if { $msg != "" }  {
    ok_warn_msg "$msg";   # initial work-dir not required to be valid
    return  0
  }
}
################################################################################
_InitValuesForGUI
################################################################################


wm title . $APP_TITLE

grid [ttk::frame .top -padding "3 3 12 12"] -column 0 -row 0 -sticky nwes
grid columnconfigure . 0 -weight 1;     grid columnconfigure .top 0 -weight 0
grid columnconfigure .top 1 -weight 1;  grid columnconfigure .top 2 -weight 1
grid columnconfigure .top 3 -weight 1;  grid columnconfigure .top 4 -weight 1
grid columnconfigure .top 6 -weight 0
grid rowconfigure . 0 -weight 1;      grid rowconfigure .top 0 -weight 0
grid rowconfigure .top 1 -weight 0;   grid rowconfigure .top 2 -weight 0
grid rowconfigure .top 3 -weight 0;   grid rowconfigure .top 4 -weight 0
grid rowconfigure .top 5 -weight 1

grid [ttk::label .top.rawConvLbl -text "Raw Converter:"] -column 1 -row 1 -sticky w
#grid [ttk::entry .top.rawConv -width 29 -textvariable CONVERTER_NAME] -column 2 -row 1 -sticky we
grid [ttk::combobox .top.rawConv -textvariable CONVERTER_NAME] -column 2 -row 1 -sticky we
bind .top.rawConv <<ComboboxSelected>> GUI_SetRAWConverter
.top.rawConv configure -values $CONVERTER_NAME_LIST
.top.rawConv state readonly

grid [ttk::button .top.settings -text "Preferences..." -command GUI_ChangeSettings] -column 3 -row 1 -sticky we

grid [ttk::button .top.help -text "Help" -command GUI_ShowHelp] -column 4 -row 1 -sticky we

grid [ttk::button .top.chooseDir -text "Folder..." -command GUI_ChooseDir] -column 1 -row 2 -sticky we
#TODO: how-to:  bind .top <KeyPress-f> ".top.chooseDir invoke"

grid [ttk::entry .top.workDir -width 29 -textvariable WORK_DIR -state disabled] -column 2 -row 2 -columnspan 3 -sticky we

grid [ttk::button .top.extractThumbs -text "Extract\nThumbnails" -command GUI_ExtractThumbnails] -column 1 -row 3 -sticky we

grid [ttk::button .top.sortThumbs -text "Sort RAWs\nby Thumbnails" -command GUI_SortRAWsByThumbnails] -column 2 -row 3 -sticky we

grid [ttk::button .top.mapDepthColor -text "Map Depth\nto Color" -command GUI_MapDepthToColor] -column 3 -row 3 -sticky we

grid [ttk::button .top.procAllRAWs -text "Process\nAll Photos" -command GUI_ProcAllRAWs] -column 4 -row 3 -sticky we


grid [ttk::button .top.quit -text "Quit" -command GUI_Quit] -column 1 -row 4 -sticky we

grid [ttk::label .top.progressLbl -textvariable PROGRESS] -column 2 -row 4 -sticky we

grid [ttk::button .top.showDepthOvrd -text "Override\nDepth..." -command GUI_ProcShowDepthOvrd] -column 3 -row 4 -sticky we

grid [ttk::button .top.procChangedRAWs -text "Process\nChanged Photos" -command GUI_ProcChangedRAWs] -column 4 -row 4 -sticky we





grid [tk::text .top.logBox -width 60 -height 6 -wrap word -state disabled] -column 1 -row 5 -columnspan 4 -sticky wens
grid [ttk::scrollbar .top.logBoxScroll -orient vertical -command ".top.logBox yview"] -column 5 -row 5 -columnspan 1 -sticky wns
.top.logBox configure -yscrollcommand ".top.logBoxScroll set"

#.top.logBox tag configure boldline   -font {bold}  ; # TODO: find how to specify bold
#.top.logBox tag configure italicline -font {italic}; # TODO: find how to specify italic
.top.logBox tag configure underline   -underline on




foreach w [winfo children .top] {grid configure $w -padx 5 -pady 5}

focus .top.rawConv


ok_msg_set_callback "_AppendLogText" ;            # only after the GUI is built
_AppendLogText "Log messages will appear here" ;  # only after the GUI is built


# Handle the "non-standard window termination" by
# invoking the Cancel button when we receives a
# WM_DELETE_WINDOW message from the window manager.
wm protocol . WM_DELETE_WINDOW {
    .top.quit invoke
}
################################################################################


proc GUI_SetRAWConverter {}  {
  _UpdateGuiStartAction
  SetRAWConverter
  _UpdateGuiEndAction
}


proc GUI_ChangeSettings {}  {
  global APP_TITLE
  set res [GUI_PreferencesShow]
  if { $res != 0 }  {
    set savedOK [PreferencesCollectAndWrite]
  }
}


proc GUI_ShowHelp {}  {
  global APP_TITLE SCRIPT_DIR
  tk_messageBox -message "Please read [file join $SCRIPT_DIR {..} {Doc} {UG__UW_image_depth.txt}]" -title $APP_TITLE
}


proc GUI_ChooseDir {}  {
  global APP_TITLE SCRIPT_DIR WORK_DIR
  set ret [tk_chooseDirectory]
  if { $ret != "" }  {
    set msg [_GUI_SetDir $ret]
    #tk_messageBox -message "After cd to work-dir '$WORK_DIR'" -title $APP_TITLE
    if { $msg != "" }  {
      tk_messageBox -message "-E- $msg" -title $APP_TITLE
      return  0
    }
  }
  return  1
}


proc _GUI_SetDir {newWorkDir}  {
  global APP_TITLE SCRIPT_DIR WORK_DIR
  .top.workDir configure -state normal
  set WORK_DIR $newWorkDir
  .top.workDir configure -state disabled
  set msg [cdToWorkdirOrComplain 1]
  #tk_messageBox -message "After cd to work-dir '$WORK_DIR'" -title $APP_TITLE
  return  $msg
}


proc GUI_ExtractThumbnails {}  {
  global APP_TITLE WORK_DIR THUMB_DIR
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set msg [ExtractThumbsFromAllRaws]
  _UpdateGuiEndAction
  if { "" != $msg }  {
    #tk_messageBox -message "-E- Failed to extract thumbnails in '$WORK_DIR':  $msg" -title $APP_TITLE
    return  0
  }
  set msg "Thumbnails extracted into directory <[file join $WORK_DIR $THUMB_DIR]>"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
  return  1
}


proc GUI_SortRAWsByThumbnails {}  {
  global APP_TITLE WORK_DIR RAW_COLOR_TARGET_DIR
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set msg [SortAllRawsByThumbnails]
  _UpdateGuiEndAction
  if { "" != $msg }  {
    #tk_messageBox -message "-E- Failed to sort RAWs by thumbnails in '$WORK_DIR':  $msg" -title $APP_TITLE
    return  0
  }
  set msg "RAW files of WB targets moved into directory <[file join $WORK_DIR $RAW_COLOR_TARGET_DIR]>"
  #tk_messageBox -message $msg -title $APP_TITLE
  # success msg printed by SortAllRawsByThumbnails
  return  1
}


# Builds depth-to-color mapping. Returns 1 on success, 0 on error.
proc GUI_MapDepthToColor {}  {
  global APP_TITLE WORK_DIR DATA_DIR
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set oldFocus [focus];   # Save old keyboard focus - maybe need to to restore
  if { 1 == [GUI_DepthOvrdIsOpen] }  {
    set msg "Depth-override window needs to be closed before processing depth data"
    ok_err_msg $msg
    tk_messageBox -message $msg -title $APP_TITLE -icon error
    focus $oldFocus;  # return the focus back to pre-dialog state
    _UpdateGuiEndAction;  return  0
  }
  if { 1 == [DepthColorDataFilesExist] }  {
    set msg1 "Color and depth data files already exist in data directory '[GetDataDirFullPath]'"
    ##error $msg1;  # OK_TMP
    set answer [tk_messageBox -type "yesno" -default "yes" \
      -message "$msg1; continue and override?" -icon question -title $APP_TITLE]
    if { $answer == "no" }  {
      ok_warn_msg "$msg1; the user decided to abort"
      focus $oldFocus;  # return the focus back to pre-dialog state
      _UpdateGuiEndAction;  return  0
    }
    ok_info_msg "$msg1; the user decided to continue and override"
  }
  set msg [ProcessDepthData 1] ;  # ignoreGrayTargetsFile=1 - confirmed by user
  _UpdateGuiEndAction
  if { "" != $msg }  {
    #tk_messageBox -message "-E- Failed to map depth to WB in '$WORK_DIR':  $msg" -title $APP_TITLE
    return  0
  }
  set msg "Depth-to-color mapping data created in directory <[file join $WORK_DIR $DATA_DIR]>"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
  return  1
}


proc GUI_ProcAllRAWs {}       {  return  [_GUI_ProcRAWs 0] }
proc GUI_ProcChangedRAWs {}   {  return  [_GUI_ProcRAWs 1] }

# Chooses depths for all RAWs, computes their color parameters.
# Overrides the color parameters in the settings files/
# Returns 1 on success, 0 on error.
proc _GUI_ProcRAWs {onlyChanged}  {
  global APP_TITLE WORK_DIR DATA_DIR
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set msg "" ;  # as if evething is OK
  if { 1 == [GUI_DepthOvrdIsOpen] }  {
    ok_trace_msg "Depth-override window was open when RAW processing request obtained"
    if { 0 == [UpdateAndFlushDepthOvrdCSV] }  {
      set msg "Failed to read depth-override data from the input form"
    }
  } else {
    ok_trace_msg "Depth-override window was closed when RAW processing request obtained"
  }
  if { "" == $msg }  {;  # OK so far
    set cnt [ProcessUltimateRAWs $onlyChanged]
  }
  _UpdateGuiEndAction
  if { $cnt <= 0 }  {
    #tk_messageBox -message "-E- Failed to process settings for all RAWs in '$WORK_DIR':  $msg" -title $APP_TITLE
    return  0
  }
  set msg "WB settings for all RAWs overriden in directory <[file join $WORK_DIR $DATA_DIR]>"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
  return  1
}


proc GUI_Quit {}  {
  global APP_TITLE SCRIPT_DIR
  set answer [tk_messageBox -type "yesno" -default "no" \
    -message "Are you sure you want to quit?" -icon question -title $APP_TITLE]
  if { $answer == "no" }  {
    return
  }
  if { 1 == [GUI_DepthOvrdIsOpen] }  {
    set oldFocus [focus];   # Save old keyboard focus
    if { 0 == [GUI_SaveDepthWndDataIfRequested] } {
      focus $oldFocus;  # return the focus back to pre-dialog state
      return
    }
  }
  ok_finalize_diagnostics
  exit  0
}


proc GUI_ProcShowDepthOvrd {}  {
  global APP_TITLE
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  # No problem of reopen while already shown - we anyway perform "deiconify"
  set res [GUI_DepthOvrdShow]
  _UpdateGuiEndAction
  # ?TODO?
}


########## Utilities #######

proc _UpdateGuiStartAction {}   {
  global CNT_PROBLEMS_BEFORE PROGRESS
  _CleanLogText
  set PROGRESS "...Working..."
  update idletasks
  set CNT_PROBLEMS_BEFORE [ok_msg_get_errwarn_cnt]
}

proc _UpdateGuiEndAction {}   {
  global CNT_PROBLEMS_BEFORE PROGRESS
  set cnt [expr [ok_msg_get_errwarn_cnt] - $CNT_PROBLEMS_BEFORE]
  set msg "The last action encountered $cnt problem(s)"
  if { $cnt > 0 }  { ok_warn_msg $msg } else { ok_info_msg $msg }
  set PROGRESS "...Idle..."
  update idletasks
}


proc _GUI_TryStartAction {}  {
  global APP_TITLE WORK_DIR
  _UpdateGuiStartAction
  if { 0 == [CheckWorkArea] }  {
    #tk_messageBox -message "-E- '$WORK_DIR' lacks essential input files" -title $APP_TITLE
    ok_err_msg "'$WORK_DIR' lacks essential input files"
    _UpdateGuiEndAction;  return  0
  }
  return  1
}
