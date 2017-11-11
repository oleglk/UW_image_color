# longest_path.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "topological_sort.tcl"]

set INF   32767; # "positive-infinity"
set NINF -32767; # "negative-infinity"

set FIRST "SOURCE";   # name for start vertex
set LAST  "DEST";     # name for end   vertex


proc FindLongestPath {graphDict} {
  _PriDict $graphDict
  set topoList [topsort $graphDict]
  if { $topoList == 0 }  {
    return  -1;   # error already printed
  }
  #~ set reversedDict [_ReverseGraphDict $graphDict]
  #~ if { $reversedDict == 0 }  {
    #~ return  -1;   # error already printed
  #~ }
  return  [_FindLongestPathGivenTopoSorting $graphDict $topoList]
}


proc _FindLongestPathGivenTopoSorting {graphDict topoList} {
  global FIRST LAST NINF INF
  # init distances; 0 for source, inf for the rest
  array unset distance
  set revTopoList [lreverse $topoList]
  foreach u $revTopoList { set distance($u) $NINF };   set distance($FIRST) 0
  array unset pred; # predecessors in the longest path
  puts "Topological order: {$revTopoList}"
  ok_info_msg "Start finding 'longest path' from $FIRST to $LAST in [llength $revTopoList] point graph"
  # process vertices in topological order - from FIRST to LAST
  foreach u $revTopoList {
    ok_trace_msg "... arrived at '$u'; distance==$distance($u)"
    if { $distance($u) != $NINF }  {
      # update distances and predecessors of all adjacent vertices
      if { 0 == [dict exists $graphDict $u] } {
        continue;   # no adjacent edges for sure
      }
      set adjList [dict get $graphDict $u]
      foreach v $adjList {
        set newDist [expr $distance($u) + 1]
        # override only if strictly greater to prioritize smaller depths' samples
        if { $newDist > $distance($v) } {
          set distance($v) $newDist
          set pred($v) $u
          ok_trace_msg "Preliminary distance to '$v' through '$u' is $newDist"
        }
      }
    }
  }
  # build the resulting list with the longest path
  set v $LAST
  set lpath [list $LAST]
  while { [info exists pred($v)] }  {
    if { $v == $pred($v) }  {
      ok_err_msg "Cycle in the 'longest path' at '$v'"
      return  0
    }
    set v $pred($v)
    set lpath [linsert $lpath 0 $v]
  }
  set lpath [lrange $lpath 1 [expr [llength $lpath] - 2]];  # remove FIRST/LAST
  ok_info_msg "Found 'longest path' of [llength $lpath] point(s) from $FIRST to $LAST in [llength $revTopoList]-point graph"
  return  $lpath 
}


#~ proc _ReverseGraphDict {graphDict} {
  #~ #TODO
#~ }


proc _PriDict {theDict} {
  dict for {key val} $theDict {
    puts "$key => $val"
  }
}


proc _Test_FindLongestPath {} {
  global FIRST LAST
  puts "-------- simple line graph -------"
  for { set i 1 } { $i < 10 } { incr i 1 }  {
    dict set graphDict1 $i [expr $i + 1]
  }
  dict set graphDict1 $FIRST 1;   dict set graphDict1 10 $LAST
  set lPath [FindLongestPath $graphDict1]
  puts "Input dictionary:";  _PriDict $graphDict1
  puts "Longest path '$FIRST'->'$LAST':   {$lPath}"
  puts "-------- add one bypass to the simple line graph -------"
  dict lappend graphDict1 1 4
  set lPath [FindLongestPath $graphDict1]
  puts "Input dictionary:";  _PriDict $graphDict1
  puts "Longest path '$FIRST'->'$LAST':   {$lPath}"
  puts "-------- force to use the bypass -------"
  set graphDict2 [dict remove $graphDict1 2]
  set lPath [FindLongestPath $graphDict2]
  puts "Input dictionary:";  _PriDict $graphDict2
  puts "Longest path '$FIRST'->'$LAST':   {$lPath}"
}