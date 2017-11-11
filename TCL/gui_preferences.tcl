# gui_preferences.tcl

package require Tk

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "preferences_mgr.tcl"]

### Sketch of the GUI #####
# |                    |                         |                           | |
# +--------------------------------------------------------------------------+-+
# |Raw Converter:      |              CBX rawConv                            | |
# +--------------------------------------------------------------------------+-+
# |BTN chooseDcrawPath |              ENT dcrawPath                          | |
# +--------------------------------------------------------------------------+-+
# |BTN chooseDefDir    |              ENT defWorkDir                         | |
# +--------------------------------------------------------------------------+-+
# |BTN chooseLogViewer |              ENT logViewerPath                      | |
# +--------------------------------------------------------------------------+-+
# |BTN chooseHelpViewer|              ENT helpViewerPath                     | |
# +--------------------------------------------------------------------------+-+
# |CB showTrace        |BTN  save                |BTN cancel                 | |
# +--------------------------------------------------------------------------+-+
set WND_TITLE "Underwater Image Color - Preferences"

set SHOW_TRACE $LOUD_MODE; # a proxy to prevent changing LOUD_MODE without "Save"

################################################################################
### Here (on top-level) the preferences-GUI is created but not yet shown.
### The code originated from: http://www.tek-tips.com/viewthread.cfm?qid=112205
################################################################################

toplevel .prefWnd

grid [ttk::frame .prefWnd.f -padding "3 3 12 12"] -column 0 -row 0 -sticky nwes
grid columnconfigure .prefWnd 0 -weight 1;   grid columnconfigure .prefWnd.f 0 -weight 0
grid columnconfigure .prefWnd.f 1 -weight 0
grid columnconfigure .prefWnd.f 2 -weight 0
grid columnconfigure .prefWnd.f 3 -weight 1
grid rowconfigure .prefWnd 0 -weight 0;   grid rowconfigure .prefWnd.f 0 -weight 0
grid rowconfigure .prefWnd.f 1 -weight 0; grid rowconfigure .prefWnd.f 2 -weight 0
grid rowconfigure .prefWnd.f 3 -weight 0; grid rowconfigure .prefWnd.f 4 -weight 0
grid rowconfigure .prefWnd.f 5 -weight 0; grid rowconfigure .prefWnd.f 6 -weight 0


grid [ttk::label .prefWnd.f.rawConvLbl -text "Default Raw Converter:"] -column 1 -row 1 -sticky w

grid [ttk::combobox .prefWnd.f.rawConv -textvariable INITIAL_CONVERTER_NAME] -column 2 -row 1 -columnspan 2 -sticky we
#(no need)  bind .prefWnd.f.rawConv <<ComboboxSelected>> GUI_SetDefaultRAWConverter
.prefWnd.f.rawConv configure -values $CONVERTER_NAME_LIST
.prefWnd.f.rawConv state readonly

grid [ttk::button .prefWnd.f.chooseDcrawPath -text "Dcraw path..." -command GUI_ChooseDcraw] -column 1 -row 2 -sticky w
grid [ttk::entry .prefWnd.f.dcrawPath -width 29 -textvariable DCRAW] -column 2 -row 2 -columnspan 2 -sticky we

grid [ttk::button .prefWnd.f.chooseDefDir -text "Default working folder..." -command GUI_ChooseDefDir] -column 1 -row 3 -sticky w
grid [ttk::entry .prefWnd.f.defDir -width 29 -textvariable INITIAL_WORK_DIR] -column 2 -row 3 -columnspan 2 -sticky we

grid [ttk::button .prefWnd.f.chooseLogViewer -text "Log viewer path..." -command GUI_ChooseLogViewer] -column 1 -row 4 -sticky w
grid [ttk::entry .prefWnd.f.logViewer -width 29 -textvariable LOG_VIEWER] -column 2 -row 4 -columnspan 2 -sticky we

grid [ttk::button .prefWnd.f.choosHelpViewer -text "Help viewer path..." -command GUI_ChooseHelpViewer] -column 1 -row 5 -sticky w
grid [ttk::entry .prefWnd.f.helpViewer -width 29 -textvariable HELP_VIEWER] -column 2 -row 5 -columnspan 2 -sticky we

grid [ttk::checkbutton .prefWnd.f.showTrace -text "Show Trace" -command _GUI_None -variable SHOW_TRACE] -column 1 -row 6 -sticky we

grid [ttk::button .prefWnd.f.save -text "Save" -command {set _CONFIRM_STATUS 1}] -column 2 -row 6
  # _CONFIRM_STATUS is a global variable that will hold the value
  # corresponding to the button clicked.  It will also serve as our signal
  # to our GUI_PreferencesShow procedure that the user has finished interacting with the dialog

grid [ttk::button .prefWnd.f.cancel -text "Cancel" -command {set _CONFIRM_STATUS 0}] -column 3 -row 6


foreach w [winfo children .prefWnd.f] {grid configure $w -padx 5 -pady 5}


# Set the window title, then withdraw the window
# from the screen (hide it)

wm title .prefWnd $WND_TITLE
wm withdraw .prefWnd

# Install a binding to handle the dialog getting
# lost.  If the user tries to click a mouse button
# in our main application, it gets redirected to
# the dialog window.  This binding detects a mouse
# click and in response deiconfies the window (in
# case it was iconified) and raises it to the top
# of the window stack.
#
# We use a symbolic binding tag so that we can
# install this binding easily on all modal dialogs
# we want to create.

bind modalDialog <ButtonPress> {
  wm deiconify %W
  raise %W
}

bindtags .prefWnd [linsert [bindtags .prefWnd] 0 modalDialog]

# Handle the "non-standard window termination" by
# invoking the Cancel button when we receives a
# WM_DELETE_WINDOW message from the window manager.
wm protocol .prefWnd WM_DELETE_WINDOW {
    .prefWnd.f.cancel invoke
}
################################################################################


###########################
# Display the dialog
###########################
proc GUI_PreferencesShow {} {
  global _CONFIRM_STATUS
  
  
  # read proxy variables
  set ::SHOW_TRACE $::LOUD_MODE
  
  
  # Save old keyboard focus
  set oldFocus [focus]

  # Set the dialog message and display the dialog

  wm deiconify .prefWnd

  # Wait for the window to be displayed
  # before grabbing events

  catch {tkwait visibility .prefWnd}
  catch {grab set .prefWnd}

  # Now drop into the event loop and wait
  # until the _CONFIRM_STATUS variable is
  # set.  This is our signal that the user
  # has clicked on one of the buttons.

  tkwait variable _CONFIRM_STATUS

  # Release the grab (very important!) and
  # return focus to its original widget.
  # Then hide the dialog and return the result.

  grab release .prefWnd
  
  # ? or:   focus .prefWnd.f.rawConv
  focus $oldFocus
  wm withdraw .prefWnd

  return $_CONFIRM_STATUS
}


proc GUI_ChooseDcraw {}  {
  global APP_TITLE DCRAW
  set oldFocus [focus];  # save old keyboard focus to restore it later
  set ret [tk_getOpenFile]
  catch {raise .prefWnd; focus $oldFocus}; # TODO: how to restore keyboard focus
  if { $ret != "" }  {
    set DCRAW $ret
    # TODO: check that the file chosen is executable
  }
  return  1
}


proc GUI_ChooseDefDir {}  {
  global APP_TITLE INITIAL_WORK_DIR
  set oldFocus [focus];  # save old keyboard focus to restore it later
  set ret [tk_chooseDirectory]
  catch {raise .prefWnd; focus $oldFocus}; # TODO: how to restore keyboard focus
  if { $ret != "" }  {
    set INITIAL_WORK_DIR $ret
  }
  return  1
}


proc GUI_ChooseLogViewer {}  {
  global APP_TITLE LOG_VIEWER
  set oldFocus [focus];  # save old keyboard focus to restore it later
  set ret [tk_getOpenFile]
  catch {raise .prefWnd; focus $oldFocus}; # TODO: how to restore keyboard focus
  if { $ret != "" }  {
    set LOG_VIEWER $ret
    # TODO: check that the file chosen is executable
  }
  return  1
}


proc GUI_ChooseHelpViewer {}  {
  global APP_TITLE HELP_VIEWER
  set oldFocus [focus];  # save old keyboard focus to restore it later
  set ret [tk_getOpenFile]
  catch {raise .prefWnd; focus $oldFocus}; # TODO: how to restore keyboard focus
  if { $ret != "" }  {
    set HELP_VIEWER $ret
    # TODO: check that the file chosen is executable
  }
  return  1
}


#~ proc GUI_IndicateLoudMode {}  {
  #~ global LOUD_MODE
  #~ ok_info_msg [format "Trace mode set to %s" [expr {($LOUD_MODE==1)? on : off}]]
#~ }


proc _GUI_None {}  {
  ok_info_msg "Called _GUI_None"
}
