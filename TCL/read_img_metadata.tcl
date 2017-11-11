# read_img_metadata.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR            "debug_utils.tcl"]

set DCRAW "dcraw"

# indices for metadata fields
set iMetaDate 0
set iMetaTime 1
set iMetaISO  2



# Processes the following exif line(s):
# Timestamp: Sat Aug 23 08:58:21 2014
# Returns 1 if line was recognized, otherwise 0
proc _ProcessDcrawMetadataLine {line imgInfoArr} {
  global iMetaDate iMetaTime iMetaISO
  upvar $imgInfoArr imgInfo
  # example:'Timestamp: Sat Aug 23 08:58:21 2014'
  set isMatched [regexp {Timestamp: ([a-zA-Z]+) ([a-zA-Z]+) ([0-9]+) ([0-9]+):([0-9]+):([0-9]+) ([0-9]+)} $line fullMach \
                                    weekday month day hours minutes seconds year]
  if { $isMatched == 0 } {
    return  0
  }
  set imgInfo($iMetaDate) [list $year $month $day]
  set imgInfo($iMetaTime) [list $hours $minutes $seconds]
  return  1
}


# Puts into 'imgInfoArr' ISO, etc. of image 'fullPath'.
# On success returns number of data fields being read, 0 on error.
proc GetImageAttributesByDcraw {fullPath imgInfoArr} {
  global DCRAW
  global iMetaDate iMetaTime iMetaISO
  upvar $imgInfoArr imgInfo
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
    return  0
  }
  set readFieldsCnt 0
  # command to mimic: eval [list $::ext_tools::EXIV2 pr PICT2057.MRW]
  set tclExecResult [catch {
    # Open a pipe to the program, then get the reply and process it
    # set io [open "|dcraw.exe -i -v $fullPath" r]
    set io [eval [list open [format {|{%s}  -i -v %s} \
             $DCRAW $fullPath] r]]
    # while { 0 == [eof $io] } { set len [gets $io line]; puts $line }
    while { 0 == [eof $io] } {
      set len [gets $io line]
      #puts $line
      if { 0 != [_ProcessDcrawMetadataLine $line imgInfo] } {
        incr readFieldsCnt
      }
    }
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!";	return  0
  }
  set tclExecResult [catch {
    close $io;  # generates error; separate "catch" to suppress it
  } execResult]
  if { $tclExecResult != 0 } {	ok_warn_msg "$execResult"    }
  if { $readFieldsCnt == 0 } {
    ok_err_msg "Cannot understand metadata of '$fullPath'"
    return  0
  }
  ok_trace_msg "Metadata of '$fullPath': time=$imgInfo($iMetaTime)"
  return  $readFieldsCnt
}

