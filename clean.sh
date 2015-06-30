#!/bin/bash

# use the BUNDLE_PATH environment variable to select the application bundle's
# parent directory; change to that directory
BUNDLE_ROOT="$(dirname "$BUNDLE_PATH")"
BUNDLE_PROCESSING_ROOT=$BUNDLE_ROOT/Processing/
cd $BUNDLE_PROCESSING_ROOT

# make a temporary file to write the output of the 'is this a git directory?'
# check command to
TEMP=$(mktemp /tmp/temporary-file.XXXXXXXX || exit 1)
GIT=`git rev-parse --is-inside-work-tree &> ${TEMP}`
IS_GIT=`cat $TEMP`

if [[ "$IS_GIT" == "true" ]]; then

    # run git commands needed to reset the current working directory and index
    # to the state it was in before the Qt-codesigner process restructured
    # the application bundle's directories
    git clean -df
    git reset --hard HEAD
    
    STATUS_TEMP=$(mktemp /tmp/temporary-file.XXXXXXXX || exit 1)
    STATUS=`git status &> ${STATUS_TEMP}`
    
    # check the contents of STATUS_TEMP and pull out the names of files that
    # need to be reverted (beyond the files touched when the `git clean` 
    # process ran previously)
    if [ -f $STATUS_TEMP ]
    then
      while read line
      do
      echo $line | grep -q deleted:
      if [ $? == 0 ]; then
        checkout=`echo ${line:9}`
        # (use "git checkout -- <file>..." to discard changes in working directory)
        echo $checkout
        git checkout -- $checkout
      fi
    done < $STATUS_TEMP
    fi

    git checkout master

else
  echo "Application Bundle Directory: ${BUNDLE_PROCESSING_ROOT}"
  echo "This directory does not appear to contain a git repository so it is not possible to revert its contents to a previous state."
  exit 0
fi
