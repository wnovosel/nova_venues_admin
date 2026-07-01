#!/bin/sh
set -e

rm -rf $HOME/Library/Developer/Xcode/DerivedData
rm -rf /Volumes/workspace/DerivedData

git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

cd $CI_PRIMARY_REPOSITORY_PATH
flutter pub get
flutter precache --ios

cd ios
rm -rf Pods Podfile.lock .symlinks
pod install
