#!/bin/bash
# Build the Android APK into build/:  tools/android/build.sh [debug|release]   (default: debug)
# Needs tools/android/setup.sh first. A debug build is signed with Godot's debug key and installs on any phone that
# allows apps from outside the Play Store. A release build needs a keystore: GODOT_ANDROID_KEYSTORE_RELEASE_PATH,
# GODOT_ANDROID_KEYSTORE_RELEASE_USER and GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD.
set -e
cd "$(dirname "$0")/../.."
KIND=${1:-debug}
mkdir -p build
godot --headless --path . --import > /dev/null 2>&1 || true
OUT=build/CrustEmpire-$KIND.apk
# a Gradle build (the ARCore plugin is an Android library): Godot's Android project goes in android/ the first time
INSTALL=""
[ -d android/build ] || INSTALL="--install-android-build-template"
godot --headless --path . $INSTALL --export-$KIND "Android" $OUT 2>&1 | tee build/export.log | grep -E "ERROR|error:|FAILURE|export: end" || true
[ -f $OUT ] || { echo "no APK built"; exit 1; }
ls -la $OUT
