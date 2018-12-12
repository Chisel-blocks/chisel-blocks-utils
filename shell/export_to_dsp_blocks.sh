#!/bin/sh
# Extract files from existing git repository and push them to master branch
# of git@bwrcrepo.eecs.berkeley.edu:dsp-blocks/chisel/${MODULE}.git
#
# Initially written by Marko Kosunen, marko.kosunen@aalto.fi, 12.12.2018
#
# [TODO]: Split to two scripts, generate fucntion with input arguments
# And caller script example,not a big deal, just donot have tome to do it now.
#

#Generate function
generate(){
MODULE="$1"
PRESERVE="$2"
WD="$3"
cd $WD
rm -rf ./$MODULE

#PUT YOUR REPO HERE
# [TODO], make this as an argument
#git clone git@bwrcrepo.eecs.berkeley.edu:fader2/TheSDK_generators.git ./${MODULE}

cd ./${MODULE}

# YOUR BRANCHES HERE
# [TODO]: make this an argument
#git checkout fader2_2019
#git pull origin fader2_2019

ALLFILES=$(git ls-files)
ALLFILES=$(printf "./%s\n" $ALLFILES | xargs)

for module in $PRESERVE; do
    ALLFILES="$(printf "%s\n" $ALLFILES |  grep -v "$module" | xargs)"
done
REMOVE="$ALLFILES"
echo $REMOVE


git filter-branch --index-filter "git rm -r --cached --ignore-unmatch $REMOVE" --prune-empty

git remote rm origin
git branch -D master
git remote add origin git@bwrcrepo.eecs.berkeley.edu:dsp-blocks/chisel/${MODULE}.git
git branch  master
git checkout master 
git branch -d fader2_2019 
    
cat << EOF > ./build.sbt
import scala.sys.process._
// OBS: sbt._ has also process. Importing scala.sys.process 
// and explicitly using it ensures the correct operation

organization := "edu.berkeley.cs"

name := "$MODULE"

version := scala.sys.process.Process("git rev-parse --short HEAD").!!.mkString.replaceAll("\\\\s", "")+"-SNAPSHOT"

scalaVersion := "2.11.11"

// [TODO] what are these needed for? remove if obsolete
def scalacOptionsVersion(scalaVersion: String): Seq[String] = {
  Seq() ++ {
    // If we're building with Scala > 2.11, enable the compile option
    //  switch to support our anonymous Bundle definitions:
    //  https://github.com/scala/bug/issues/10047
    CrossVersion.partialVersion(scalaVersion) match {
      case Some((2, scalaMajor: Int)) if scalaMajor < 12 => Seq()
      case _ => Seq("-Xsource:2.11")
    }
  }
}

def javacOptionsVersion(scalaVersion: String): Seq[String] = {
  Seq() ++ {
    // Scala 2.12 requires Java 8. We continue to generate
    //  Java 7 compatible code for Scala 2.11
    //  for compatibility with old clients.
    CrossVersion.partialVersion(scalaVersion) match {
      case Some((2, scalaMajor: Int)) if scalaMajor < 12 =>
        Seq("-source", "1.7", "-target", "1.7")
      case _ =>
        Seq("-source", "1.8", "-target", "1.8")
    }
  }
}

// Parse the version of a submodle from the git submodule status
// for those modules not version controlled by Maven or equivalent
def gitSubmoduleHashSnapshotVersion(submod: String): String = {
    val shellcommand =  "git submodule status | grep %s | awk '{print substr(\$1,0,7)}'".format(submod)
    scala.sys.process.Process(Seq("/bin/sh", "-c", shellcommand )).!!.mkString.replaceAll("\\\\s", "")+"-SNAPSHOT"
}


// [TODO] what are these needed for? remove if obsolete
crossScalaVersions := Seq("2.11.11", "2.12.3")
scalacOptions ++= scalacOptionsVersion(scalaVersion.value)
javacOptions ++= javacOptionsVersion(scalaVersion.value)

// [TODO] what are these needed for? remove if obsolete
resolvers ++= Seq(
  Resolver.sonatypeRepo("snapshots"),
  Resolver.sonatypeRepo("releases")
)
// [TODO]: Is this redundant?
resolvers += "Sonatype Releases" at "https://oss.sonatype.org/content/repositories/releases/"

// Provide a managed dependency on X if -DXVersion="" is supplied on the command line.
// [TODO] is simpler clearer?
val defaultVersions = Map(
  "chisel3" -> "3.2-SNAPSHOT",
  "chisel-iotesters" -> "1.1.+"
  )

libraryDependencies ++= (Seq("chisel3","chisel-iotesters").map {
  dep: String => "edu.berkeley.cs" %% dep % sys.props.getOrElse(dep + "Version", defaultVersions(dep)) })


//This is (mainly) for TheSDK testbenches, may become obsolete
libraryDependencies += "com.gilt" %% "handlebars-scala" % "2.1.1"

libraryDependencies  ++= Seq(
//  // Last stable release
  "org.scalanlp" %% "breeze" % "0.13.2",
  
// Native libraries are not included by default. add this if you want them (as of 0.7)
  // Native libraries greatly improve performance, but increase jar sizes. 
  // It also packages various blas implementations, which have licenses that may or may not
  // be compatible with the Apache License. No GPL code, as best I know.
  "org.scalanlp" %% "breeze-natives" % "0.13.2",
  
  // The visualization library is distributed separately as well.
  // It depends on LGPL code
  "org.scalanlp" %% "breeze-viz" % "0.13.2"
)

// Some common deps in BWRC projects, select if needed
// TODO-how to figure out what version is the current and the best?
libraryDependencies += "edu.berkeley.cs" %% "dsptools" % "1.1-SNAPSHOT"

//libraryDependencies += "berkeley" %% "rocketchip" % "1.2"
//libraryDependencies += "edu.berkeley.eecs" %% "ofdm" % "0.1"
//libraryDependencies += "edu.berkeley.cs" %% "eagle_serdes" % "0.0-SNAPSHOT"

// Put your git-version controlled snapshots here
//libraryDependencies += "edu.berkeley.cs" %% "hbwif" % gitSubmoduleHashSnapshotVersion("hbwif")

EOF
cp ../configure_template ./configure

cat <<EOF > init_submodules.sh
#!/bin/sh
#Init submodules in this dir, if any
DIR="\$( cd "\$( dirname \$0 )" && pwd )"
git submodule update --init

#Publish local the ones you need
#cd \$DIR/clkdiv_n_2_4_8
#sbt publishLocal

#Selectively, init submodules of a larger projects
#cd \$DIR/rocket-chip
#git submodule update --init chisel3
#git submodule update --init firrtl
#git submodule update --init hardfloat

#Recursively update submodeles
#cd \$DIR/eagle_serdes
#git submodule update --init --recursive serdes_top
#sbt publishLocal
#Assemble executables
###sbt publishing
#cd \$DIR/rocket-chip/firrtl
#sbt publishLocal
#sbt assembly

exit 0
EOF
cat << EOF > ./README.md
# Description of scala module version control principle with git
Marko Kosunen, marko.kosunen@aalto.fi, 12.12.2018

## Principle of operation:
All modules version controlled with this method can be used effortlessly 
and recursively as git submodules inside similar modules

The mehod of use is _always_ the same
1. \`./init_submodules.sh\` (if any)
2. Publish locally the submodules you want to use.
    (embedded to init_submodules.sh)
3. \`./configure && make\`

## Version strings:
In build.sbt, the version of the current module is of from
"module-<commit-hash>-SNAPHOT"
It is created with line: 
\`version := scala.sys.process.Process("git rev-parse --short HEAD").!!.mkString.replaceAll("\\\\s", "")+"-SNAPSHOT"\`

Dependencies to similar submodules are defined with the 
function gitSubmoduleHashSnapshotVersion
and with the dependency definitions
\`libraryDependencies += "edu.berkeley.cs" %% "hbwif" % gitSubmoduleHashSnapshotVersion(modulename")\`

This dependency is satisfied only if there is a locallly published (sbt publishLocal) submodule 
with the submodule hash of the current git submodule.

**OBS1**: every time the submodule is updated, it must be published locally.
See init_submodules.sh for reference. Make it recursive if needed.

**OBS2**: If the submodules are edited and committed, the changes are visible 
at the top level ONLY if ALL the hierarchy levels of submodules from bottom 
module to top are git-added, git-committed and git-pushed.
This is the normal operation of submodules.

## Add your module readme here
Lorem ipsum...

EOF

sed -i "s/TEMPLATEMODULENAME/${MODULE}/" ./configure
git add ./configure && git add ./build.sbt && git add ./init_submodules.sh && git add ./README.md
git commit -m"Publish as a git-versioned submodule"
git push origin --set-upstream master
     cd ..
#    rm -rf ./$module
}

# These are to be included ALWAYS. Modify accordint to your needs.
FILES="README.md ./project ./build.sbt ./configure ./.gitignore ./init_submodules.sh"
#

## Then the actual modules
MODULE="halfband"

# These are the directories in src/main/scala to be retained
MODULELIST="$MODULE halfband_BW_01125_N_6 halfband_BW_0225_N_8 halfband_BW_045_N_40"
MODULES=$(printf "./src/main/scala/%s/\n" $MODULELIST | xargs ) 
PRESERVE="$FILES $MODULES"
PWD=$(pwd)

#Call the generator
#generate "$MODULE" "$PRESERVE" $PWD

# Repeat if needed.
#MODULE="halfband_interpolator"
#MODULELIST="$MODULE halfband_BW_01125_N_6 halfband_BW_0225_N_8 halfband_BW_045_N_40"
#MODULES=$(printf "./src/main/scala/%s/\n" $MODULELIST | xargs ) 
#PRESERVE="$FILES $MODULES"
#generate "$MODULE" "$PRESERVE" $PWD
#
#MODULE="cic3"
#MODULELIST="$MODULE"
#MODULES=$(printf "./src/main/scala/%s/\n" $MODULELIST | xargs ) 
#PRESERVE="$FILES $MODULES"
#generate "$MODULE" "$PRESERVE" $PWD
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

