import os
import sys
import subprocess

# Code adapted from a script written by Manicqin 
# https://gist.github.com/Manicqin/35d81b4a7599bbe8b645

def find_qt_directory():
    # NOTE: Please be aware that if you used Homebrew to install Qt that you
    # may have also set up symlinks between the Qt tools (like 'QT Creator')
    # and your Mac's ~/Application directory which will give locateQt.py
    # problems isolating the Qt root directory.
    #
    # macdeployqt is used because it is in the right place by default, but
    # any of the Qt application components/tools can be specified in `mdfind` 
    mdfind = subprocess.check_output(["mdfind", "-name", """macdeployqt"""])
    possible_match = mdfind.split("\n")
 
    match = [x for x in possible_match if """macdeployqt""" and not """macdeployqtplus""" in x]
    if len(match) is not 1:
 
        if len(match) is 0:
            print "No matches were found. Please confirm that Qt has been installed on this machine."
        else:
            print "Multiple potential matches were returned:", match
 
        print "All possible matches:", possible_match
        exit()
 
    QT_ROOT_DIR = os.path.dirname(match[0])
    QT_BIN_DIR = ("%s/bin" % QT_ROOT_DIR)
    QT_FRAMEWORK_DIR = ("%s/lib" % QT_ROOT_DIR)
    print "locateQt.py found a match for QT dir", match, "\nQt root directory:", QT_ROOT_DIR, "\n\nQT_BIN_PATH is:", QT_BIN_DIR, "\nQT_FRAMEWORK_PATH is:", QT_FRAMEWORK_DIR, "\n"

    # if you want to automate the process you can use these return hooks:
    #return QT_ROOT_DIR
    #return QT_BIN_DIR
    #return QT_FRAMEWORK_DIR

find_qt_directory()
