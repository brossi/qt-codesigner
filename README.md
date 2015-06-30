# Qt-codesigner
A set of scripts and instructions to help you correctly codesign your Qt application on OSX 10.9 and up. 

Please report any issues you have with any of the scripts or questions about the process. Thank you!

## Scope
The current set of scripts and tools are focused on codesigning an application only, not an application and installer. Future versions of these tools could be extended to allow an application to sign an installer and/or to sign an application bundle for use in the Mac App Store. 

> There's nothing preventing these tools for being used for that purpose now, but I have not had the need or opportunity to do the research to see if there are additional steps required. Feel free to submit a pull request with the adjustments needed if you've figured it out.

## Dependencies

* Git (Comes pre-installed with OS X)
* Python 2.7 (Comes pre-installed with OS X)
* [Bash 4](http://johndjameson.com/blog/updating-your-shell-with-homebrew/)

## Setup

> Note: The tools included in *Qt-codesigner* make the assumption that you've already compiled a working version of your application bundle (ex. "MyProduct.app") prior to attempting to codesign. If you have not, please do this first and then follow the instructions here. Details about how to compile your application bundle are going to depend on your unique needs so instructions for how to do this are unfortunately outside the scope of what these tools can provide.

### Determine Where Qt Is Installed

If you used [Homebrew](http://brew.sh/) to install Qt (and I recommend you do if you have the option), the default installation location the Qt resources are placed is `/usr/local/Cellar/qt/{version}/`. Otherwise, if you're not sure where Qt is the python script, **locateQt.py** is included to help you locate the directory on your machine where Qt has been installed. 

```
python locateQT.py
```

Take note of the path that is returned by the script and then use that information to construct two parameters in **env_vars.sh**:
 * `QT_BIN_PATH`: the path to the parent directory where *macdeployqt* is located (ex. "/usr/local/Cellar/qt/4.8.7/bin");  
 * `QT_FRAMEWORK_PATH`: the path to the *lib* directory inside of the named version directory where Qt is located (ex. "/usr/local/Cellar/qt/4.8.7/lib")
 * `QT_VERSION`: Qt framework version for the application you are targeting (*Note: only Qt versions 4 and 5 are supported by the Qt-codesigner tools*)

Example response when only one option exists:

```
$ python locateQt.py
locateQt.py found a match for QT dir ['/usr/local/Cellar/qt/4.8.7/bin/macdeployqt']
Qt root directory: /usr/local/Cellar/qt/4.8.7

QT_BIN_PATH is: /usr/local/Cellar/qt/4.8.7/bin
QT_FRAMEWORK_PATH is: /usr/local/Cellar/qt/4.8.7/lib
```

Example response when more than one option exists (you'll need to manually generate the `QT_BIN_PATH` and `QT_FRAMEWORK_PATH` parameters based on which version of the Qt framework you want to use:

```
$ python locateQt.py
filtering possible matches returned too many possibilities please supply ['/usr/local/Cellar/qt/4.8.7/bin/macdeployqt', '/usr/bin/macdeployqt-4.8']
all possible matches: ['/usr/local/Cellar/qt/4.8.7/bin/macdeployqt', '/Users/devdoe/development/AnotherApp/contrib/macdeploy/macdeployqtplus', '/usr/bin/macdeployqt-4.8', '']
```

### Signing Identity

> If you don't yet have a valid code signing identity registered with Apple, you will need to get one through the [Apple Developer Portal](https://developer.apple.com/library/mac/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html#//apple_ref/doc/uid/TP40005929-CH4-SW2). Be aware that this process can take a few days to complete (you'll be waiting for Apple's response once you've set up your Developer account and applied for your certificates).

Once you've located where Qt is installed you'll next want to capture the Apple Developer identity you want to use to sign your application. To avoid any conflicts during the code signing process I recommend that you use the identity hash instead of the identity string. You may already have this information set aside, but if not, you can use the console command:

```
security find-identity
```

You may have multiple identities. For signing an application that will not be distributed through the Mac App Store, you'll be looking for the identity that follows the pattern, **Developer ID Application: {signing.name} ({alphanum.id})**.

Example:

```
Policy: X.509 Basic
  Matching identities
  1) D4B9E9AABF634B4431F053F95725D3934EC7E3C9 "com.apple.idms.appleid.prd.306a526e656c6754775779303250725a4a61584e6b413d3d"
  2) NT4K2OSYQJ55QACNIU2WCPGATTRIY77HY1EYUAGQ "Developer ID Application: Dev Doe (4QKM4X5HWT)"
  3) 2D2A58CADEB0A46976D746E3FA7693AD4D0E1C68 "Developer ID Installer: Dev Doe (4QKM4X5HWT)"
  4) 9928BCC01126B2C40C146ACBF43DE0CBC432D8BA "3rd Party Mac Developer Installer: Dev Doe (4QKM4X5HWT)"
     4 identities found

  Valid identities only
  1) D4B9E9AABF634B4431F053F95725D3934EC7E3C9 "com.apple.idms.appleid.prd.306a526e656c6754775779303250725a4a61584e6b413d3d"
  2) NT4K2OSYQJ55QACNIU2WCPGATTRIY77HY1EYUAGQ "Developer ID Application: Dev Doe (4QKM4X5HWT)"
  3) 2D2A58CADEB0A46976D746E3FA7693AD4D0E1C68 "Developer ID Installer: Dev Doe (4QKM4X5HWT)"
  4) 9928BCC01126B2C40C146ACBF43DE0CBC432D8BA "3rd Party Mac Developer Installer: Dev Doe (4QKM4X5HWT)"
     4 valid identities found
```

Take note of the 40-character long hash for the "Developer ID Application" identity and copy it into the `IDENTITY` parameter in **env_vars.sh**.

### Application To Be Signed

You'll want to let Qt-codesigner's scripts know where to find the application you want to sign. In **env_vars.sh** populate the `BUNDLE_PATH` parameter with the absolute path to the application bundle you want to codesign (ex. "/Users/testuser/development/myapplication/MyApp.app").

## Codesigning Your Application Bundle

Once you've filled out all of the environent variable parameters in **env_vars.sh** you're ready to codesign your application bundle.

```
./codesign.sh
```

The process will output the steps it is taking and report any issues through the console. A successful run will be indicated in the output.

### Reverting the Process

If you should find yourself in a situation where the Git repository that is automagically created during the Qt-codesigner process needs to be reset to the base state use the *clean* argument when launching the main script:

```
./codesign.sh clean
```

---

## Resources And Other Relevant Discussions

* http://successfulsoftware.net/2014/10/17/signing-qt-applications-for-mac-os-x-10-9-5-and-10-10/
* https://blog.qt.io/blog/2014/10/29/an-update-on-os-x-code-signing/
* https://forum.qt.io/topic/45590/codesigning-for-qt-application-developed-for-mac-os-x
* https://developer.apple.com/library/mac/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/FrameworkAnatomy.html
* https://developer.apple.com/library/ios/technotes/tn2318/_index.html
* http://stackoverflow.com/questions/27952111/unable-to-sign-app-bundle-using-qt-frameworks-on-os-x-10-10
* http://forums.macnn.com/79/developer-center/355720/how-re-sign-apples-applications-once/
* http://furbo.org/2013/10/17/code-signing-and-mavericks/
* http://stackoverflow.com/questions/29560736/xcode-6-3-code-signing-issues-after-update
* http://macinstallers.blogspot.com/2014/08/codesign-mavericks-yosemite-commands.html