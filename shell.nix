{ pkgs ? import <nixpkgs> {} }:
# https://grapheneos.org/build
# Pixel 5: redfin, kernel is redbull
# Build:
#  dpkg --add-architecture amd64
#  # https://packages.debian.org/buster/libc6
#  sudo dpkg -i libc6_2.28-10_amd64.deb libgcc1_8.3.0-6_amd64.deb gcc-8-base_8.3.0-6_amd64.deb
#
#  mkdir src
#  cd src
#  # https://grapheneos.org/releases#redfin-stable
#  TAG=SQ1A.211205.008.2021122018
#  repo init -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/$TAG
#  gpg --recv-keys 65EEFE022108E2B708CBFCF7F9E712E59AF5F22A
#  ( cd .repo/manifests && git verify-tag $(git describe) )
#  repo sync -j16
#
#  cd kernel/google/redbull
#  git submodule sync
#  git submodule update --init --recursive
#  ./build.sh redfin
#  #nix-shell --run 'cd src/kernel/google/redbull && gos-build-env bash ./build.sh redfin'
#  cd ../../..
#
#  #BUILD_ID for vendor files:
#  #  https://www.reddit.com/r/CopperheadOS/comments/8oncnp/build_help_step_extracting_vendor_files/
#  #  https://developers.google.com/android/images#redfin  -> SQ1A.211205.008
#  DEVICE=redfin
#  BUILD_ID=SQ1A.211205.008
#  vendor/android-prepare-vendor/execute-all.sh -d $DEVICE -b $BUILD_ID -o vendor/android-prepare-vendor
#  mkdir -p vendor/google_devices
#  rm -rf vendor/google_devices/$DEVICE
#  mv vendor/android-prepare-vendor/$DEVICE/$BUILD_ID/vendor/google_devices/* vendor/google_devices/
#
#  source script/envsetup.sh
#  export OFFICIAL_BUILD=true
#  sed -iE '/name="url"/ s_https://[^<>]*_https://groot.wahrhe.it_' packages/apps/Updater/res/values/config.xml
#  choosecombo release redfin user
#
#  m target-files-package

let
  #androidsdk = 
  #  ((import <nixpkgs> {config.android_sdk.accept_license = true; system = "x86_64-linux"; }).androidsdk_9_0);
  androidStuff =
    ((import <nixpkgs> {config.android_sdk.accept_license = true; system = "x86_64-linux"; }).androidenv.composeAndroidPackages {
      platformVersions = [ "31" ];
      abiVersions = [ "x86" "x86_64"];
      includeNDK = true;
      ndkVersion = "21.4.7075529";
      platformToolsVersion = "31.0.3";
      buildToolsVersions = [ "31.0.0" ];

      # cp /nix/var/nix/profiles/per-user/root/channels/nixos/nixpkgs/pkgs/development/mobile/androidenv/*.{sh,rb} repo/
      # nix-shell -p ruby --run 'cd repo && ./generate.sh'
      repoJson = ./repo/repo.json;
    });
  androidsdk = androidStuff.androidsdk;
  deps = pkgs: with pkgs; [
    gitRepo git gnupg
    jdk ncurses5 openssl rsync unzip zip
    e2fsprogs jq protobuf
    (python3.withPackages (p: with p; [ p.protobuf ]))
    signify
    libarchive.out  # for bsdtar

    # skip prebuilt tools -> use our own -> doesn't work
    #clang_13 bison flex bc lld_13 llvmPackages_13.bintools llvmPackages_13.llvm
  ];

  fhs = pkgs.buildFHSUserEnv {
    name = "gos-build-env";
    #targetPkgs = p: deps p ++ [ p.zlib p.gcc p.glibc p.glibc.dev ];
    # gcc-unwrapped is for /lib/gcc
    targetPkgs = p: [ p.zlib p.gcc p.glibc p.glibc.dev p.gcc-unwrapped p.openssl p.openssl.dev p.ncurses6 p.ncurses5.dev ];
    extraBuildCommands = ''
      # prefer wrapped gcc
      ls -l $out/usr/bin -d
      chmod u+w $out/usr/bin
      ln -sf ${pkgs.gcc}/bin/* $out/usr/bin
    '';
  };
in pkgs.mkShell {
  buildInputs = deps pkgs ++ [ fhs ];

  shellHook = ''
    export ANDROID_SDK_ROOT=${androidsdk}/libexec/android-sdk
    export ANDROID_NDK_ROOT=${androidsdk}/libexec/android-sdk/ndk-bundle
    DEVICE=redfin
    BUILD_ID=SQ1A.211205.008

    # sdkmanager uses JAVA_HOME to find Java and it doesn't work with Java 17
    # unset JAVA_HOME so it is using java8, which is set by the wrapper script
    unset JAVA_HOME

    # nix-shell sets temp to /run/user/$UID, which will not have enough space.
    unset TMP TEMP TMPDIR TEMPDIR
  '';
}
