if 0 {
[A text adventure game engine]
[Scott Beasley] 2008-05-26
}
 # Game Engine - Save as TclAdamsEng.tcl

 #############################################################################
 ## TclAdamsEng.tcl
 ## Package to play Scott Adams Adventure game files in the TRS-80 format
 ## (ScottFree).
 ##
 ## Author: Scott Beasley (scottbeasley@gmail.com)
 ## Feel free to *itch, or send patches to the above address :-)
 ##
 #############################################################################

 # Declare and build some "noseeums" for the game.
 set dirs {N NO NOR NORTH\
           S SO SOU SOUTH\
           E EA EAS EAST\
           W WE WES WEST\
           U UP\
           D DO DOW DOWN}
 # Used to map direction letter to noun number.
 set dirmap {N 0 S 1 E 2 W 3 U 4 D 5}
 set dirnames [list NORTH SOUTH EAST WEST UP DOWN]

 proc GetRandomNumber { } {
    set inum [expr {int (rand()*101)}]
    return $inum
 }

 # Clean-up game dB read data.
 proc Clean {args} {
    foreach argval $args {
       upvar $argval ptr
       set ptr [string trim $ptr {\" }]
    }      
 }

 # Read in all chars from a file, between two '"'
 # Note: This is a quick hack at it, feel free to replace :-)
 proc ReadQuotedMsg {fd {option ""}} {
    set msg_buff {}
    set QuoteCnt 0

    while {[set char [read $fd 1]] != {}} {
	if {$char == "\"" && [incr QuoteCnt] > 1} {
		# Throw away the end of line
		if {$option == "-endofline"} { gets $fd }
		break   
	} elseif {$QuoteCnt > 0} {

		append msg_buff $char         
	}
    }
    return $msg_buff
 }

 proc CountCarriedInv {strGameInfo} {
    upvar $strGameInfo GameInfo

    set indx 0   
    foreach item_info $GameInfo(items) {
       if {[lindex $item_info 1] == -1} {
         incr indx         
      }
    }
   
    return $indx   
 }

 ## Return the verb number for a given verb string.
 proc GetVerbNo {strGameInfo verb} {
   upvar $strGameInfo GameInfo

   set verb_no 0
   set found_one 0
   
   set verb [string range $verb 0 [expr {$GameInfo(WordLen)-1}]]
   
   foreach verb_noun $GameInfo(words) {
      set WasSynonym 0
      set game_verb [lindex $verb_noun 0]
      if {[string index $game_verb 0] != "*"} {
         set curr_verb_no $verb_no
      } else {
        set game_verb [string range $game_verb 1 end]
        set WasSynonym 1         
      }         

      if {$verb == $game_verb} {
         set found_one 1
         if {$WasSynonym} {
            set verb_no $curr_verb_no
         }
         
         break   
      }
      
      incr verb_no
   }

   if {!$found_one} {
      return -1   
   }
   
   return $verb_no    
 }

 ## Return the noun number for a given noun string.
 proc GetNounNo {strGameInfo noun} {
   upvar $strGameInfo GameInfo

   set noun_no 0
   set found_one 0

   set noun [string range $noun 0 [expr {$GameInfo(WordLen)-1}]]
   
   foreach verb_noun $GameInfo(words) {
      set WasSynonym 0
      set game_noun [lindex $verb_noun 1]
      if {[string index $game_noun 0] != "*"} {
         set curr_noun_no $noun_no
      } else {
         set game_noun [string range $game_noun 1 end]
         set WasSynonym 1         
      }
      
      if {$noun == $game_noun} {
         set found_one 1         
         if {$WasSynonym} {
            set noun_no $curr_noun_no
         }
         
         break   
      }
      
      incr noun_no
   }

   if {!$found_one} {
      return -1   
   }
   
   return $noun_no    
 }

 proc Look {strGameInfo} {
   upvar $strGameInfo GameInfo
   global dirnames
   
   set room $GameInfo(CurrentRoom)

   # Get exits to location...
   set room_info [lindex $GameInfo(locations) $room]
   set GameInfo(RoomText) [lindex $room_info 6]
   if {[string index $GameInfo(RoomText) 0] == "*"} {
      set GameInfo(RoomText) [string range $GameInfo(RoomText) 1 end]
   }
   
   set dirs [lrange $room_info 0 5]
   set dir_txt {}    
   set dir_ndx 0   
   foreach dir $dirs {
      if {$dir != 0} {
         append dir_txt "[lindex $dirnames $dir_ndx] "
      }
 
      incr dir_ndx      
   }

   set GameInfo(RoomExits) $dir_txt

   ## Get Items at location...
   set GameInfo(ItemsInRoom) {}
   foreach item_info $GameInfo(items) {
      if {[lindex $item_info 1] == $room} {
         set item_desc [lindex [split [lindex $item_info 0] {/}] 0]
         lappend GameInfo(ItemsInRoom) $item_desc
      }      
   }
   
   return 0   
 }

 proc ItemLocationChange {strGameInfo item_no room} {
   upvar $strGameInfo GameInfo

   set item_info [lindex $GameInfo(items) $item_no]
   set GameInfo(items) [lreplace $GameInfo(items) $item_no \
                       $item_no [list [lindex $item_info 0] $room\
                       [lindex $item_info 2]]]
 }

 proc GetOrDrop {strGameInfo action item {static_ignore {}}} {
   upvar $strGameInfo GameInfo
   set iRet 4

   ## This will let us match it from the noun part of the table
   ## And handle the user typing syn's also.
   set noun_ndx [GetNounNo GameInfo $item]
   if {$noun_ndx > -1} {
      set item [lindex [lindex $GameInfo(words) $noun_ndx] 1]
   }

   # Get...   
   if {!$action} {      
      set item_ndx 0      
      foreach item_info $GameInfo(items) {
         set item_desc [lindex [split [lindex $item_info 0] {/}] 0]
         set item_name [string trim [lindex [split [lindex \
                        $item_info 0] {/}] 1]]
         set item_loc [lindex $item_info 1]         

         if {($item_name == $item && $item_loc == $GameInfo(CurrentRoom))} {
            if {[CountCarriedInv GameInfo] >= $GameInfo(MaxItemsCarry)} {
               set iRet 10
               break               
            }

            ## Is the item static?         
            if {$item_name == ""} {
               if {$static_ignore == ""} {               
                  set iRet 5
               }
               
               break            
            }

            ## See if we have it already...            
            if {$item_loc == -1} {
               set iRet 6
               break            
            }               
         
            set iRet 0
            ItemLocationChange GameInfo $item_ndx -1
            break            
         }
         
         incr item_ndx
      }      
   }

   ## Drop...
   if {$action} {      
      set item_ndx 0      
      foreach item_info $GameInfo(items) {
         set item_desc [lindex [split [lindex $item_info 0] {/}] 0]
         set item_name [string trim [lindex [split [lindex \
                        $item_info 0] {/}] 1]]
         set item_loc [lindex $item_info 1]

         ## Yet another hack fix.... 
         ## Doing this helps with Items that have the same name.
         ## Pirate's Cove was really bad about this.         
         if {$item_loc == 0} {
            incr item_ndx
            continue
         }
         
         if {$item_name == $item} {
            if {$item_loc == -1} {            
               set iRet 0
               ItemLocationChange GameInfo $item_ndx $GameInfo(CurrentRoom)
               break
            } else {
               set iRet 9
               break            
            }               
         }
         
         incr item_ndx
      }      
   }
   
   return $iRet
 }

 proc MoveInDirection {strGameInfo dir_no} {
   upvar $strGameInfo GameInfo

   set room_info [lindex $GameInfo(locations) $GameInfo(CurrentRoom)]
   set room [lindex $room_info $dir_no]
   if {$room} {
      set GameInfo(CurrentRoom) $room
   } else {
      return 3      
   }      

   return 0   
 }

 proc CheckConditions {strGameInfo conds_lst} {
   upvar $strGameInfo GameInfo

   ## Clear the param list here.   
   set GameInfo(param_lst) {}
   
   foreach condition $conds_lst {
      set cond 1      
      set cond_val [expr {$condition%20}]
      set arg_val [expr {$condition/20}]      

      ## Check for one of 19 condition types.      
      switch $cond_val {
         0 {
            lappend GameInfo(param_lst) $arg_val
         }

         1 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {[lindex $item_info 1] != -1} {
               set cond 0
            }           
         }            
         
         2 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {[lindex $item_info 1] != $GameInfo(CurrentRoom)} {
               set cond 0
            }
         }            
         
         3 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {[lindex $item_info 1] != $GameInfo(CurrentRoom) && \
                [lindex $item_info 1] != -1} {
               set cond 0
            }           
         }            
         
         4 {
            if {$arg_val != $GameInfo(CurrentRoom)} {
               set cond 0
            }           
         }            
         
         5 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {[lindex $item_info 1] == $GameInfo(CurrentRoom)} {
               set cond 0
            }           
         }            
         
         6 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {[lindex $item_info 1] == -1} {
               set cond 0
            }           
         }            

         7 {
            if {$arg_val == $GameInfo(CurrentRoom)} {
               set cond 0
            }           
         }            
         
         8 {
            if {!$GameInfo(Flag-$arg_val)} {
               set cond 0
            }               
         }            
         
         9 {
            if {$GameInfo(Flag-$arg_val)} {
               set cond 0
            }
         }            
         
         10 {
            if {![CountCarriedInv GameInfo]} {
               set cond 0
            }               
         }            
         
         11 {
            if {[CountCarriedInv GameInfo]} {
               set cond 0
            }               
         }            

         12 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {[lindex $item_info 1] == $GameInfo(CurrentRoom) || \
                [lindex $item_info 1] == -1} {
               set cond 0
            }           
         }            

         13 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {![lindex $item_info 1]} {
               set cond 0
            }           
         }            

         14 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {[lindex $item_info 1]} {
               set cond 0
            }           
         }            
        
         15 {
            if {[CountCarriedInv GameInfo] > $arg_val} {
               set cond 0
            }               
         }            

         16 {
            if {[CountCarriedInv GameInfo] <= $arg_val} {
               set cond 0
            }               
         }            

         17 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {[lindex $item_info 1] != [lindex $item_info 2]} {
               set cond 0
            }           
         }            

         18 {
            set item_info [lindex $GameInfo(items) $arg_val]
            if {[lindex $item_info 1] == [lindex $item_info 2]} {
               set cond 0
            }           
         }            

         19 {
            if {$GameInfo(CurrentCounter) != $arg_val} {
               set cond 0      
            }               
         }         
      }
      
      if {!$cond} {
         set GameInfo(ConditionFailed) 1
         break      
      } else {
         set GameInfo(ConditionFailed) 0         
      }         
   }
   
   return $cond
 }

 proc DoActions {strGameInfo action_lls} {
   upvar $strGameInfo GameInfo

   set GameInfo(param_ndx) 0    
   foreach action $action_lls {
      if {!$action} {
         continue
      }
      
      ## Append any msg's to the current msg list.
      if {$action >= 1 && $action < 52} {
         lappend GameInfo(CurrentMsgs) [lindex $GameInfo(messages) $action]
         continue         
      }         

      if {$action > 101} {
         lappend GameInfo(CurrentMsgs) [lindex $GameInfo(messages) \
                 [expr {$action-50}]]
         continue                        
      }
      
      set arg_param [lindex $GameInfo(param_lst) $GameInfo(param_ndx)]
      ## See if it was another type of action.            
      switch $action {
         52 {
            if {[CountCarriedInv GameInfo] >= $GameInfo(MaxItemsCarry)} {
               lappend GameInfo(CurrentMsgs) "You are carrying to much!\n"
               break               
            }

            ItemLocationChange GameInfo $arg_param -1
            incr GameInfo(param_ndx)
            set GameInfo(DidGetOrDrop) 1
         }            

         53 {
            ItemLocationChange GameInfo $arg_param $GameInfo(CurrentRoom)
            incr GameInfo(param_ndx)
            set GameInfo(DidGetOrDrop) 1
         }
         
         54 {
            set GameInfo(CurrentRoom) $arg_param
            incr GameInfo(param_ndx)
         }            

         55 -
         59 {         
            ItemLocationChange GameInfo $arg_param 0
            incr GameInfo(param_ndx)
         }            
            
         56 {
            set GameInfo(IsDark) 1
            set GameInfo(Flag-15) 1
         }            

         57 {
            set GameInfo(IsDark) 0
            set GameInfo(Flag-15) 0
         }            
         
         58 -
         60 {
            set GameInfo(Flag-$arg_param) [expr {$action==60?0:1}]
            incr GameInfo(param_ndx)
         }            

         61 {
            set GameInfo(IsDead) 1
            set GameInfo(IsDark) 0
            set GameInfo(Flag-15) 0
            set GameInfo(CurrentRoom) [expr {$GameInfo(NumberOfRooms)-1}]
         }
         
         62 {
            incr GameInfo(param_ndx)
            set iroom [lindex $GameInfo(param_lst) $GameInfo(param_ndx)]
            ItemLocationChange GameInfo $arg_param $iroom
            incr GameInfo(param_ndx)
         }
         
         63 {
            set GameInfo(GameOver) 0
            if {$GameInfo(GameOverFunc) != ""} {
               eval $GameInfo(GameOverFunc)
            }
         }

         64 -
         76 {
            if {$GameInfo(LookFunc) != ""} {
               eval $GameInfo(LookFunc)
            }
         }            
         
         65 {
            set iTreasureCnt 0
            foreach item_info $GameInfo(items) {
               if {([lindex $item_info 1] == $GameInfo(TreasureRoom)) && \
                   [string index [lindex $item_info 0] 0] == "*"} {
                  incr iTreasureCnt
               }                  
            }
            
            set iScore [expr {$iTreasureCnt*100/$GameInfo(TotalTreasures)}]

            if {$GameInfo(TotalTreasures) == $iTreasureCnt} {
               lappend GameInfo(CurrentMsgs) "\nYou Win!"
            }
   
            lappend GameInfo(CurrentMsgs) "\nYou have stored away\
                    $iTreasureCnt of $GameInfo(TotalTreasures) total\
                    treasures." "Your score is $iScore."
         }
         
         66 {
            lappend GameInfo(CurrentMsgs) "\nYou are carrying:"
            if {![CountCarriedInv GameInfo]} {
               lappend GameInfo(CurrentMsgs) "Nothing."
            }

            set iLineLen 0
            set iDivder 0
            set InvLine {}                  
            foreach item_info $GameInfo(items) {
               if {[lindex $item_info 1] != -1} {
                  continue
               }
               
               set item [lindex [split [lindex $item_info 0] {/}] 0]               
               append InvLine "$item. "
       
               if {[expr {$iLineLen+[string length $item]+2}] >= \
                   $GameInfo(MaxDisplayWidth)} {
                  lappend GameInfo(CurrentMsgs) "$InvLine\n"
                  set iLineLen 0
                  set InvLine {}                  
               }
        
               incr iLineLen [expr {[string length $item]+2}]
            }
            
            lappend GameInfo(CurrentMsgs) "$InvLine\n"
         }

         67 {
            set GameInfo(Flag-0) 1
         }
         
         68 {
            set GameInfo(Flag-0) 0
         }
         
         69 {
            set GameInfo(LightCountDown) $GameInfo(TotalLightTime)
            ## Item number 9 is always the light source.
            ItemLocationChange GameInfo 9 -1            
            set GameInfo(IsDark) 0
            set GameInfo(Flag-15) 0
         }
         
         70 {
 ##            set GameInfo(CurrentMsgs) {}
            if {$GameInfo(ClearFunc) != ""} {
               eval $GameInfo(ClearFunc)
            }
         }
         
         71 {
            if {$GameInfo(SaveGameFunc) != ""} {
               eval $GameInfo(SaveGameFunc)
            }
         }
         
         72 {
            set item_no1 $arg_param
            incr GameInfo(param_ndx)
            set item_no2 [lindex $GameInfo(param_lst) $GameInfo(param_ndx)]
            set item_loc1 [lindex [lindex $GameInfo(items) $item_no1] 1]
            set item_loc2 [lindex [lindex $GameInfo(items) $item_no2] 1]
            ItemLocationChange GameInfo $item_no1 $item_loc2
            ItemLocationChange GameInfo $item_no2 $item_loc1
            incr GameInfo(param_ndx)
         }
         
         73 {
            set GameInfo(Continue) 1
         }
         
         74 {
            ItemLocationChange GameInfo $arg_param -1
            incr GameInfo(param_ndx)
         }
         
         75 {
            set item_no1 $arg_param
            incr GameInfo(param_ndx)
            set item_no2 [lindex $GameInfo(param_lst) $GameInfo(param_ndx)]
            set item_loc2 [lindex [lindex $GameInfo(items) $item_no2] 1]
            ItemLocationChange GameInfo $item_no1 $item_loc2
            incr GameInfo(param_ndx)
         }
         
         77 {
            if {$GameInfo(CurrentCounter) >= 0} {
               incr GameInfo(CurrentCounter) -1
            }
         }
         
         78 {
            lappend GameInfo(CurrentMsgs) $GameInfo(CurrentCounter)
         }
         
         79 {
            set GameInfo(CurrentCounter) $arg_param
            incr GameInfo(param_ndx)
         }
         
         80 {
            set iSwap $GameInfo(RoomNumberHold)
            set GameInfo(RoomNumberHold) $GameInfo(CurrentRoom)
            set GameInfo(CurrentRoom) $iSwap
         }

         81 {
            set iSwap $GameInfo(CurrentCounter)
            set GameInfo(CurrentCounter) $GameInfo(Counter-$arg_param)
            set GameInfo(Counter-$arg_param) $iSwap
            incr GameInfo(param_ndx)
         }
         
         82 {
            incr GameInfo(CurrentCounter) $arg_param
            incr GameInfo(param_ndx)
         }
         
         83 {
            set arg_val "-$arg_param"
            incr GameInfo(CurrentCounter) $arg_val
            incr GameInfo(param_ndx)
         }
         
         84 {
            lappend GameInfo(CurrentMsgs) $GameInfo(TypedNoun)
         }
         
         85 {
            lappend GameInfo(CurrentMsgs) $GameInfo(TypedNoun) "\n"
         }
         
         86 {
            lappend GameInfo(CurrentMsgs) "\n"
         }
         
         87 {
            set iSwap $GameInfo(CurrentRoom)
            set GameInfo(CurrentRoom) $GameInfo(RoomStack-$arg_param)
            set GameInfo(RoomStack-$arg_param) $iSwap
            incr GameInfo(param_ndx)
         }
         
         88 {
            after 2000
         }
         
         89 {
            incr GameInfo(param_ndx)
         }
      }
   }
 }   

 proc CheckActions {strGameInfo verb_no noun_no} {
   upvar $strGameInfo GameInfo
   set repeat 0
   set iWasAction 0
   
   ## Clear the param list counter here.   
   set GameInfo(param_ndx) 0

   ## Loop all the actions in the list and see if we have a hit.   
   foreach action_info $GameInfo(actions) {
      set vocab [lindex $action_info 0]
      set action_verb [expr {$vocab/150}]
      set action_noun [expr {$vocab%150}]
      set cond1 [lindex $action_info 1]
      set cond2 [lindex $action_info 2]
      set cond3 [lindex $action_info 3]
      set cond4 [lindex $action_info 4]
      set cond5 [lindex $action_info 5]
      
      if {($action_verb == $verb_no || !$action_verb) || ($repeat && !$action_verb)} {
         if {($action_noun == $noun_no || !$action_noun) || !$action_verb} {
            ## Code for conditions that are only checked n% of the time.            
            if {(!$action_verb && \
                ([GetRandomNumber] >= $action_noun)) && !$repeat} {
               continue                   
            }
            
            set condition [CheckConditions GameInfo [list $cond1 $cond2 \
                                           $cond3 $cond4 $cond5]]
                                         
            if {$condition} {
               set action1 [lindex $action_info 6]
               set action2 [lindex $action_info 7]
               set act0 [expr {$action1/150}]
               set act1 [expr {$action1%150}]
               set act2 [expr {$action2/150}]
               set act3 [expr {$action2%150}]

               DoActions GameInfo [list $act0 $act1 $act2 $act3]
               set iWasAction 1
               ## I guess this is right?               
               if {$GameInfo(Continue)} {               
                  set GameInfo(Continue) 0
                  set repeat 1                  
               }
               
               if {$action_verb && !$repeat} {
                  break
               }         
            }               
         }
      }

      if {$action_verb} {
         set repeat 0   
      }         
   }
   
   return $iWasAction
 }

 proc ParseUserInput {strGameInfo cmdln_in} {
   upvar $strGameInfo GameInfo
   global dirs dirmap

   set iVerbNo -1
   set iNounNo 0
   set iGetAll 0
   set iret 0
   set GameInfo(TypedNoun) {}
   set GameInfo(ConditionFailed) 0   
   set GameInfo(DidGetOrDrop) 0
   set GameInfo(WasHelp) 0
   incr GameInfo(TurnCnt)
   if {!$GameInfo(LightCountDown)} {
      set GameInfo(IsDark) 1
      set GameInfo(Flag-15) 1
      return 11      
   } else {
      incr GameInfo(LightCountDown) -1
   }      
   
   foreach {verb noun} [string trim [split $cmdln_in]] {}
   set GameInfo(TypedNoun) $noun
   set verb [string toupper $verb]   
   set noun [string toupper $noun]   

   if {$verb == {QUIT} || $verb == {EXIT} || $verb == {Q}} {
      set GameInfo(Playing) 0
      if {$GameInfo(GameOverFunc) != ""} {
         eval $GameInfo(GameOverFunc)
      }
      
      return 0
   }

   set iVerbNo [GetVerbNo GameInfo $verb]

   ## Check and see if it was a direction.   
   if {$iVerbNo == 1 && $noun == ""} {
      return 2     
   }

   if {$iVerbNo == 1 || $noun == ""} {
      if {$noun != ""} {
         set possiable_dir $noun
      } else {
         set possiable_dir $verb
      }         
      
      foreach dir [string trim [split $dirs]] {
         if {$possiable_dir == $dir} {
            set dir [string range $possiable_dir 0 0]
            set iVerbNo 1
            set iNounNo [string map $dirmap $dir]
            set iret [MoveInDirection GameInfo $iNounNo]
         }         
      }
   }
   
   ## Extra hack for 'Inventory'.
   if {$verb == {I}} {
      set iVerbNo [GetVerbNo GameInfo "INV"]
   }

   ## Extra hack for get/drop all.
   if {($iVerbNo == 10 || $iVerbNo == 18) && $noun == "ALL"} {
      set iGetAll 1      
   }
   
   ## Check for unknown command, or match a noun if there was one.
   if {$iVerbNo == -1} {
      return 7
   } else {
      if {$noun != "" && !$iGetAll} {
         set iNounNo [GetNounNo GameInfo $noun]
         if {$iNounNo == -1} {
            return 8
         }
      }
   }

   ## Check for any actions to perform.   
   set iWasAction [CheckActions GameInfo $iVerbNo $iNounNo]

   if {$verb == "HELP" && !$GameInfo(ConditionFailed)} {
      set GameInfo(WasHelp) 1
      if {$GameInfo(HelpFunc) != ""} {
         eval $GameInfo(HelpFunc)
      }
   }

   ## See if it was a 'GET' or 'DROP'.   
   if {($iVerbNo == 10 || $iVerbNo == 18) && \
      !$GameInfo(DidGetOrDrop) && $GameInfo(ConditionFailed)} {
      if {$noun == "ALL"} {
         foreach item_info $GameInfo(items) {
            if {[lindex $item_info 1] != $GameInfo(CurrentRoom)} {
               continue
            }
            set item [string trim [lindex [split [lindex \
                           $item_info 0] {/}] 1]]
            set iret [GetOrDrop GameInfo [expr {$iVerbNo==10?0:1}] $item 1]
            if {!$iret} {
               set item_desc [string trim [lindex [split [lindex \
                             $item_info 0] {/}] 0]]
               lappend GameInfo(CurrentMsgs) "$item_desc: O.K."
            }               
         }            
      } else {
         set iret [GetOrDrop GameInfo [expr {$iVerbNo==10?0:1}] $noun]
      }

      ## Hackish way to get certain events to happen.
      ## Maybe not the best place for it, but....      
      CheckActions GameInfo $iVerbNo $iNounNo
   }
   
   return $iret
 }

 proc ReadAdventureFile {strGameInfo gamefile} {
   upvar $strGameInfo GameInfo
   unset -nocomplain GameInfo
   

   ## Init the game play vars.
   set GameInfo(datfile) $gamefile
   set GameInfo(Playing) 1
   set GameInfo(GameOver) 0
   set GameInfo(Continue) 0
   set GameInfo(IsDark) 0
   set GameInfo(IsDead) 0
   set GameInfo(TurnCnt) 0
   set GameInfo(param_lst) {}
   set GameInfo(param_ndx) 0
   set GameInfo(BitFlags) 0
   set GameInfo(CurrentCounter) 0
   set GameInfo(CurrentMsgs) {}
   set GameInfo(CurrentUserMsgs) {}
   set GameInfo(TypedNoun) {}
   set GameInfo(RoomNumberHold) 0
   set GameInfo(DidGetOrDrop) 0
   set GameInfo(WasHelp) 0
   set GameInfo(SaveGameFunc) {}
   set GameInfo(ClearFunc) {}
   set GameInfo(LookFunc) {}
   set GameInfo(GameOverFunc) {}   
   set GameInfo(HelpFunc) {}
   set GameInfo(MaxDisplayWidth) 80
   set GameInfo(ConditionFailed) 0
   
   ## I go a little more on the counters and flags just for the future.
   for {set iNdx 0} {$iNdx < 32} {incr iNdx} {
      set GameInfo(Counter-$iNdx) 0
   }

   ## I do the flags like this... Because I can :-).
   for {set iNdx 0} {$iNdx < 32} {incr iNdx} {
      set GameInfo(Flag-$iNdx) 0
   }

   for {set iNdx 0} {$iNdx < 32} {incr iNdx} {
      set GameInfo(RoomStack-$iNdx) 0
   }
   
   set fd [open $GameInfo(datfile) "r"]
   fconfigure $fd -buffersize 256000

   ## Read in the Game file info, and store it.   
   set filler [gets $fd]
   set GameInfo(NumberOfItems) [string trim [gets $fd]]
   set GameInfo(NumberOfActions) [string trim [gets $fd]]
   set GameInfo(NumberOfWords) [string trim [gets $fd]] 
   set GameInfo(NumberOfRooms) [string trim [gets $fd]]
   set GameInfo(MaxItemsCarry) [string trim [gets $fd]]
   set GameInfo(StartingRoom) [string trim [gets $fd]]
   set GameInfo(TotalTreasures) [string trim [gets $fd]]
   set GameInfo(WordLen) [string trim [gets $fd]]
   set GameInfo(TotalLightTime) [string trim [gets $fd]]
   set GameInfo(NumberOfMsgs) [string trim [gets $fd]]
   set GameInfo(TreasureRoom) [string trim [gets $fd]]
   set GameInfo(CurrentRoom) $GameInfo(StartingRoom)
   set GameInfo(LightCountDown) $GameInfo(TotalLightTime)
   
   set ActCnt 0
   incr GameInfo(NumberOfActions)   
   while {$ActCnt < $GameInfo(NumberOfActions)} {
      set Vocab [gets $fd]
      set Condition1 [gets $fd]; set Condition2 [gets $fd]
      set Condition3 [gets $fd]; set Condition4 [gets $fd]
      set Condition5 [gets $fd]
      set Action1 [gets $fd]; set Action2 [gets $fd]
      Clean Vocab Condition1 Condition2 Condition3 \
            Condition4 Condition5 Action1 Action2      
      lappend GameInfo(actions) [list $Vocab $Condition1 $Condition2\
                                      $Condition3 $Condition4\
                                      $Condition5 $Action1 $Action2]
      incr ActCnt                                
   }

   set WordCnt 0
   incr GameInfo(NumberOfWords)   
   while {$WordCnt < $GameInfo(NumberOfWords)} {
      set Verb [gets $fd]; set Noun [gets $fd]
      Clean Verb Noun      
      lappend GameInfo(words) [list $Verb $Noun]
      incr WordCnt                                
   }

   set RoomCnt 0
   incr GameInfo(NumberOfRooms)
   while {$RoomCnt < $GameInfo(NumberOfRooms)} {
      set Exit1 [gets $fd]; set Exit2 [gets $fd]
      set Exit3 [gets $fd]; set Exit4 [gets $fd]
      set Exit5 [gets $fd]; set Exit6 [gets $fd]
      set Desc [ReadQuotedMsg $fd -endofline]
      Clean Exit1 Exit2 Exit3 Exit4 Exit5 Exit6 Desc
      lappend GameInfo(locations) [list $Exit1 $Exit2 $Exit3\
                                        $Exit4 $Exit5 $Exit6 $Desc]
      incr RoomCnt
   }

   set MsgCnt 0
   incr GameInfo(NumberOfMsgs)   
   while {$MsgCnt < $GameInfo(NumberOfMsgs)} {
      set msg [ReadQuotedMsg $fd -endofline]
      Clean msg
      lappend GameInfo(messages) $msg
      incr MsgCnt                                
   }

   set ItemCnt 0
   incr GameInfo(NumberOfItems)
   while {$ItemCnt < $GameInfo(NumberOfItems)} {
      set Item [ReadQuotedMsg $fd]
      set Location [gets $fd]
      Clean Item Location
      lappend GameInfo(items) [list $Item $Location $Location]
      incr ItemCnt                                
   }

   set ActCnt 0
   while {$ActCnt < $GameInfo(NumberOfActions)} {
      set ActionCmd [ReadQuotedMsg $fd -endofline]
      Clean ActionCmd
      lappend GameInfo(actioncmds) [string trim $ActionCmd "\n\r"]
      incr ActCnt                                
   }   
 }
