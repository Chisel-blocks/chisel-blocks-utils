#!/usr/bin/env bash
# Extract files from existing git repository and push them to master branch
# of git@bwrcrepo.eecs.berkeley.edu:dsp-blocks/chisel/${MODULE}.git
#
# Initially written by Marko Kosunen, marko.kosunen@aalto.fi, 12.12.2018

help_f()
{
cat << EOF
 init_submodule  Release 1.1 (17.12.2020)
 Initializes a self-contained dsp-block module
 with a minimum working example
 Written by Marko Pikkis Kosunen marko.kosunen@aalto.fi

 SYNOPSIS
   init_submodule [OPTIONS]
 DESCRIPTION
   Filter given files to a new git branch

 OPTIONS

   -m
       Module [string]: The name of the module directory to create.

   -P  Push. Default: do not push.

   -R
       Remote git repository URL in https or in ssh format
       Default:
       "git@your.domain:<your_repo>/[MODULE].git"

   -w
       Working directory. The module will be created as a subdirectory
       of the working directory.
       Default: pwd

   -h
       Show this help.
EOF

}

SCRIPTPATH=$(cd `dirname $0` && pwd )

MODULE=""
TARGETREMOTE=""

PUSHING="0"
TARGETBRANCH="master"
WD=$(pwd)

CURRENTDIR=$(pwd)

SED="sed"

#Default versions
SCALA="2.13.8"
CHISEL="3.5.4"
DSPTOOLS="1.5.6"
CHISELTEST="0.5.6"
SBT="1.9.9"

BREEZE="2.0"
PUSH="0"
while getopts m:PR:t:w:h opt
do
  case "$opt" in
    m) MODULE="${OPTARG}";;
    P) PUSH="1";;
    R) TARGETREMOTE="${OPTARG}";;
    t) TARGETBRANCH="${OPTARG}";;
    w) WD="${OPTARG}";;
    h) help_f; exit 0;;
    \?) help_f; exit 0;;
  esac
done

OSNAME=$(uname)
if [ "$OSNAME" = "Darwin" ]; then
    SED="gsed"
    if ! type "${SED}" &> /dev/null; then
        echo "Please install GNU sed to run to MacOS."
        exit 1
    fi
else
    echo "Assuming that sed is GNU sed for operating system ${OSNAME}."
fi

if [ -z "$MODULE" ]; then
    echo "Module name not given"
    help_f
    exit 1
fi

PACKAGENAME=$(echo $MODULE | awk '{print tolower($0)}')

if [ -z "$TARGETREMOTE" ]; then
    TARGETREMOTE="git@github.com:Chisel-blocks/${MODULE}.git"
    echo "Using default target remote repository "
    echo "${TARGETREMOTE}"
fi

if [ -d "${WD}/${MODULE}" ]; then
    echo "Directory ${WD}/${MODULE} exists, remove it first"
    exit 1
fi

cd $WD
mkdir ./${MODULE}
cd ./${MODULE}
git init

git remote add origin "${TARGETREMOTE}"
if [ ! "master" == "${TARGETBRANCH}" ]; then
    git branch  ${TARGETBRANCH}
    git checkout ${TARGETBRANCH}
    git branch -D master
fi

#Generate unified build.sbt if build.sbt is not preserved
echo "Writing build.sbt"

cat << EOF > ./build.sbt
import scala.sys.process._
// OBS: sbt._ has also process. Importing scala.sys.process
// and explicitly using it ensures the correct operation

ThisBuild / scalaVersion := "$SCALA"
ThisBuild / version      := scala.sys.process.Process("git rev-parse --short HEAD").!!.mkString.replaceAll("\\\s", "")+"-SNAPSHOT"
ThisBuild / organization := "Chisel-blocks"

// Last two numbers must be the same
val chiselVersion = "$CHISEL"
val chiselTestVersion = "$CHISELTEST"

val breezeVersion = "$BREEZE"
val dspVersion = "$DSPTOOLS"

lazy val root = (project in file("."))
  .settings(
    name := "$PACKAGENAME",
    libraryDependencies ++= Seq(
      "edu.berkeley.cs" %% "chisel3" % chiselVersion,
      "edu.berkeley.cs" %% "chiseltest" % chiselTestVersion,
      "edu.berkeley.cs" %% "dsptools" % dspVersion,
      "org.scalanlp" %% "breeze" % breezeVersion,
      "org.scalanlp" %% "breeze-natives" % breezeVersion,
      "org.scalanlp" %% "breeze-viz" % breezeVersion
    ),
    scalacOptions ++= Seq(
      "-language:reflectiveCalls",
      "-deprecation",
      "-feature",
      "-Xcheckinit",
      "-P:chiselplugin:genBundleElements",
    ),
    addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full),
  )

// Parse the version of a submodle from the git submodule status
// for those modules not version controlled by Maven or equivalent
def gitSubmoduleHashSnapshotVersion(submod: String): String = {
    val shellcommand =  "git submodule status | grep %s | awk '{print substr(\$1,0,7)}'".format(submod)
    scala.sys.process.Process(Seq("/bin/sh", "-c", shellcommand )).!!.mkString.replaceAll("\\\s", "")+"-SNAPSHOT"
}

// Put your git-version controlled snapshots here
//libraryDependencies += "Chisel-blocks" %% "someblock" % gitSubmoduleHashSnapshotVersion("someblock")


EOF
git add ./build.sbt

echo "Generating configure file template"
cp ${SCRIPTPATH}/configure_template ./configure
${SED} -i "s/TEMPLATEMODULENAME/${MODULE}/" ./configure
${SED} -i "s/TEMPLATEPACKAGENAME/${PACKAGENAME}/" ./configure
git add ./configure

echo "Generating init_submodules.sh template"
cat <<EOF > init_submodules.sh
#!/usr/bin/env bash
#Init submodules in this dir, if any
DIR="\$( cd "\$( dirname \$0 )" && pwd )"
git submodule sync

#Recursively init submodules
#SUBMODULES="\\
#    f2_dsp \\
#    f2_cm_serdes_lane \\
#    "
#for module in \$SUBMODULES; do
#    git submodule update --init \${module}
#    cd \${DIR}/\${module}
#    if [ -f "./init_submodules.sh" ]; then
#        ./init_submodules.sh
#    fi
#    sbt publishLocal
#    cd \${DIR}
#done


exit 0
EOF
chmod 755 ./init_submodules.sh
git add ./init_submodules.sh


echo "Generating project/build.properties for Scala-version<->sbt compatibility"
mkdir ./project && echo "sbt.version=$SBT" > ./project/build.properties && git add ./project/build.properties

echo "Writing README.md"
cat << EOF > ./README.md
# Description of scala module version control principle with git
Generated by init_module.sh of Chisel-blocs-utils, 
https://github.com/Chisel-blocks/chisel-blocks-utils , $(date +'%Y%m%d')

## Principle of operation:
All modules version controlled with this method can be used effortlessly
and recursively as git submodules inside similar modules

The method of use is _always_ the same
1. \`./init_submodules.sh\` (if any)
2. Publish locally the submodules you want to use.
    (embedded to init_submodules.sh)
3. \`./configure && make\`

## Version strings:
In build.sbt, the version of the current module is of from
"module-<commit-hash>-SNAPHOT"
It is created with line:
\`version := scala.sys.process.Process("git rev-parse --short HEAD").!!.mkString.replaceAll("\\\\s", "")+"-SNAPSHOT"\`

Dependencies on similar submodules are defined with the
function gitSubmoduleHashSnapshotVersion
and with the dependency definitions
\`libraryDependencies += "edu.berkeley.cs" %% "hbwif" % gitSubmoduleHashSnapshotVersion(modulename")\`

This dependency is satisfied only if there is a locally published (sbt publishLocal) submodule
with the submodule hash of the current git submodule.

**OBS1**: Every time a submodule is updated, it must be published locally.
See init_submodules.sh for reference. Make it recursive if needed.

**OBS2**: If submodules are edited and committed, the changes are visible
at the top level ONLY if ALL the entire hierarchy of submodules from bottom
module to top are git-added, git-committed and git-pushed.
This is how submodules normally operate.

## Testing
Tests are located under \`src/test/scala/$PACKAGENAME\`. You can run them with \`make test_${PACKAGENAME}\`.

## Add your module readme here
Lorem ipsum...

EOF
git add ./README.md

mkdir -p ./src/main/scala/${PACKAGENAME}
cat << EOF > ./src/main/scala/${PACKAGENAME}/${MODULE}.scala

// Chisel module ${MODULE}
// Description here
// Inititally written by chisel-blocks-utils initmodule.sh, $(date +'%Y-%m-%d')
package ${PACKAGENAME}

import chisel3._
import chisel3.util._
import chisel3.experimental._
import chisel3.stage.{ChiselStage, ChiselGeneratorAnnotation}
import dsptools.{DspTester, DspTesterOptionsManager, DspTesterOptions}
import dsptools.numbers._
import breeze.math.Complex

/** IO definitions for ${MODULE} */
class ${MODULE}IO[T <:Data](proto: T,n: Int)
   extends Bundle {
        val A       = Input(Vec(n,proto))
        val B       = Output(Vec(n,proto))
}

/** Module definition for ${MODULE}
  * @param proto type information
  * @param n number of elements in register
  */
class ${MODULE}[T <:Data] (proto: T,n: Int) extends Module {
    val io = IO(new ${MODULE}IO( proto=proto, n=n))
    val register=RegInit(VecInit(Seq.fill(n)(0.U.asTypeOf(proto.cloneType))))
    register:=io.A
    io.B:=register
}

/** This gives you verilog */
object ${MODULE} extends App {
    val annos = Seq(ChiselGeneratorAnnotation(() => new ${MODULE}(
        proto=DspComplex(UInt(16.W),UInt(16.W)), n=8
    )))
    (new ChiselStage).execute(args, annos)
}

EOF

git add  ./src/main/scala/${PACKAGENAME}/${MODULE}.scala

mkdir -p ./src/test/scala/${PACKAGENAME}
cat << EOF > ./src/test/scala/${PACKAGENAME}/${MODULE}Spec.scala
package $PACKAGENAME

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import dsptools.{DspTester, DspTesterOptionsManager, DspTesterOptions}
import dsptools.numbers._

class ${PACKAGENAME}Spec extends AnyFlatSpec with ChiselScalatestTester {

  it should "propagate values in the register" in {
    test(new ${PACKAGENAME}(proto = DspComplex(UInt(16.W), UInt(16.W)), n = 8)) { dut =>
      dut.io.A(0).real poke 5
      dut.io.A(0).imag poke 102 
      dut.clock.step(1)
      dut.io.B(0).real expect 5
      dut.io.B(0).imag expect 102
    }
  }
}
EOF

git add  ./src/test/scala/${PACKAGENAME}/${MODULE}Spec.scala


cat << EOF > ./src/main/scala/${MODULE}/package.scala
/** This comment generates package-wide documentation using scaladoc.
  * @see See [[https://docs.scala-lang.org/overviews/scaladoc/for-library-authors.html this page]]
  * for more information about scaladoc comments.
  * The comment generating this documentation can be found in the file \`src/main/scala/${MODULE}/package.scala\`.
  */
package object ${PACKAGENAME} {}
EOF
git add  ./src/main/scala/${MODULE}/package.scala

git commit -m"Init git-versioned submodule ${MODULE}"

if [ "$PUSH" == "1" ]; then
    echo "Pushing to ${TARGETREMOTE}, branch ${TARGETBRANCH}"
    git push origin --set-upstream ${TARGETBRANCH}
    cd ${CURRENTDIR}
else

cat << EOF

Everything set up for you to push.
If satisfied with the result, run

cd ${WD}/${MODULE} && git push origin --set-upstream ${TARGETBRANCH}

Or re-run with option -P

EOF

cd ${CURRENTDIR}
fi

exit 0
