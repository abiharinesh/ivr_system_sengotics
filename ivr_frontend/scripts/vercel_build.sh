#!/bin/sh
set -e

echo "Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"

flutter --version

echo "Injecting frontend env..."
sh scripts/inject_env.sh

echo "Building Flutter web..."
flutter pub get
flutter build web
