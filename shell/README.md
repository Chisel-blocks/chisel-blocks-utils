##Example bash script of how to do extraction from existing project 

MODULE="f2_interpolator"
FILES="README.md ./project ./build.sbt ./configure ./.gitignore ./init_submodules.sh"

# These are the directories in src/main/scala to be retained
MODULELIST="$MODULE"
MODULES=$(printf "./src/main/scala/%s/\n" $MODULELIST | xargs ) 
PRESERVE="$FILES $MODULES"

SOURCEREPO="git@bwrcrepo.eecs.berkeley.edu-foobar:fader2/TheSDK_generators.git"
TARGETREMOTE="git@bwrcrepo.eecs.berkeley.edu-foobar:dsp-blocks/chisel/${MODULE}.git"
./dsp-block-helpers/shell/extract_git_module.sh -m"${MODULE}" -p "${PRESERVE}" -r "${SOURCEREPO}" -R "${TARGETREMOTE}" -s "fader2_2019"



