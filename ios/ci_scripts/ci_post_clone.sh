#!/bin/sh
set -e

rm -rf "$HOME/Library/Developer/Xcode/DerivedData"
rm -rf /Volumes/workspace/DerivedData

if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi
export PATH="$PATH:$HOME/flutter/bin"

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter config --no-analytics
flutter pub get
flutter precache --ios

dart run flutter_launcher_icons
dart run flutter_native_splash:create

cd ios
rm -rf Pods Podfile.lock .symlinks
pod install
