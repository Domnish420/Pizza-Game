#!/bin/bash
# Build the ARCore plugin (GodotVR/godot_arcore) for this game and put it in addons/ARCorePlugin/bin:
#   tools/android/build_arcore.sh
# The built libraries are committed, so this is only needed to change the plugin. Needs tools/android/setup.sh
# (JDK 17, the Android SDK with NDK 28.1, CMake 3.22.1, build tools 36.1, platform 36) and about 20 minutes.
#
# The plugin is taken at a known commit and changed by tools/android/arcore.patch: built against Godot 4.7's Android
# library and toolchain, AR optional (the game installs on any phone), and nothing asked (ARCore install, camera)
# until the game turns AR on (requestAR, arStatus). Its C++ is built against godot-cpp 4.5 (it runs on 4.5 and later).
set -e
cd "$(dirname "$0")/../.."
GAME=$PWD
WORK=${WORK:-/opt/build/godot_arcore}
PLUGIN_COMMIT=1509a01
GODOT_CPP_TAG=godot-4.5-stable
NDK=28.1.13356709
export ANDROID_HOME=${ANDROID_HOME:-/opt/android-sdk}
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/$NDK

if [ ! -d $WORK/.git ]; then
	git clone -q https://github.com/GodotVR/godot_arcore.git $WORK
fi
cd $WORK
git checkout -q -f $PLUGIN_COMMIT
git apply $GAME/tools/android/arcore.patch
echo "sdk.dir=$ANDROID_HOME" > local.properties

# godot-cpp for Android arm64 (debug and release)
if [ ! -f godot-cpp/bin/libgodot-cpp.android.template_release.arm64.a ]; then
	rm -rf godot-cpp
	git clone -q --depth 1 --branch $GODOT_CPP_TAG https://github.com/godotengine/godot-cpp.git godot-cpp
	(cd godot-cpp && scons platform=android target=template_debug arch=arm64 -j"$(nproc)" > /dev/null \
		&& scons platform=android target=template_release arch=arm64 -j"$(nproc)" > /dev/null)
fi

./gradlew assemble --no-daemon -q
mkdir -p $GAME/addons/ARCorePlugin/bin/debug $GAME/addons/ARCorePlugin/bin/release
cp plugin/demo/addons/ARCorePlugin/bin/debug/ARCorePlugin-debug.aar $GAME/addons/ARCorePlugin/bin/debug/
cp plugin/demo/addons/ARCorePlugin/bin/release/ARCorePlugin-release.aar $GAME/addons/ARCorePlugin/bin/release/
ls -la $GAME/addons/ARCorePlugin/bin/*/
