# nested_text.tcl

set ::_OPEN  0 ;   # means opening bracket
set ::_CLOSE 1 ;   # means closing bracket

set ::_nt_stack [list] ;  # for FIFO list of {type str} records (lists)


# Returns folded version of 'inpTxt' folded around 'beginTag' and  'endTag'.
# 'beginTag' and  'endTag' are regular-expression patterns.
# 'numLevels' tells how many nesting levels to fold - from innermost. 0 means all.
# On error returns 0.
proc nested_text_fold {inpTxt beginTag endTag numLevels}  {
  set tail $inpTxt ;  # unprocessed yet text
  set nestList [nested_text_to_list $inpTxt $beginTag $endTag]
  if { $nestList == 0 }  {  return  0 };  # error already printed
  set outTxt [nested_text_from_list $nestList $beginTag $endTag $numLevels]
  if { $outTxt == 0 }  {  return  0 };  # error already printed
  return  $outTxt
}


# 
proc nested_text_to_list {inpTxt beginTag endTag} {
  # TODO: implement
}


# 
proc nested_text_from_list {nestList beginTag endTag numLevels}   {
  # TODO: implement
}


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
