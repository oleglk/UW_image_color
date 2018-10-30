# nested_text.tcl

set ::_OPEN  0 ;   # means opening-bracket tag
set ::_CLOSE 1 ;   # means closing-bracket tag
set ::_BODY  2 ;   # means block's body (between opener and closer)


set ::_nt_stack [list] ;  # for FIFO list of {type str} records (lists)


# Returns position indices for the body of nested text block
#         enclosed by start+end tags in 'enclosingTags'.
# If there are several occurences, only the 1st one is picked.
# Examples for 'inpTxt' == "B0{body0_B1{ body1 B2:{- body2 -}  }  }" :
## [list  [list "B0{" "}"]  [list "B1{" "}"]]  ==> " body1 B2:{- body2 -}  "
## [list  [list "B0{" "}"]  [list "B1{" "}"]  [list "B2:{" "}"]]  ==> "- body2 -"
# Returns "*ERROR*" on structural error, "" if block not found
proc TODO__nested_text_one_block_find {inpTxt enclosingTags}  {
}


#~ # Returns folded version of 'inpTxt' folded around 'beginTag' and  'endTag'.
#~ # 'beginTag' and  'endTag' are regular-expression patterns.
#~ # 'foldFromLevel' tells from which level to start folding - counting from outermost. 0 means all.
#~ # On error returns 0.
#~ proc TODO__nested_text_fold {inpTxt beginTag endTag foldFromLevel}  {
  #~ set tail $inpTxt ;  # unprocessed yet text
  #~ set nestList [nested_text_to_list $inpTxt $beginTag $endTag]
  #~ if { $nestList == 0 }  {  return  0 };  # error already printed
  #~ set outTxt [nested_text_from_list $nestList $beginTag $endTag $numLevels]
  #~ if { $outTxt == 0 }  {  return  0 };  # error already printed
  #~ return  $outTxt
#~ }


#~ # Returns (flat) list of records that describe fragments in text structure:
#~ #  {type nest-level begin-index end-index}
#~ #  type = _OPEN | _CLOSE | _BODY
#~ # If no tags found, returns 0.
#~ proc TODO__nested_text_parse_into_fragments {inpTxt beginTag endTag} {
  #~ # TODO: implement
#~ }


#~ # Returns (flat) list of records that describe tagss in text structure:
#~ #  {type -1 begin-index end-index}
#~ #  type = _OPEN | _CLOSE
#~ # If no tags found, returns 0.
#~ proc TODO__nested_text_find_tag_positions {inpTxt beginTag endTag} {
  #~ set openTagsList_repeated [regexp -all -inline -indices -- $beginTag]
  #~ if { $openTagsList_repeated == "" }  { return  0 };   # nothing found
  #~ # [regexp -all -inline -indices {(\d+)} "01--4"]  ==>  {0 1} {0 1} {4 4} {4 4}
  #~ set openTagsList [dict keys $openTagsList_repeated];  # ==>  {0 1} {4 4} 
  #~ if { $closeTagsList_repeated == "" }  { return  0 };   # nothing found
  #~ set closeTagsList [dict keys $closeTagsList_repeated]
  #~ # build combined list of open- and close tags
  #~ set resList [list]
  #~ set curPos 0
  #~ set iOpen 0; set iClose 0; # current indices in 'openTagsList' & 'closeTagsList'
  #~ while { ($iOpen < [llength $openTagsList]) && \
          #~ ($iClose < [llength $closeTagsList]) }  {
    #~ set posOpen  [lindex [lindex $openTagsList $iOpen] 0]   ; # begin of open
    #~ set posClose [lindex [lindex $closeTagsList $iClose] 0] ; # begin of close
    #~ if { $posOpen < $posClose } {
      #~ set posEndOpen [lindex [lindex $openTagsList $iOpen] 1]
      #~ lappend resList [list $::_OPEN -1 $posOpen $posEndOpen]
    #~ } else {
      #~ set posEndClose [lindex [lindex $closeTagsList $iClose] 1]
      #~ lappend resList [list $::_CLOSE -1 $posClose $posEndClose]
    #~ }
    #~ # TODO: implement
  #~ }
  #~ # TODO: leftovers
#~ }


#~ # 
#~ proc TODO__nested_text_fold_by_taglist {inpTxt tagList foldFromLevel}   {
  #~ # TODO: implement
#~ }


############################ Local utilites ####################################
# Puts 'str' onto stack as type 'openOrClose' ($::_OPEN / $::_CLOSE)
proc _nested_text_push {openOrClose str} {
  lappend ::_nt_stack [list $openOrClose $str]
}


# Reads 'str' and type (into 'openOrClose') from stack. Removes it from the stack.
# Returns`1 on success, 0 on empty stack
proc _nested_text_pop {openOrClose str} {
  upvar $openOrClose openOrClose_
  upvar $str str_
  if { 0 == [_nested_text_top openOrClose_ str_] }  { return  0 }; # empty or error
  set ::_nt_stack [lreplace $::_nt_stack end end]
  return  1
}


# Reads 'str' and type (into 'openOrClose') from stack. Dosn't change the stack
# Returns`1 on success, 0 on empty stack
proc _nested_text_top {openOrClose str} {
  upvar $openOrClose openOrClose_
  upvar $str str_
  if { [_nested_text_stack_is_empty] }  {    return  0  }
  set record [lindex $::_nt_stack end]
  set openOrClose_ [lindex $record 0];  set str_ [lindex $record 1]
  return  1
}


# Returns 1 on empty stack, 0 otherwise
proc _nested_text_stack_is_empty {} {
  return  [expr {0 == [llength $::_nt_stack]}]
}

 
# Removes all content from the stack
proc _nested_text_clear_stack {} {
  set ::_nt_stack [list]
}


# Returns 1 on empty stack, 0 otherwise
proc _nested_text_top_is_opener {} {
  if { 0 == [_nested_text_top openOrClose_ str_] }  { return  0 }; # empty or error
  return  [expr {$openOrClose_ == $::_OPEN}]
}


# Returns 1 on empty stack, 0 otherwise
proc _nested_text_top_is_closer {} {
  if { 0 == [_nested_text_top openOrClose_ str_] }  { return  0 }; # empty or error
  return  [expr {$openOrClose_ == $::_CLOSE}]
}
############################ End of local utilites #############################
