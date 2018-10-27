# nested_text.tcl

set ::_OPEN  0 ;   # means opening bracket
set ::_CLOSE 1 ;   # means closing bracket

set ::_nt_stack [list] ;  # for FIFO list of {type str} records (lists)

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