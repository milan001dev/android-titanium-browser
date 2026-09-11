#!/bin/bash
source common.sh
set_keys
export VERSION=$(grep -m1 -o '[0-9]\+\(\.[0-9]\+\)\{3\}' vanadium/args.gn)
export CHROMIUM_SOURCE=https://chromium.googlesource.com/chromium/src.git # https://github.com/chromium/chromium.git
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y sudo lsb-release file nano git curl python3 python3-pillow imagemagick librsvg2-bin
sudo dpkg --add-architecture i386; sudo apt-get update; sudo apt-get install -y libgcc-s1:i386

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PWD/depot_tools:$PATH"
mkdir -p chromium/src/out/Default; cd chromium/src
git init
git remote add origin $CHROMIUM_SOURCE
git fetch --depth 1 $CHROMIUM_SOURCE +refs/tags/$VERSION:chromium_$VERSION
git checkout $VERSION
cp $SCRIPT_DIR/.gclient ../.gclient

# https://grapheneos.org/build#browser-and-webview
rm -rf $SCRIPT_DIR/vanadium/patches/*trichrome-{apk-build-targets,browser-apk-targets}.patch
rm -rf $SCRIPT_DIR/vanadium/patches/*{detailed,supported}-language*.patch
rm -rf $SCRIPT_DIR/vanadium/patches/*javascript-optimizer-{site-setting,settings-UI}.patch
rm -rf $SCRIPT_DIR/vanadium/patches/*component-updates.patch
rm -rf $SCRIPT_DIR/vanadium/patches/*{pdf,PDF,for-content-public,toolbar-button,configs-from-config-app,new-tab-card,predictive-back*}*.patch
# rm -rf $SCRIPT_DIR/vanadium/patches/*crashpad*.patch
replace "$SCRIPT_DIR/vanadium/patches" "VANADIUM" "TITANIUM"
replace "$SCRIPT_DIR/vanadium/patches" "Vanadium" "Titanium"
replace "$SCRIPT_DIR/vanadium/patches" "vanadium" "titanium"
git am --whitespace=nowarn --keep-non-patch $SCRIPT_DIR/vanadium/patches/*.patch

gclient sync -D --no-history --nohooks
gclient runhooks
./build/install-build-deps.sh --no-prompt

source $SCRIPT_DIR/patch.sh
mkdir -p out/tmp out/release

# 1. Compila ARM64 (64-bit per SoC MediaTek mt5896)
mkdir -p out/arm64
cp $SCRIPT_DIR/args.gn out/arm64/args.gn
sed -i 's/target_cpu = "arm"/target_cpu = "arm64"/' out/arm64/args.gn
gn gen out/arm64
autoninja -C out/arm64 chrome_public_apk chrome_public_bundle
mv $(find out/arm64/apks -name 'Chrome*.apk') out/tmp/$VERSION-arm64-v8a.apk
mv $(find out/arm64/apks -name 'Chrome*.aab') out/tmp/$VERSION-arm64-v8a.aab
rm -rf out/arm64

# 2. Compila ARM32 (32-bit armeabi-v7a di fallback)
mkdir -p out/arm
cp $SCRIPT_DIR/args.gn out/arm/args.gn
sed -i 's/target_cpu = "arm64"/target_cpu = "arm"/' out/arm/args.gn
gn gen out/arm
autoninja -C out/arm chrome_public_apk
mv $(find out/arm/apks -name 'Chrome*.apk') out/tmp/$VERSION-armeabi-v7a.apk
rm -rf out/arm

export PATH=$PWD/third_party/jdk/current/bin/:$PATH
export ANDROID_HOME=$PWD/third_party/android_sdk/public
for apk in out/tmp/*.apk; do
    [ -f "$apk" ] && sign_apk "$apk" "out/release/$(basename $apk)"
done
for aab in out/tmp/*.aab; do
    [ -f "$aab" ] && sign_aab "$aab" "out/release/$(basename $aab)"
done
rm -rf $SCRIPT_DIR/keys
