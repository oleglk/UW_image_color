# raw_manip.tcl - read and convert RAW images

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "read_img_metadata.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]


set CONVERT  [file nativename "C:/Program Files/ImageMagick-6.8.6-8/convert.exe"]

set CONV_MODE_COLORTARGET 0
set CONV_MODE_PREVIEW     1
set CONV_MODE_THUMBNAIL   2


proc FindThumbnails {subdirPath {priErr 1}} {
  #global THUMB_DIR THUMB_COLORTARGET_DIR
  set thumbNamePattern [_MakeThumbnailFilename "*.ANY_EXT"]
  set thumbPathPattern [file join $subdirPath $thumbNamePattern]
  ok_trace_msg "Thumbnail search pattern: '$thumbPathPattern'"
  set tclResult [catch {
    set res [glob $thumbPathPattern] } execResult]
  if { $tclResult != 0 } {
    if { $priErr != 0 } { ok_err_msg "$execResult!" }
    return  [list]
  }
  return  $res
}


proc _MakeThumbnailFilename {rawPath} {
  return  "[file rootname [file tail $rawPath]].thumb.JPG"
}

proc ConvertOneRaw {convMode rawPath outDir mR mG mB} {
  global CONV_MODE_COLORTARGET CONV_MODE_PREVIEW CONV_MODE_THUMBNAIL
  global CONVERT DCRAW
  if { 0 == [file exists $outDir]  }  {  file mkdir $outDir  }
  set outPath  [file join $outDir "[file rootname [file tail $rawPath]].TIF"]

  ok_info_msg "ConvertOneRaw: processing $rawPath; colors: {$mR $mG $mB}..."
  if       { $convMode == $CONV_MODE_PREVIEW } {
    # auto gamma correction
    set outPath  [file join $outDir "[file rootname [file tail $rawPath]].JPG"]
    if { 0 == [CanWriteFile $outPath] }  {
      ok_err_msg "Cannot write into '$outPath'";    return 0
    }
    #exec dcraw  -r $mR $mG $mB $mG  -o 2  -q 3  -h  -k 10   -c  $rawPath | $CONVERT ppm:- -quality 95 $outPath
    #exec dcraw  -r $mR $mG $mB $mG  -o 1  -q 3  -h   -k 10   -c  $rawPath | $CONVERT ppm:- -quality 95 $outPath
    exec $DCRAW  -r $mR $mG $mB $mG  -o 1  -q 3  -h           -c  $rawPath | $CONVERT ppm:- -quality 95 $outPath
  } elseif { $convMode == $CONV_MODE_COLORTARGET } {
    # fixed gamma correction
    #TODO: try no color-space
    set outPath  [file join $outDir "[file rootname [file tail $rawPath]].TIF"]
    if { 0 == [CanWriteFile $outPath] }  {
      ok_err_msg "Cannot write into '$outPath'";    return 0
    }
    #exec dcraw  -r $mR $mG $mB $mG  -o 2  -q 3  -h  -4 -k 10 -b 2.0 -g 2.2 0  -T -c  $rawPath > $outPath
    exec dcraw  -r $mR $mG $mB $mG  -o 2  -q 3  -h  -4 -k 10  -b 2.0 -g 2.2 0  -T -c  $rawPath > $outPath
  } elseif { $convMode == $CONV_MODE_THUMBNAIL } {
    # only extract thumbnail; color-multipliers are ignored
    set outPath  [file join $outDir [_MakeThumbnailFilename $rawPath]]
    if { 0 == [CanWriteFile $outPath] }  {
      ok_err_msg "Cannot write into '$outPath'";    return 0
    }
    exec $DCRAW  -e -c  $rawPath > $outPath
  } else {
    ok_err_msg "Unsupported conversion mode $convMode"
    return  0
  }
  return  1
}


# Returns number of successfully converted RAWs
proc ConvertRaw {convMode rawPathList outDir mR mG mB} {
  if { 0 == [file exists $outDir]  }  {  file mkdir $outDir  }
  ok_info_msg "ConvertRaw: start processing [llength $rawPathList] RAW(s) ; colors: {$mR $mG $mB}..."
  set cnt 0
  foreach f $rawPathList {
    if { 1 == [ConvertOneRaw $convMode $f $outDir $mR $mG $mB] }   {
      incr cnt 1
    } ;  # else: error already printed
  }
  ok_info_msg "ConvertRaw: finished"
  return  $cnt
}


# Extracts thumbnails from all RAWs in 'rawPathList'. Returns "" on success.
# On error returns error message.
proc ExtractThumbsFromRaw {rawPathList} {
  global THUMB_DIR THUMB_COLORTARGET_DIR CONV_MODE_THUMBNAIL
  if { 0 == [llength $rawPathList] }  {
    set msg "No RAW(s) provided for thumbnail extraction.";   ok_err_msg $msg
    return  $msg
  }
  if { 0 != [ConvertRaw $CONV_MODE_THUMBNAIL $rawPathList $THUMB_DIR 1 1 1] }  {
    if { 0 == [file exists $THUMB_COLORTARGET_DIR]  }  {
      file mkdir $THUMB_COLORTARGET_DIR
    }
    ok_info_msg "Done extracting [llength $rawPathList] thumbnail(s) from RAW(s)."
    ok_info_msg "Now move gray-target thumbnails from '$THUMB_DIR' into '$THUMB_COLORTARGET_DIR'"
    return  ""
  } else {
    set msg "Failed extracting [llength $rawPathList] thumbnail(s) from RAW(s)."
    ok_err_msg $msg;  return  0
  }
}


proc SortRawsByThumbnails {rawPathList} {
  global THUMB_DIR THUMB_COLORTARGET_DIR RAW_COLOR_TARGET_DIR
  if { 0 == [llength $rawPathList] }  {
    set msg "No RAW(s) provided for sortinng by thumbnails"
    ok_err_msg $msg;    return  $msg
  }
  if { 0 == [file exists $RAW_COLOR_TARGET_DIR]  }  {
    file mkdir $RAW_COLOR_TARGET_DIR
  }
  ok_info_msg "SortRawsByThumbnails: start processing [llength $rawPathList] RAW(s)..."
  set thCnt 0
  foreach f $rawPathList {
    set thumbName [_MakeThumbnailFilename $f]
    set thumbPath [file join $THUMB_COLORTARGET_DIR $thumbName]
    if { 1 == [file exists $thumbPath] }  {
      set nameNoDir [file tail $f];  set dirPath [file dirname $f]
      ok_info_msg "Image '$nameNoDir' considered a WB target"
      incr thCnt 1
      # move the RAW and all related files (like settings)
      set allForOneImage [FindAllInputsForOneRAWInDir $nameNoDir $dirPath]
      foreach fr $allForOneImage {
        set newPath [file join $RAW_COLOR_TARGET_DIR [file tail $fr]]
        file rename -force $fr $newPath
      }
    } else {
      #ok_trace_msg "Image '[file tail $f]' considered an ultimate photo ('$thumbPath' inexistent)"
    }
  }
  set msg "SortRawsByThumbnails: finished; $thCnt image(s) considered WB target(s) and moved into '$RAW_COLOR_TARGET_DIR'"
  if { $thCnt > 0 }  {
    ok_info_msg $msg;    return  "";      # empty message on success
  }  else  {
    ok_warn_msg $msg;    return  $msg;    # message on a problem
  }
}
