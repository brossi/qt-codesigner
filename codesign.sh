#!/bin/bash
clear

# scope: Restructure the application bundle's frameworks and plugins to correct
#        an issue with how Qt builds the bundle contrary to how OS X's codesign
#        process expects it to be structured. Once the structure has been fixed
#        invoke the codesign process in an inside-out manner (signing the
#        nested frameworks and plugins, first, before signing bundle).
WORKING_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
printf "\n******* STARTING CODESIGN PROCESS *******\n"

# long-running task progress indicator
spinner()
{
  local pid=$1
  local delay=0.75
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# check to see if the user is attempting to pass the revert parameter 
# along with the script to invoke the reset functionality
if [[ "$1" == "clean" ]]; then
    source env_vars.sh
    printf "\n******* Returning 'Processing' Repo To Base State *******\n"
    . clean.sh
    exit
fi

# refresh session with user-specified environment variables
source env_vars.sh

BUNDLE_NAME=$(basename $BUNDLE_PATH)

PROCESSING="Processing"

# use the BUNDLE_PATH environment variable to select the application bundle's
# parent directory; change to that directory
BUNDLE_ROOT="$(dirname "$BUNDLE_PATH")"
TEMP=$(mktemp /tmp/temporary-file.XXXXXXXX || exit 1)
cd $BUNDLE_ROOT

# enable backup if the MAKE_BACKUP environment variable is set to 'true'
if [ $MAKE_BACKUP == true ]; then
  ORIG="Original"
  mkdir -p $ORIG
  echo "Making a copy of $BUNDLE_NAME and moving it to the 'Original' directory."
  rsync -avhW --progress $BUNDLE_PATH $ORIG > ${TEMP}
fi

# check to see if the 'Processing' directory has already been created; if 
# it hasn't, create it and make a copy of the application bundle, and then
# instantiate a new Git repository
if [ ! -d $BUNDLE_PATH/$PROCESSING ]; then
  # create the directories that we'll need to make copies of the targetted
  # application bundle
  mkdir -p $PROCESSING

  # create the intermediary tar file and pipe it to the destination directory
  # http://serverfault.com/questions/43014/copying-a-large-directory-tree-locally-cp-or-rsync
  echo "Making a copy of $BUNDLE_NAME and moving it to the 'Processing' directory."
  rsync -avhW --progress $BUNDLE_PATH $PROCESSING > ${TEMP}

  # remove original file temporarily so it doesn't get confused with the
  # eventual signed application bundle output
  #echo "Temporarily removing the source file until processing has finished..."
  #rm -rf $SRC

  # protect the base state before processing with Git to make it easy to 
  # revert to a clean state if something goes wrong
  GIT_DIR="$BUNDLE_ROOT/$PROCESSING/"
  cd $GIT_DIR
  printf ".DS_Store" > .gitignore
  git init && git add -A && git commit -avm "Base app bundle state before running codesign processes." --quiet
fi

# if the 'Original' directory exists, proceed with the Qt-codesigner process;

# restructure application bundle directories to meet new OS X guidelines
# https://developer.apple.com/library/mac/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/FrameworkAnatomy.html
cd $WORKING_DIR
python restructure.py

# CODESIGN PROCESS
BUNDLE_PROCESSING_ROOT=$BUNDLE_ROOT/$PROCESSING/
BUNDLE_PROCESSING_PATH=$BUNDLE_ROOT/$PROCESSING/$BUNDLE_NAME
FRAMEWORK_DIRS=$BUNDLE_PROCESSING_PATH/Contents/Frameworks
PLUGIN_DIRS=$BUNDLE_PROCESSING_PATH/Contents/PlugIns
BAD_FRAMEWORKS=('QtGui')

# clean-up Info.plist files to make sure that no unauthorized  "Qt*_debug" 
# values have hitched a ride
printf "\n******* Fixing Bad Framework Info.plist Files *******\n"

for CURRENT_FRAMEWORK in ${BAD_FRAMEWORKS}; do
  echo "Framework Info.plist with incorrect value found: ${CURRENT_FRAMEWORK}"
  TMP=$(sed 's/_debug//g' ${BUNDLE_PROCESSING_PATH}/Contents/Frameworks/${CURRENT_FRAMEWORK}.framework/Resources/Info.plist)
  echo "$TMP" > ${BUNDLE_PROCESSING_PATH}/Contents/Frameworks/${CURRENT_FRAMEWORK}.framework/Resources/Info.plist
done 

# recursion function for looping through framework and plugin directories
recurse() {
  for i in "$1"/*; do
    if [ -d "$i" ]; then
        #echo "$i"
        recurse "$i"
    fi
    EXCLUDE="_CodeSignature"
    if [ "${i/$EXCLUDE}" = "$i" ]; then
      # excluded directories not included in the current target path;
      # check each object to see if it has already been signed; if it has
      # not yet been signed go ahead and sign it
      CS_TEMP=$(mktemp /tmp/temporary-file.XXXXXXXX || exit 1)
      CHECKSIG=`codesign --verify $CODESIGN_OPTIONS $i &> ${CS_TEMP}`
      if [ -f $CS_TEMP ]; then
        while read line; do
          echo "${line}" | grep -q "code object is not signed at all"
          if [ $? -eq 0 ]; then
            # object found that hasn't been signed yet
            echo "${i} (Signed)"
            codesign -s "${IDENTITY}" $i
          #else
            # object found that has already been signed
            #echo "${i}"
          fi
        done < $CS_TEMP
      fi
    fi
  done
}

printf "\n******* Signing Frameworks and Plugins ***********\n"
cd $BUNDLE_PROCESSING_PATH

# sign frameworks
FRAMEWORK_TEMP=$(mktemp /tmp/temporary-file.XXXXXXXX || exit 1)
( recurse $FRAMEWORK_DIRS > $FRAMEWORK_TEMP 2>&1 ) &
spinner $!
# sign plugins
PLUGIN_TEMP=$(mktemp /tmp/temporary-file.XXXXXXXX || exit 1)
( recurse $PLUGIN_DIRS > $PLUGIN_TEMP 2>&1 ) &
spinner $!

cat $FRAMEWORK_TEMP
cat $PLUGIN_TEMP

# todo: enable the 'tree view' with callouts for the files that were signed
# COUNTER=0
# TREE_TEMP=$(mktemp /tmp/temporary-file.XXXXXXXX || exit 1)
# for i in $BUNDLE_PROCESSING_PATH; do
#     # we only want to loop through the tree once
#     if [[ $i == $BUNDLE_PROCESSING_PATH && $COUNTER == 0 ]]; then
#       COUNTER=$[COUNTER + 1]
#       # generate the nice "tree view" from the path to the file we're
#       # evaluating in the application bundle
#       TREE_GEN=`find $BUNDLE_PROCESSING_PATH -print | sed -e "s;$BUNDLE_PROCESSING_PATH;\.;g;s;[^/]*\/;|__;g;s;__|; |;g"`
#       echo "$TREE_GEN" > $TREE_TEMP 2>&1
#     fi
# done
#cat $TREE_TEMP

shopt -s nullglob
SHORT_NAME=${BUNDLE_NAME[@]%.app}

# sign bundle
printf "\n******* Sign Bundle ***********\n"
codesign --force --verify ${CODESIGN_OPTIONS} --deep --sign "${IDENTITY}" . $BUNDLE_PROCESSING_PATH

# verify
printf "\n******* Verify Bundle ***********\n"
otool -L $BUNDLE_PROCESSING_PATH/Contents/MacOS/$SHORT_NAME
printf "\n\n"
codesign --verify --deep ${CODESIGN_OPTIONS} $BUNDLE_PROCESSING_PATH

printf "\n******* Verify Bundle (spctl) ***********\n"
VERIFY_TEMP=$(mktemp /tmp/temporary-file.XXXXXXXX || exit 1)
( spctl -a -vvvv $BUNDLE_PROCESSING_PATH > ${VERIFY_TEMP} 2>&1 )
spctl -a -vvvv $BUNDLE_PROCESSING_PATH

IS_ACCEPTED=(`cat $VERIFY_TEMP`)

if [ ${IS_ACCEPTED/'accepted'} = $IS_ACCEPTED ]; then
  printf "The application bundle has been successfully signed!\nThe final step is to commit the changes to the master branch and then change the name of the 'Processing' directory to 'Signed'.\n"

  cd $BUNDLE_PROCESSING_ROOT
  git add -A && git commit -avm"Successfully signed the $SHORT_NAME.app bundle." && git checkout master && git merge --no-ff restructure -q -m "Finishing up the application signing process."
  
  cd ..
  mv Processing Signed
  printf "\n******* CODESIGN PROCESS COMPLETED ***********\n"
fi