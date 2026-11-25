#!/bin/bash
# Install what building the Android APK needs (Linux, as root): JDK 17, the Android SDK (platform 33 and 34, build
# tools, CMake, NDK r23c) in $ANDROID_HOME (default /opt/android-sdk), Godot 4.3's Android export templates, and the
# editor settings pointing Godot at them. Safe to run again: it skips what is already there.
#   tools/android/setup.sh
set -e
ANDROID_HOME=${ANDROID_HOME:-/opt/android-sdk}
JDK=/usr/lib/jvm/java-17-openjdk-amd64
TPL=~/.local/share/godot/export_templates/4.3.stable
GODOT_VERSION=4.3-stable

[ -x $JDK/bin/java ] || (apt-get update -qq && apt-get install -y -qq openjdk-17-jdk-headless)
command -v scons > /dev/null || apt-get install -y -qq scons

if [ ! -x $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager ]; then
	mkdir -p $ANDROID_HOME/cmdline-tools
	curl -fsSL -o /tmp/cmdline.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
	unzip -q -o /tmp/cmdline.zip -d $ANDROID_HOME/cmdline-tools && rm -f /tmp/cmdline.zip
	rm -rf $ANDROID_HOME/cmdline-tools/latest && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest
fi
SM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
if [ ! -d $ANDROID_HOME/ndk/23.2.8568313 ] || [ ! -d $ANDROID_HOME/cmake/3.22.1 ]; then
	yes | JAVA_HOME=$JDK $SM --licenses > /dev/null 2>&1 || true
	JAVA_HOME=$JDK $SM --install "platform-tools" "build-tools;34.0.0" "build-tools;33.0.2" "platforms;android-34" \
		"platforms;android-33" "cmake;3.10.2.4988404" "cmake;3.22.1" "ndk;23.2.8568313" > /dev/null
fi

if [ ! -f $TPL/android_source.zip ]; then
	mkdir -p $TPL
	curl -fsSL -o /tmp/templates.tpz https://github.com/godotengine/godot/releases/download/$GODOT_VERSION/Godot_v${GODOT_VERSION}_export_templates.tpz
	unzip -oj -q /tmp/templates.tpz templates/android_debug.apk templates/android_release.apk templates/android_source.zip \
		templates/version.txt -d $TPL && rm -f /tmp/templates.tpz
fi

# Godot's editor settings: where the SDK and JDK are (Godot writes the file, with a debug keystore, the first time
# the editor runs)
ES=~/.config/godot/editor_settings-4.3.tres
[ -f $ES ] || godot --headless --editor --quit > /dev/null 2>&1 || true
if [ -f $ES ]; then
	grep -q "export/android/android_sdk_path" $ES || echo 'export/android/android_sdk_path = ""' >> $ES
	grep -q "export/android/java_sdk_path" $ES || echo 'export/android/java_sdk_path = ""' >> $ES
	sed -i "s|^export/android/java_sdk_path = .*|export/android/java_sdk_path = \"$JDK\"|; s|^export/android/android_sdk_path = .*|export/android/android_sdk_path = \"$ANDROID_HOME\"|" $ES
fi
echo "Android build tools ready: $ANDROID_HOME, $JDK, $TPL"
