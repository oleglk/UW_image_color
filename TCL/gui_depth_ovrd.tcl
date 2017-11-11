# gui_depth_ovrd.tcl - a non-modal top-level window for depth-override correction

package require Tk

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "dive_log.tcl"]
source [file join $SCRIPT_DIR   "toplevel_utils.tcl"]

### Sketch of the GUI #####
# |                                                                          | |
# +--------------------------------------------------------------------------+-+
# |                        TXT fullHeader                                    | |
# +--------------------------------------------------------------------------+-+
# |                        TXT depthTable                                    |^|
# |                                                                          |^|
# |                                                                          |^|
# |                                                                          |||
# |                                                                          |V|
# |                                                                          |V|
# |                                                                          |V|
# +--------------------------------------------------------------------------+-+
# |BTN reload          |BTN  save                |BTN close                  | |
# +--------------------------------------------------------------------------+-+
set WND_TITLE "Underwater Image Color - Depth Override"

array unset PURENAME_TO_DEPTH ;  # will hold the depth-override for ALL images

################################################################################
### Here (on top-level) the preferences-GUI is created but not yet shown.
### The code originated from: http://www.tek-tips.com/viewthread.cfm?qid=112205
################################################################################

toplevel .depthWnd


grid [ttk::frame .depthWnd.f -padding "3 3 12 12"] -column 0 -row 0 -sticky nwes
grid columnconfigure .depthWnd 0 -weight 1
grid columnconfigure .depthWnd.f 0 -weight 0
grid columnconfigure .depthWnd.f 1 -weight 1
grid columnconfigure .depthWnd.f 2 -weight 1
grid columnconfigure .depthWnd.f 3 -weight 1
grid columnconfigure .depthWnd.f 4 -weight 0
grid rowconfigure .depthWnd 0 -weight 1
grid rowconfigure .depthWnd.f 0 -weight 0
grid rowconfigure .depthWnd.f 1 -weight 0
grid rowconfigure .depthWnd.f 2 -weight 1
grid rowconfigure .depthWnd.f 3 -weight 0

# header-keywords should be no smaller than corresponding cell data fields
set NAME_HDR "Image-Name"
set ESTIMDEPTH_HDR "Estimated-Depth"
set CHOSENDEPTH_HDR "Chosen-Depth"
grid [tk::text .depthWnd.f.fullHeader -width 60 -height 1 -wrap none -state normal] -column 1 -row 1 -columnspan 3 -sticky we
.depthWnd.f.fullHeader insert end "$NAME_HDR\t$ESTIMDEPTH_HDR\t$CHOSENDEPTH_HDR"
.depthWnd.f.fullHeader configure -state disabled

grid [tk::text .depthWnd.f.depthTable -width 71 -height 12 -wrap none -state disabled] -column 1 -row 2 -columnspan 3 -sticky wens
grid [ttk::scrollbar .depthWnd.f.depthTableScroll -orient vertical -command ".depthWnd.f.depthTable yview"] -column 4 -row 2 -columnspan 1 -sticky wns
.depthWnd.f.depthTable configure -yscrollcommand ".depthWnd.f.depthTableScroll set"


foreach w [winfo children .depthWnd.f] {grid configure $w -padx 5 -pady 5}

# Set the window title, then withdraw the window from the screen (hide it)
wm title .depthWnd $WND_TITLE
wm withdraw .depthWnd
# 
wm protocol .depthWnd WM_DELETE_WINDOW "GUI_CloseWin_DepthWnd"


################################################################################

# Merges depth-override data from 'PURENAME_TO_DEPTH' into predefined CSV file
# Returns 1 on success, -1 on file-save error; 0 on data error
proc UpdateAndFlushDepthOvrdCSV {}  {
  global PURENAME_TO_DEPTH
  array unset depthOvrdArr;  # essential init-s
  set ovrdReadRes [TopUtils_ReadIntoArrayDepthOverrideCSV depthOvrdArr 1]
  if { $ovrdReadRes == 0 } {
    set msg "Depth-override data disappeared after being used once"
    ok_err_msg $msg;      return  0
  } elseif { $ovrdReadRes < 0 } {
    set msg "Corrupted depth-override data file"
    ok_err_msg $msg;      return  0
  }
  if { 0 == [set updateOK \
        [TopUtils_UpdateDepthOverrideArray depthOvrdArr PURENAME_TO_DEPTH]] } {
    set msg "Error occured while updating depth-override data"
    ok_err_msg $msg
    #DO NOT return; let it save the correct overrides; invalid entries rejected
  }
  # save the new version of depth-override data; don't touch the "previous"
  if { 0 == [ok_write_array_of_lists_into_csv_file depthOvrdArr \
                                     [FindDepthOvrdData] "pure-name" " "] }  {
    ok_err_msg "Failed to save new depth-override data in '[FindDepthOvrdData]'"
    return  -1
  }
  ok_info_msg "Updated depth-override data printed into '[FindDepthOvrdData]'"
  return  $updateOK
}


################################################################################
proc GUI_DepthOvrdIsOpen {}  {
  set tclResult [catch { set state [wm state .depthWnd] } execResult]
  if { $tclResult != 0 } { set state "withdrawn" }
  return  [expr {$state != "withdrawn"}]
}

proc GUI_DepthOvrdShow {}  {
  global GEOM_DEPTHWND
  # display the window; if reopening, restore old position
  if { [info exists GEOM_DEPTHWND] } {
    wm geometry .depthWnd $GEOM_DEPTHWND
  }
  wm deiconify .depthWnd

  # Wait for the window to be displayed before continuing
  catch {tkwait visibility .depthWnd}
  GUI_FillDepthTable
  return
}


proc GUI_CloseWin_DepthWnd {}  {
  global APP_TITLE GEOM_DEPTHWND
  if { [catch { winfo geom .depthWnd } g] } {
    return
  }
  ###set oldFocus [focus];   # Save old keyboard focus
  set GEOM_DEPTHWND $g
  # TODO: when only depth-override window is closed, either always save/apply or be able to reset
  if { 1 != [UpdateAndFlushDepthOvrdCSV] } {
    tk_messageBox -message "-E- There are errors in depth-override; invalid input is rejected; please see the log" -title $APP_TITLE
    ###focus $oldFocus;  # raise the depth-override window back on top
    #DO NOT return - let the window close
  }
  wm withdraw .depthWnd
  return
}


proc GUI_SaveDepthWndDataIfRequested {}  {
  if { "yes" == [tk_messageBox -type "yesno" -icon question \
      -title "Save depth-override data?" \
      -message "Do you want to save depth-override data?"] } {
    if { -1 == [UpdateAndFlushDepthOvrdCSV] }  {
      if { "no" == [tk_messageBox -type "yesno" -icon question \
          -title "Failed saving depth-override" \
          -message "Failed to save depth-override data; close anyway?"] } {
        return  0;  # ask to save but failed
      }
    }
  }
  return  1;  # either saved or not asked to
}


proc GUI_FillDepthTable {}  {
  global APP_TITLE
  global PURENAME_TO_DEPTH
  set trashDirPath "" ;   # the 1st proc involving it will choose the path
  CleanDepthOverrideFiles "Override-Depth" trashDirPath
  array unset depthOvrdArr;  array unset PURENAME_TO_DEPTH; # essential init-s
  if { 0 >= [TopUtils_ReadIntoArrayDepthOverrideCSV depthOvrdArr 1] } {
    GUI_CloseWin_DepthWnd
    set msg "No depth-override data available"
    ok_err_msg $msg
    tk_messageBox -message "-E- $msg" -title $APP_TITLE
    return
  }
  TopUtils_RemoveHeaderFromDepthOverrideArray depthOvrdArr
  set tBx .depthWnd.f.depthTable
  $tBx configure -state normal
  $tBx delete 1.0 end;   # clean all
  # depth-override arrays:
  #   pure-name::{global-time,min-depth,max-depth,estimated-depth,depth}
  set allPureNames  [lsort [array names depthOvrdArr]];  # TODO: better sort
  set cnt 0
  foreach pureName $allPureNames {
    incr cnt [_GUI_AppendOneDepthOvrdRecord $pureName depthOvrdArr];# +1 on success
  }
  $tBx configure -state disabled
  ok_info_msg "Prepared $cnt depth-override record(s)"
}


# Inserts depth entry or error message at the end of the textbox.
# Returns 1 on success, 0 on error
proc _GUI_AppendOneDepthOvrdRecord {pureName depthOvrdArrVar} {
  global NAME_HDR ESTIMDEPTH_HDR CHOSENDEPTH_HDR
  global PURENAME_TO_DEPTH
  upvar $depthOvrdArrVar depthOvrdArr
  set retVal 1
  if { 0 == [info exists depthOvrdArr($pureName)] }  {
    set str "Image '$pureName' inexistent in depth-override data"
    ok_err_msg $str;  set retVal 0
  } else {
    ok_trace_msg "Processing depth-ovrd record for '$pureName': {$depthOvrdArr($pureName)}"
    # build and insert into textbox either depth-ovrd record, or error-message 
    if { 0 == [TopUtils_ParseDepthOverrideRecord depthOvrdArr $pureName \
                      globalTime minDepth maxDepth estimatedDepth depth] }  {
      set str "Invalid depth-override record for '$pureName': '$depthOvrdArr($pureName)'"
      ok_err_msg $str;  set retVal 0
    } else {
####  set str "[_FormatCellToHeader $pureName $NAME_HDR]\t[_FormatCellToHeader $estimatedDepth $ESTIMDEPTH_HDR]\t[_FormatCellToHeader $depth $CHOSENDEPTH_HDR]"
      set str "[_FormatCellToHeader $pureName $NAME_HDR]\t[_FormatCellToHeader $estimatedDepth $ESTIMDEPTH_HDR]"
    }
    set tBx .depthWnd.f.depthTable
    set PURENAME_TO_DEPTH($pureName) [_FormatCellToHeader $depth $CHOSENDEPTH_HDR]
    set entryPath ".depthWnd.f.depthTable.depth_$pureName"
    set tclResult [catch {
      set res [$tBx  insert end "$str\t"];  # insert text-only line prefix
      set depthEntry [ttk::entry $entryPath \
                      -width [string length $CHOSENDEPTH_HDR] \
                      -textvariable PURENAME_TO_DEPTH($pureName) \
                      -validate key -validatecommand {ValidateDepthString %P}]
      set res [$tBx  window create end -window $depthEntry]
      set retVal [_GUI_AppendOneEntryPlusMinusResetButtons $pureName $estimatedDepth]
      if { $retVal == 1 }  { incr cnt 1 }
      set res [$tBx  insert end "\n"]
      $tBx see end
    } execResult]
  }
  if { $tclResult != 0 } {
    set msg "Failed appending depth-override record: $execResult!"
    ok_err_msg $msg;  set retVal 0
  }
  return  $retVal
}


# Inserts plus/minus/reset buttons for the last depth entry at the end of the textbox.
# Returns 1 on success, 0 on error
proc _GUI_AppendOneEntryPlusMinusResetButtons {pureName estimatedDepth} {
  set retVal 1
  set tBx .depthWnd.f.depthTable
  set btnPaths [list  ".depthWnd.f.depthTable.minus_$pureName"  \
                      ".depthWnd.f.depthTable.plus_$pureName" \
                      ".depthWnd.f.depthTable.reset_$pureName" ]
  set btnLabels [list "-0.5" "+0.5" "-0-"]
  ####set btnCursors [list based_arrow_down based_arrow_up target]
  set btnCursors [list sb_up_arrow sb_down_arrow cross]
##  set btnCmds [list "_GUI_CmdPlus" "_GUI_CmdMinus" "_GUI_CmdReset"]
  set btnCmds [list "_GUI_CmdModifyDepth" "_GUI_CmdModifyDepth" \
                    "_GUI_CmdModifyDepth"]
  for {set i 0}  {$i < 3}  {incr i}   {
    set bPath [lindex $btnPaths $i];    set bLbl  [lindex $btnLabels $i]
    set bCmd  [lindex $btnCmds $i];     set bCsr  [lindex $btnCursors $i]
    set tclResult [catch {
      set res [$tBx  insert end " "];  # ? separate buttons ?
      set btn [ttk::button $bPath -text $bLbl -cursor $bCsr -style Toolbutton \
                                  -command [list $bCmd $bPath $estimatedDepth]]
      ##$btn configure -padx 0
      set res [$tBx  window create end -window $btn]
      incr cnt 1
    } execResult]
    if { $tclResult != 0 } {
      set msg "Failed appending depth-modification buttons for '$pureName': $execResult!"
      ok_err_msg $msg;  set retVal 0
    }
  }
  return  $retVal
}


proc _FormatCellToHeader {cellVal hdrVal}  {
  if { 1 == [string is double $cellVal] }  {
    return  [format "%[string length $hdrVal].2f" $cellVal]
  } else {
    return  [format "%[string length $hdrVal]s" $cellVal]
  }
}


#~ proc _GUI_CmdPlus {}   {}
#~ proc _GUI_CmdMinus {}  {}
#~ proc _GUI_CmdReset {}  {}

# Bind with: -command [list _GUI_CmdModifyDepth 'path' 'estimatedDepth']
proc _GUI_CmdModifyDepth {btnPath estimatedDepth}   {
  global PURENAME_TO_DEPTH CHOSENDEPTH_HDR
  if { 0 == [_ParsePlusMinusResetButtonPath $btnPath pureName cmd] }  {
    return  0;  # error already printed
  }
  if { 0 == [info exists PURENAME_TO_DEPTH($pureName)] }  {
    ok_err_msg "Requested depth modification for inexistent image '$pureName'"
    return  0
  }
  set oldVal $PURENAME_TO_DEPTH($pureName)
  switch $cmd {
    -1  {
      set newVal [expr $oldVal - 0.5];  if { $newVal < 0.0 }  { set newVal 0.0 }
    }
    1  {
      set newVal [expr $oldVal + 0.5]
    }
    0 {
      set newVal $estimatedDepth
    }
    default {
      ok_err_msg "Invalid depth modification command '$cmd' for image '$pureName'"
      return  0
    }
  }
  set PURENAME_TO_DEPTH($pureName) [_FormatCellToHeader $newVal $CHOSENDEPTH_HDR]
  return  1
}


# ".depthWnd.f.depthTable.plus_$pureName" -> {'pureName' 1}
# 'cmdVar' <- +1/-1/0 for Plus/Minus/Reset
# Returns 1 on success, 0 on error
proc _ParsePlusMinusResetButtonPath {btnPath pureNameVar cmdVar}  {
  upvar $pureNameVar pureName
  upvar $cmdVar cmd
  set prefix "\.depthWnd\.f\.depthTable"
  set pattern [format {%s\.(plus|minus|reset)_([^\n\r]+)} $prefix]
  ##set pattern [format {%s.([a-zA-Z]+)_([^\n\r]+)} $prefix]
  if { 0 == [regexp -expanded $pattern $btnPath fullMatch cmdWord pureName] }  {
    ok_err_msg "Invalid depth-modification button path '$btnPath';  pattern={$pattern}"
    return  0
  }
  switch [string toupper $cmdWord] {
    "PLUS"    {set cmd  1}
    "MINUS"   {set cmd -1}
    "RESET"   {set cmd  0}
    default   {
      ok_err_msg "Invalid command in depth-modification button path '$btnPath'"
      return  0
    }
  }
  return  1
}

