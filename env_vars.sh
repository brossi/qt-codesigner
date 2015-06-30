#!/bin/bash

# ENVIRONMENT VARIABLES USED IN THE CODESIGN PROCESS

# where the scripts can find your local Qt installation
# use `locateQt.py` if you don't have this information
export QT_BIN_PATH=""
export QT_FRAMEWORK_PATH=""
# the version of Qt you are targeting
export QT_VERSION=""

# codesign identity and options
export IDENTITY=""
export CODESIGN_OPTIONS="--verbose=4 --timestamp=none"

# application you are going to sign
export BUNDLE_PATH=""

# leave INFO_PLIST_PATH blank if you've customized the info.plist file 
# that came with the Qt-codesigner repo, or populate the parameter with the
# absolute path to a different info.plist file for your application
export INFO_PLIST_PATH=""

# whether or not you want to create an 'Original' directory with a copy
# of the application bundle; useful as a security measure until you've run 
# through the Qt-codesigner process a few times (set to 'false' to turn off)
export MAKE_BACKUP=true