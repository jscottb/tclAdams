##!/bin/sh
## \
exec wish "$0" "$@"
 
##############################################################################
## TkAdams.tcl
##
## Tk driver to test Scott Adams Adventure game engine written in TCL.
##
## Author: Scott Beasley (scottbeasley@gmail.com)
## Feel free to *itch, or send patches to the above address :-)
##
##############################################################################

# Where is the engine?
if {$tcl_platform(platform) == "unix" && [file type $argv0] == "link"} {
	if {[catch "file readlink $argv0" link_file]} {
		puts "error reading file link:\"$argv0\": $link_file"
		exit 1
	}
	# Absolute or relative path?
	if {[string index $link_file 0] == "/"} {
		set engine_file [file join [file dirname $link_file] "TclAdamsEng.tcl"]
	} else {
		set engine_file [file join [file dirname $argv0] [file dirname $link_file] "TclAdamsEng.tcl"]
	}
} else {
	set engine_file [file join [file dirname [info script ]] "TclAdamsEng.tcl"]
}
source [file normalize $engine_file]


package require Tk
 
 proc LoadAdventFile {{GameFile {}}} {
   global GameInfo   

   puts "LoadAdventFile:"
   set GameInfo(MaxDisplayWidth) 85   
   if {$GameFile == ""} {
      set types {
          {{Adams Games Files}   {.dat}  TEXT}
          {{All Files}         *             }
      }
      
      set filename [tk_getOpenFile -filetypes $types]

      if {$filename != ""} {
         set GameFile $filename
      }
   }

   if {$GameFile != ""} {
   
        puts "    GameFile=$GameFile" ; update
      ReadAdventureFile GameInfo $GameFile
      CheckActions GameInfo 0 0
      MakeAWish 1
      focus .fr_one_wish.e_command   
   }
 }
 
 proc UserError {errormsg} {
   .fr_one.txt_action_msgs configure -state normal   
   .fr_one.txt_action_msgs delete 1.0 end
   .fr_one.txt_action_msgs insert 1.0 $errormsg
   .fr_one.txt_action_msgs configure -state disabled
 }

 proc DescriptPuts {line} {
   .fr_one.txt_room_and_item_info configure -state normal
   .fr_one.txt_room_and_item_info insert end $line
   .fr_one.txt_room_and_item_info configure -state disabled
 }

 proc ActionPuts {line} {
   set line [string trimright $line]
   .fr_one.txt_action_msgs configure -state normal   
   .fr_one.txt_action_msgs insert end $line
   .fr_one.txt_action_msgs insert end "\n"
   .fr_one.txt_action_msgs configure -state disabled
 }

 proc SetDirButtonsAllowed {} {
   global GameInfo dirnames

   foreach dir $dirnames {
      ".fr_two.b_[string tolower $dir]" configure -state disabled      
   }

   if {[string trim $GameInfo(RoomExits)] != ""} {
      foreach dir [split $GameInfo(RoomExits)] {
         if {[string trim $dir] != ""} {
            ".fr_two.b_[string tolower $dir]" configure -state active
         }            
      }
   }      
 }

 proc MakeAWish {{noparse 0}} {
   global UsersWish GameInfo
   
   if {$noparse} {
      set iRet 0      
   } else {
      set GameInfo(CurrentMsgs) {}
      set UsersWish [string trim $UsersWish]
      if {$UsersWish == ""} {
         return         
      }
      
      set iRet [ParseUserInput GameInfo $UsersWish]
   }
   
   set UsersWish {}
   Look GameInfo
   
   .fr_one.txt_action_msgs configure -state normal
   .fr_one.txt_room_and_item_info configure -state normal
   .fr_one.txt_action_msgs delete 1.0 end
   .fr_one.txt_room_and_item_info delete 1.0 end
   .fr_one.txt_action_msgs configure -state disabled
   .fr_one.txt_room_and_item_info configure -state disabled

   switch $iRet {
      2 {
         UserError "You must supply a direction.\n"
      }
   
      3 {
         UserError "You can't go in that direction.\n"
      }
 
      5 {
         UserError "It's beyond your power to do that!\n"
      }

      6 {
         UserError "You are carring that already...\n"
      }
      
      7 {
         UserError "You speak unknown words!\n"
      }
      
      8 {
         UserError "Don't know what that is?\n"
      }
   
      9 {
         UserError "You are not carring that...\n"
      }

      10 {
         UserError "You are carring to much!\n"
      }

      11 {
         UserError "It's too dark to do it!\n"
      }
   }

   set iFirstActMsg 0   
   foreach msg $GameInfo(CurrentMsgs) {
      if {!$iFirstActMsg} {
         set msg [string trimleft $msg "\n"]
         set iFirstActMsg 1   
      }
      
      set msg [string trimright $msg "\n"]
      if {$msg != ""} {         
         ActionPuts "$msg\n"
      }            
   }

   DescriptPuts "You are in a $GameInfo(RoomText)\n"
   set iLineLen 0
   set iDivder 0
   if {[llength $GameInfo(ItemsInRoom)]} {   
      DescriptPuts "You see: "
      foreach item $GameInfo(ItemsInRoom) {
         if {$iDivder} {
            DescriptPuts ". "
         } else {
            set iDivder 1         
         }         
       
         if {[expr {$iLineLen+[string length $item]+2}] >= \
             $GameInfo(MaxDisplayWidth)} {
            DescriptPuts "\n"
            set iLineLen 0
         }
        
         incr iLineLen [expr {[string length $item]+2}]
         DescriptPuts $item
      }
   }
   
   DescriptPuts "\nObvious exits: $GameInfo(RoomExits)\n"
   SetDirButtonsAllowed   
 }

 proc DoDirection {dir} {
   global UsersWish
  
   set UsersWish $dir
   MakeAWish   
 }

 ## TkAdams Driver.
   # Build the window.
   wm title . {tkAdams}
   wm resizable . 0 0
   wm deiconify .

   frame .fr_one -borderwidth 0 -height 75 -relief groove -width 340 
   text .fr_one.txt_action_msgs -height 10 -state disabled
   text .fr_one.txt_room_and_item_info -height 10 -state disabled
   frame .fr_one_wish -borderwidth 0 -height 75 -relief groove -width 340 
   label .fr_one_wish.l_your_wish -borderwidth 1 -relief flat \
         -text {What is your wish?} -width 18 
   entry .fr_one_wish.e_command -textvariable UsersWish -width 25

   grid .fr_one -in . -column 0 -row 3 -columnspan 1 -rowspan 1 
   grid .fr_one.txt_action_msgs -in .fr_one -column 0 -row 2 \
        -columnspan 1 -rowspan 1 
   grid .fr_one.txt_room_and_item_info -in .fr_one -column 0 -row 3 \
        -columnspan 1 -rowspan 1 
   grid .fr_one_wish -in .fr_one -column 0 -row 4 -columnspan 1 -rowspan 1 
   grid .fr_one_wish.l_your_wish -in .fr_one_wish -column 0 -row 0 \
        -columnspan 1 -rowspan 1 
   grid .fr_one_wish.e_command -in .fr_one_wish -column 1 -row 0 \
        -columnspan 1 -rowspan 1 

   frame .fr_two -borderwidth 0 -height 75 -relief groove -width 125
   grid .fr_two -in . -column 0 -row 4 -columnspan 1 -rowspan 1
   set colndx 1
   foreach dir $dirnames {
      button ".fr_two.b_[string tolower $dir]" -text $dir \
             -command "DoDirection $dir" -width 8 -state disabled
      grid ".fr_two.b_[string tolower $dir]" -in .fr_two -column $colndx \
           -row 1 -columnspan 1 -rowspan 1
      incr colndx         
   }      

   frame .fr_three -borderwidth 0 -height 75 -relief groove -width 200
   grid .fr_three -in . -column 0 -row 5 -columnspan 1 -rowspan 1
   button .fr_three.b_quit -text "Quit" \
          -command "exit" -width 8 -state normal
   button .fr_three.b_save -text "Save Game" -padx 10 \
          -command "SaveGame" -width 8 -state normal
   button .fr_three.b_load_game -text "Load Game" -padx 10 \
          -command "SaveGame" -width 8 -state normal
   button .fr_three.b_load -text "Load New Adventure" -padx 40 \
          -command "LoadAdventFile" -width 8 -state normal
   grid .fr_three.b_quit -in .fr_three -column 0 \
        -row 5 -columnspan 1 -rowspan 1
   grid .fr_three.b_save -in .fr_three -column 2 \
        -row 5 -columnspan 1 -rowspan 1 -sticky nsew
   grid .fr_three.b_load_game -in .fr_three -column 3 \
        -row 5 -columnspan 1 -rowspan 1 -sticky nsew
   grid .fr_three.b_load -in .fr_three -column 4 \
        -row 5 -columnspan 2 -rowspan 1 -sticky nsew

   bind .fr_one_wish.e_command <Key-Return> "MakeAWish"

   set GameFile {}      
   if {$argc >= 1} {
      set GameFile [lindex $argv 0]      
   }
   
   LoadAdventFile $GameFile   
   
 ## end TkAdams
