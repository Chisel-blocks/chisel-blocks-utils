#!/usr/bin/env bash
# This is a collection of functions to extract and manipulate module 
# information from a verilog file
# These, I think, are to be mainly used from scripts, so I make first
# a collection of functions. Later, command line wrappers can be written,
# if required.
# Initially written by Marko Kosunen,Marko Kosunen@aalto.fi 20191102


extract_module() {
COREVERILOG="$1"
if [ ! -z "$2" ]; then
    COREMODULE="$2"
else
    COREMODULE=`basename ${COREVERILOG} .v`
fi
# Extract everything between module <name> and );
sed -n "/module\s*${COREMODULE}/,/);/p" "${COREVERILOG}"
return 0
}

extract_io_db() {
COREVERILOG="$1"
if [ ! -z "$2" ]; then
    COREMODULE="$2"
else
    COREMODULE=`basename ${COREVERILOG} .v`
fi

# Extract everything between module <name> and );
# Take all line containing input or output
# Delete spaces from beginning of the line
# Delete commas and double spaces
# Remove comments and spaces from the end of the line
# To lines NOT having [ after input or output, add [0:0] 
# Remove []
# Remove :
sed -n "/module\s*${COREMODULE}/,/);/p" "${COREVERILOG}" \
    | sed -n '/^\s*input\|^\s*output/p' \
    | sed 's/^\s*//g' \
    | sed 's/,//g' | sed -n 's/\s\s*/ /p' \
    | sed 's/\s\/\/.*$//g' | sed 's/\s*$//g' \
    | sed '/^input \[\|output \[/! s/\s/ [0:0] /' | sed -e 's/\[//' -e 's/\]//'\
    | sed 's/:/ /g'
return 0
}

blast_io_db_buses() {
DBFILE="$1"
awk '{dir=$1; ll=$2; rl=$3; name=$4; 
      if(ll==0 && rl==0){ 
          print dir " " ll " " rl " "  name
      }
      else if( ll > rl){
          for( i=ll; i>=rl; i--){
              print dir " " 0 " " 0 " "  name "[" i "]"
          }
      }
      else if( rl > ll){
          for( i=ll; i<=rl; i++){
              print dir " " 0 " " 0 " "  name "[" i "]"
          }
      }
  }
' ${DBFILE}
return 0
}

create_wires() {
DBFILE="$1"
PREFIX="$2"
awk -v prefix=${PREFIX} '{dir=$1; ll=$2; rl=$3; name=$4; 
      if(ll==0 && rl==0){ 
          print "wire " prefix name ";"
      }
      else {
              print "wire [" ll ":" rl "] "  prefix name ";"
      }
  }
' ${DBFILE}
return 0
}

create_ios() {
DBFILE="$1"
PREFIX="$2"
awk -v prefix=${PREFIX} '{dir=$1; ll=$2; rl=$3; name=$4; 
      if(ll==0 && rl==0){ 
          print "    " dir " " name ","
      }
      else {
              print "    " dir " [" ll ":" rl "] "  name ","
      }
  }
' ${DBFILE}
return 0
}



