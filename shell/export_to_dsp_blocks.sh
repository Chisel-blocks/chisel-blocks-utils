#!/bin/sh
# Extract files from existing git repository and push them to master branch
# of git@bwrcrepo.eecs.berkeley.edu:dsp-blocks/chisel/${MODULE}.git
#
# Initially written by Marko Kosunen, marko.kosunen@aalto.fi, 12.12.2018
#
# [TODO]: Split to two scripts, generate fucntion with input arguments
# And caller script example,not a big deal, just donot have tome to do it now.
#


# These are to be included ALWAYS. Modify accordint to your needs.
# README.md, build.sbt, init_submodules.sh and configure will be overwritten
# if they do exist. Include them in files if you want to be able to revert.
FILES="README.md ./project ./build.sbt ./configure ./.gitignore ./init_submodules.sh"
#

## Then the actual modules
MODULE="halfband_BW_01125_N_6"

# These are the directories in src/main/scala to be retained
MODULELIST="$MODULE halfband_BW_0225_N_8 halfband_BW_045_N_40"
MODULES=$(printf "./src/main/scala/%s/\n" $MODULELIST | xargs ) 
PRESERVE="$FILES $MODULES"
SOURCEREPO="git@bwrcrepo.eecs.berkeley.edu:fader2/TheSDK_generators.git"
TARGETREMOTE="git@bwrcrepo.eecs.berkeley.edu:dsp-blocks/chisel/${MODULE}.git"

extract_git_module.sh -m "$MODULE" -p "$PRESERVE" -r "$SOURCEREPO" \
    -R "${TARGETREMOTE}" -s "fader2_2019" 


# Repeat if needed.
#MODULE="halfband_interpolator"
#MODULELIST="$MODULE halfband_BW_01125_N_6 halfband_BW_0225_N_8 halfband_BW_045_N_40"
#MODULES=$(printf "./src/main/scala/%s/\n" $MODULELIST | xargs ) 
#PRESERVE="$FILES $MODULES"
#extract_git_module -m "$MODULE" -p "$PRESERVE" -r "$SOURCEREPO" -R "${TARGETREMOTE}" -s "fader2_2019" 


#MODULE="cic3"
#MODULELIST="$MODULE"
#MODULES=$(printf "./src/main/scala/%s/\n" $MODULELIST | xargs ) 
#PRESERVE="$FILES $MODULES"
#extract_git_module -m "$MODULE" -p "$PRESERVE" -r "$SOURCEREPO" -R "${TARGETREMOTE}" -s "fader2_2019" 
#
#MODULE="cic3_interpolator"
#MODULELIST="$MODULE"
#MODULES=$(printf "./src/main/scala/%s/\n" $MODULELIST | xargs ) 
#PRESERVE="$FILES $MODULES"
#generate "$MODULE" "$PRESERVE" $PWD
#
#MODULE="clkdiv_n_2_4_8"
#MODULELIST="$MODULE"
#MODULES=$(printf "./src/main/scala/%s/\n" $MODULELIST | xargs ) 
#PRESERVE="$FILES $MODULES"
#generate "$MODULE" "$PRESERVE" $PWD


exit 0

