import os
import shutil
import subprocess
import sys
import pprint
import fnmatch
import argparse
import fileinput

# source session variables defined in the env_vars.sh file
command = ['bash', '-c', 'source env_vars.sh']
proc = subprocess.Popen(command, stdout = subprocess.PIPE)
for line in proc.stdout:
  (key, _, value) = line.partition("=")
  os.environ[key] = value
proc.communicate()
#pprint.pprint(dict(os.environ)) #debug

# assign environment variables required for restructuring
BUNDLE_PATH = os.environ['BUNDLE_PATH']
BUNDLE_NAME = os.path.basename(BUNDLE_PATH)
#print(BUNDLE_NAME)
BUNDLE_ROOT_PATH = os.path.dirname(BUNDLE_PATH)
BUNDLE_PROCESSING_ROOT = os.path.join(BUNDLE_ROOT_PATH, 'Processing')
BUNDLE_PROCESSING_PATH = os.path.join(BUNDLE_PROCESSING_ROOT, BUNDLE_NAME)
#print(BUNDLE_PROCESSING_PATH)

QT_BIN_PATH = os.environ['QT_BIN_PATH']
BUNDLE_FRAMEWORKS_PATH = os.path.join(BUNDLE_PROCESSING_PATH, 'Contents','Frameworks')
#print(BUNDLE_FRAMEWORKS_PATH)
version_check = QT_BIN_PATH.split('.')
QT_VERSION = os.environ['QT_VERSION']
#print(QT_VERSION)

# restructure application bundle framework and plugin directory structure
# adapted from https://gist.github.com/kingcheez/6154462d7734e0c0f3a4
print('\n********** Restructuring Application Bundle *********')

def symlink(source,target):
    if not os.path.exists(target):
        print 'link: ',source,'-->',target
        os.symlink(source,target)
 
def move(source,target):
    if not os.path.exists(target):
        print 'move: ',source,'-->',target
        shutil.move(source,target)
 
def copy(source,target):
    if not os.path.exists(target):
        print 'copy: ',source,'-->',target
        shutil.copyfile(source,target)
 
def chdir(target):
    print 'chdir: ',target
    os.chdir(target)
 
def rmdir(target):
    print 'rmdir: ',target
    shutil.rmtree(target)
 
def mkdir(target):
    if not os.path.isdir(target):
        os.makedirs(target)

# set the Git branch for the 'Processing' repo so we can revert it in the
# future if needed
chdir(BUNDLE_PROCESSING_ROOT)
command = ['bash', '-c', 'git checkout -b restructure']
proc = subprocess.Popen(command, stdout = subprocess.PIPE)
proc.communicate()

for root,frameworks,files in os.walk(BUNDLE_FRAMEWORKS_PATH):
    for framework in frameworks:
        if fnmatch.fnmatch(framework,'Qt*.framework'):
            chdir(os.path.join(root,framework))
            module = framework.replace('.framework','')
            symlink(QT_VERSION,'Versions/Current')
            symlink('Versions/Current/' + module,module)
            move('Resources','Versions/Current/Resources')
            # rmdir('Resources')
            # mkdir('Versions/4/Resources')
            copy(os.path.join(QT_BIN_PATH,'lib',framework,'Contents','Info.plist'),
               'Versions/%s/Resources/Info.plist' % QT_VERSION)
            symlink('Versions/Current/Resources','Resources')

def call_program(*args):
    l = subprocess.check_output(*args).strip().split("\n")
    if len(l) == 1:
        return l[0]
    else:
        return l

chdir(BUNDLE_PROCESSING_PATH)
for link in call_program(["find","-L",BUNDLE_PROCESSING_PATH,"-type","l"]):
    filename = os.path.split(link)[1]
    # find the actual file
    params = ["find",BUNDLE_PROCESSING_PATH,
              "-type","f",
              "-and","-not","-type","l",
              "-and","-name",filename]
    targetfile = call_program(params)
    os.remove(link)
    symlink(targetfile,link)


# debug; test to confirm that changes are being made and the Git index is
# being updated
#chdir(BUNDLE_PROCESSING_ROOT)
#proc = subprocess.check_output(['git','status'])
#output = proc.decode('utf-8')
#print(output)

# Once the restructuring process is complete, move on to the codesigning
# steps of the process detailed in sign.sh