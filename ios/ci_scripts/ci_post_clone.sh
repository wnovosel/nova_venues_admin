#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
