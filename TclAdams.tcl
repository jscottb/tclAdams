##!/bin/sh
## \
exec tclsh "$0" "$@"

##############################################################################
## TclAdams.tcl
##
## Txt Driver to test Scott Adams Adventure game engine written in TCL.
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

## Test it all out with a puny little driver.
set GameInfo {}

if {$argc < 1} {
    puts "We need a game file to play!\nUsage:\
        TclAdams gamedatfile"
    exit 1           
} else {
    set GameFile [lindex $argv 0]      
}      

ReadAdventureFile GameInfo $GameFile
fconfigure stdout -buffering none

CheckActions GameInfo 0 0

while {$GameInfo(Playing)} {
    puts "*******************************************"
    Look GameInfo
    foreach msg $GameInfo(CurrentMsgs) {
        set msg [string trimright $msg "\n"]
        if {$msg != ""} {         
        puts $msg
        }            
    }

    puts "\nLocation:\n$GameInfo(RoomText)"
    set iLineLen 0
    set iDivder 0
    if {[llength $GameInfo(ItemsInRoom)]} {   
        puts -nonewline "You see: "
        foreach item $GameInfo(ItemsInRoom) {
        if {$iDivder} {
            puts -nonewline " - "   
        } else {
            set iDivder 1         
        }         
    
        if {[expr {$iLineLen+[string length $item]+3}] >= 70} {
            puts ""
            set iLineLen 0
        }
    
        incr iLineLen [expr {[string length $item]+3}]
        puts -nonewline $item
        }
    }

    puts "\nObvious exits: $GameInfo(RoomExits)\n"

    while 1 {
        puts -nonewline "What do you want to do? "         
        set cmd_ln [string trim [gets stdin]]
        puts {}
        if {$cmd_ln != ""} {
        break      
        }      
        puts "Pardon?\n"
    }

    set GameInfo(CurrentMsgs) {}
    if {$cmd_ln == ""} {
        continue      
    }

    set iRet [ParseUserInput GameInfo $cmd_ln]

    switch $iRet {
        2 {
        puts "You must supply a direction.\n"
        }

        3 {
        puts "You can't go in that direction.\n"
        }

        5 {
        puts "It's beyond your power to do that!\n"
        }

        6 {
        puts "You are carring that already...\n"
        }
    
        7 {
        puts "You speak unknown words!\n"
        }
    
        8 {
        puts "Don't know what that is?\n"
        }

        9 {
        puts "You are not carring that...\n"
        }

        10 {
        puts "You are carring to much!\n"
        }

        11 {
        puts "It's too dark to do it!\n"
        }
    }
}


