#!/bin/bash
# Install what building the Android APK needs (Linux, as root): JDK 17, the Android SDK (platform 36, build tools
# 36.1, CMake 3.22.1, NDK 28.1 for the ARCore plugin and 29 for Godot's Gradle build) in $ANDROID_HOME (default
# /opt/android-sdk), Godot 4.7.2's Android export templates, and the editor settings pointing Godot at them. Safe to
# run again: it skips what is already there.
#   tools/android/setup.sh
set -e
ANDROID_HOME=${ANDROID_HOME:-/opt/android-sdk}
JDK=/usr/lib/jvm/java-17-openjdk-amd64
TPL=~/.local/share/godot/export_templates/4.7.2.stable
GODOT_VERSION=4.7.2-stable

[ -x $JDK/bin/java ] || (apt-get update -qq && apt-get install -y -qq openjdk-17-jdk-headless)
command -v scons > /dev/null || apt-get install -y -qq scons

if [ ! -x $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager ]; then
	mkdir -p $ANDROID_HOME/cmdline-tools
	curl -fsSL -o /tmp/cmdline.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
	unzip -q -o /tmp/cmdline.zip -d $ANDROID_HOME/cmdline-tools && rm -f /tmp/cmdline.zip
	rm -rf $ANDROID_HOME/cmdline-tools/latest && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest
fi
SM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
if [ ! -d $ANDROID_HOME/ndk/29.0.14206865 ] || [ ! -d $ANDROID_HOME/ndk/28.1.13356709 ]; then
	yes | JAVA_HOME=$JDK $SM --licenses > /dev/null 2>&1 || true
	JAVA_HOME=$JDK $SM --install "platform-tools" "build-tools;36.1.0" "platforms;android-36" "cmake;3.22.1" \
		"ndk;28.1.13356709" "ndk;29.0.14206865" > /dev/null
fi

if [ ! -f $TPL/android_source.zip ]; then
	mkdir -p $TPL
	curl -fsSL -o /tmp/templates.tpz https://github.com/godotengine/godot/releases/download/$GODOT_VERSION/Godot_v${GODOT_VERSION}_export_templates.tpz
	unzip -oj -q /tmp/templates.tpz templates/android_debug.apk templates/android_release.apk templates/android_source.zip \
		templates/version.txt -d $TPL && rm -f /tmp/templates.tpz
fi

# a debug key to sign test builds with (the same one Godot's editor would make)
KS=~/.local/share/godot/keystores/debug.keystore
if [ ! -f $KS ]; then
	mkdir -p "$(dirname $KS)"
	$JDK/bin/keytool -genkeypair -keyalg RSA -keysize 2048 -validity 9999 -alias androiddebugkey -keypass android \
		-keystore $KS -storepass android -dname "CN=Android Debug,O=Android,C=US" > /dev/null 2>&1
fi
# Godot's editor settings: where the SDK, the JDK and the debug key are
ES=~/.config/godot/editor_settings-4.7.tres
if [ ! -f $ES ]; then
	mkdir -p "$(dirname $ES)"
	printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > $ES
fi
for kv in "java_sdk_path=$JDK" "android_sdk_path=$ANDROID_HOME" "debug_keystore=$KS" "debug_keystore_user=androiddebugkey" \
		"debug_keystore_pass=android"; do
	k=${kv%%=*}; v=${kv#*=}
	if grep -q "^export/android/$k = " $ES; then sed -i "s|^export/android/$k = .*|export/android/$k = \"$v\"|" $ES
	else echo "export/android/$k = \"$v\"" >> $ES; fi
done
echo "Android build tools ready: $ANDROID_HOME, $JDK, $TPL"
