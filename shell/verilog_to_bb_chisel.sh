#!/usr/bin/env bash
# Read in a verilog file and create a Chisel package with inline verilog Blackbox 
#
# Initially written by Marko Kosunen, marko.kosunen@aalto.fi, 26.10.2019

help_f()
{
cat << EOF
 verilog_to_bb_chisel  Release 1.0 (26.110.2019)

 Written by Marko Pikkis Kosunen marko.kosunen@aalto.fi

 SYNOPSIS
   verilog_to_bb_chisel [VERILOGFILE] [MODULENAME]
 DESCRIPTION
   Fromn [VERILOGFILE] reads in the definition of [MODULENAME] and outputs Chisel package with inline verilog definition to std out.
   If [MODULENAME] is not given, uses the filename without the suffix as modulename.

   OBS: supports only integer buswidthds. No parameters.
   
 OPTIONS

   -h
       Show this help.
EOF

}


while getopts h opt
do
  case "$opt" in
    h) help_f; exit 0;;
    \?) help_f; exit 0;;
  esac
done

if [ ! -f $1 ]; then
    echo "Input file does not exists"
    help_f
    exit 1
fi
INPUTCOREMODULEFILE=$1
FILENAME=$(basename ${INPUTCOREMODULEFILE})
TMPMODULEFILE="/tmp/$$_${FILENAME}"
TMPIOFILE="/tmp/$$_IO_${FILENAME}"

if [ -z "$2" ]; then
    NAME=${FILENAME%.*}
else 
    NAME="$2"
fi

MODULE=$(sed -n "s/\(^\s*module\s*\)\(${NAME}\)\(\s*(\)/\2/p" ${INPUTCOREMODULEFILE})
if [ -z ${MODULE} ]; then
    echo "ERROR: Module ${NAME} not found."
    echo "You have to give correct module name"
    help_f
    exit 1
fi



# Parse se
sed -n "/^\s*module\s*${NAME}/,/endmodule/p" $INPUTCOREMODULEFILE \
    > ${TMPMODULEFILE}
sed -n "/^\s*input\|output\s*/p" $TMPMODULEFILE \
    | sed -e 's/^\s*//g' -e 's/\s\s*/ /g' -e 's/\s*,$//g' > ${TMPIOFILE}


#MODULE=$(sed -n "s/\(^\s*module\s*\)\(${NAME}\)\(\s*(\)/\2/p" ${TMPMODULEFILE})
#if [ -z ${MODULE} ]; then
#    echo "Module ${NAME} not found.\n You have to gove the module name"
#
##fi


cat << EOF
// Dsp-block ${MODULE} 
// Description here
// Inititally written by chisel-block-utils verilog_to_bb_chisel.sh, $(date +%Y%m%d)
package ${MODULE}

import chisel3._
import chisel3.experimental._
import chisel3.util._
import dsptools.{DspTester, DspTesterOptionsManager, DspTesterOptions}
class ${MODULE} extends BlackBox() with HasBlackBoxInline {
        val io = IO(new Bundle{
$( while read -r line; do
TYPE=$(echo $line | sed -n 's/\(^input\|output\)\(.*$\)/\1/p')
NAME=$(echo $line | sed -n 's/\(^.*\s\)\(.*$\)/\2/p')
LLIM=$(echo $line | sed -n 's/\(^.*\[\)\([0-9]*\)\(.*\)/\2/p')
RLIM=$(echo $line | sed -n 's/\(^.*\[.*:\)\([0-9]*\)\(.*\)/\2/p')
if [ ! -z ${LLIM} ]; then
    if [ ${LLIM} -ge ${RLIM} ]; then
        WIDTH=$((${LLIM}-${RLIM}+1))
        VALTYPE="UInt"
    else
        WIDTH=$((${RLIM}-${LLIM}+1))
        VALTYPE="Bits"
    fi
else
    WIDTH="1"
    VALTYPE="UInt"
fi
echo "            val $NAME = $(tr '[:lower:]' '[:upper:]' <<< ${TYPE:0:1})${TYPE:1}(${VALTYPE}(${WIDTH}.W))"
done < ${TMPIOFILE}
)
        }
    )
    setInline("${FILENAME}",
        s"""
$(cat ${TMPMODULEFILE} | sed 's/^/        |/g')
        """.stripMargin)
}

EOF

rm -f ${TMPMODULEFILE}
rm -f ${TMPIOFILE}
exit 0



