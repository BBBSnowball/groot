{ pkgs ? import <nixpkgs> {} }:
# https://grapheneos.org/build
# Pixel 5: redfin, kernel is redbull
# Build:
#  # for Debian aarch64 - doesn't work
#  #dpkg --add-architecture amd64
#  ## https://packages.debian.org/buster/libc6
#  #sudo dpkg -i libc6_2.28-10_amd64.deb libgcc1_8.3.0-6_amd64.deb gcc-8-base_8.3.0-6_amd64.deb
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
#  # build needs files for arm but they only exist for arm64 -> copy them over because we don't need them to be correct, I think
#  cp ./external/vanadium/prebuilt/{arm64/*.apk,arm/}
#
#  source script/envsetup.sh
#  export OFFICIAL_BUILD=true
#  sed -iE '/name="url"/ s_https://[^<>]*_https://groot.wahrhe.it_' packages/apps/Updater/res/values/config.xml
#  choosecombo release redfin user
#
#  m target-files-package
#
#  ... generate keys ...
#  "", "abcd"
#
#  m otatools-package
#  ln -s . vendor/google_devices/redfin
#  OUT=$(pwd)/out ANDROID_BUILD_TOP=$(pwd) bash -x script/release.sh redfin
#
#  mkdir x && cd x && unzip ../out/release-redfin-2021122717/redfin-factory-2021122717.zip && cd redfin-factory-2021122717 && ./flash-all.sh
#
#  # verify:
#  # https://www.reddit.com/r/GrapheneOS/comments/bpcttk/avb_key_auditor_app/
#  # -> yes, it is simply the sha256
#  # https://android.googlesource.com/platform/external/avb/+/master/README.md
#  # -> bootloader must show the fingerprint in the warning. It does so as "ID: xxx" with the first 8 digits.
#  sha256sum keys/redfin/avb_pkmd.bin
#  # change here: https://github.com/GrapheneOS/Auditor/blob/629e4fbde19abd51cacb9324b054d734a3c07f7a/app/src/main/java/app/attestation/auditor/AttestationProtocol.java#L490

#  cd Auditor
#  TODO: change avb fingerprint and apk signing key
#  keytool -genkey -v -keystore ~/android.keystore -alias snowball -keyalg RSA -keysize 4096 -validity 10000;  #abcdef
#  keytool -list -keystore ~/android.keystore  ;# -> fingerprint -> remove colons -> ATTESTATION_APP_SIGNATURE_DIGEST_RELEASE
#  ./gradlew assemble --no-daemon
#  cp app/build/outputs/apk/release/app-release-unsigned.apk x.apk
#  $ANDROID_SDK_ROOT/build-tools/31.0.0/apksigner sign --ks ~/android.keystore x.apk
#  adb install --no-streaming x.apk

#
# #NOTE: most of the above should also be run in the gos-build-env...
# ( cd Magisk && nix-shell -p ../shell.nix --run "gos-build-env python3 ./build.py all" )

# NIX_SSHOPTS="-F .servers/a/config" nix-copy-closure --from server /nix/store/4yahnihpl6cy9libp6d50m613f7p196i-release.sh

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
    jdk11 ncurses5 openssl rsync unzip zip
    e2fsprogs jq protobuf
    (python3.withPackages (p: with p; [ p.protobuf ]))
    signify
    libarchive.out  # for bsdtar

    # skip prebuilt tools -> use our own -> doesn't work
    #clang_13 bison flex bc lld_13 llvmPackages_13.bintools llvmPackages_13.llvm

    # for autoPatchelfHook of prebuilt binaries
    ncurses5 autoPatchelfHook libcxx

    # fastboot, for flashing
    android-tools
  ];

  # build system unsets LD_LIBRARY_PATH so make a good enough ld.so.conf
  # test with: LD_LIBRARY_PATH= ldd prebuilts/clang/host/linux-x86/clang-r416183b1/bin/clang++.real
  # ( LD_LIBRARY_PATH= LD_DEBUG=all ldd prebuilts/clang/host/linux-x86/clang-3289846/bin/clang.real |&less )
  # ( ldconfig -v -N -f /etc/ld.so.conf |grep ncur; patchelf --print-soname /lib/libncurses.so.5 )
  # ( LD_LIBRARY_PATH=$LD_LIBRARY_PATH:prebuilts/jdk/jdk11/linux-x86/lib/server ldd /home/user/grapheneos/src/prebuilts/jdk/jdk11/linux-x86/lib/libfontmanager.so )
  # ( java -jar out/host/linux-x86/framework/RecoveryImageGenerator.jar --image_width 1070 --text_name recovery_installing --font_dir out/target/product/redfin/obj/ETC/recovery_font_files_intermediates --resource_dir bootable/recovery/tools/recovery_l10n/res/ --output_file out/target/product/redfin/obj/ETC/recovery_text_res_intermediates//installing_text.png --center_alignment )
  # out/host/linux-x86/bin/avbtool and assemble_vintf work now (with patched sonames for ld.so.cache) but only after rebuilding them.
  # https://unix.stackexchange.com/questions/520546/nixos-modifying-config-files-on-a-buildfhsuserenv-environment
  # Debian also adds paths like /lib/x86_64-linux-gnu but they don't exist here.
  ldConfig = pkgs.writeTextFile {
    name = "ld-config";
    destination = "/etc/ld.so.conf";
    text = ''
      #/usr/lib  # symlink to lib64
      /usr/lib32
      /usr/lib64
    '';
  };
  ldConfigCache = pkgs.runCommand "ld-cache" {
    env = fhsBuilder [ ldConfig ];
  } ''
    mkdir -p $out/etc
    $env/bin/gos-build-env -c "ldconfig -f /etc/ld.so.conf -C $out/etc/ld.so.cache"
  '';

  fhsBuilder = extra: pkgs.buildFHSUserEnv {
    name = "gos-build-env";
    #targetPkgs = p: deps p ++ [ p.zlib p.gcc p.glibc p.glibc.dev ];
    # gcc-unwrapped is for /lib/gcc
    targetPkgs = p: (with p; [ zlib gcc glibc glibc.dev gcc-unwrapped openssl openssl.dev ncurses6 ncurses5.dev autoPatchelfHook freetype jdk11 fontconfig ]
      ++ extra);
    extraBuildCommands = ''
      # prefer wrapped gcc
      chmod u+w $out/usr/bin
      ln -sf ${pkgs.gcc}/bin/* $out/usr/bin

      # NixOS doesn't usually want ld.so to use the systems directories but we needs this here.
      #NOTE We should do the same for the 32-bit libraries...
      #     see also: https://github.com/NixOS/nixpkgs/pull/59595
      ln -sf ${libcNoPatch}/lib/ld* $out/lib/
      ln -sf ${libcNoPatch}/lib/ld* $out/usr/lib/
      ln -sf ${libcNoPatch.bin}/bin/ldd $out/usr/bin/

      #for x in /bin/sh /bin/bash /usr/bin/sh /usr/bin/bash ; do
      #  mv $out$x $out$x.orig
      #  cp -L $out$x.orig $out$x
      #  chmod u+w $out$x
      #  patchelf --set-interpreter ${libcNoPatch}/lib/ld-*.so $out$x
      #done

      for x in $out/lib/*.so* ; do
        if patchelf --print-soname $x &>/dev/null ; then
          a=$(basename $x)
          b=$(patchelf --print-soname $x)
          #a2="$(sed -s 's/^\(.*\.so\.[0-9]\+\)\..*/\1/' <<<"$a")"
          #if [ "$a2" != "$b" ] ; then
          if [ "$a" != "$b" -a "''${a##$b.}" == "$a" ] ; then
            # filename doesn't start with soname -> might be an alias
            echo "soname doesn't match filename: $a: $b"
            mv $x $x.bak
            cp -L $x.bak $x
            rm $x.bak
            chmod u+w $x
            patchelf --set-soname "$a" "$x"
          fi
        fi
      done
    '';
    profile = shellHookBase;
  };
  fhs = fhsBuilder [ ldConfig ldConfigCache ];

  shellHookBase = ''
    export ANDROID_SDK_ROOT=${androidsdk}/libexec/android-sdk
    export ANDROID_NDK_ROOT=${androidsdk}/libexec/android-sdk/ndk-bundle

    # sdkmanager uses JAVA_HOME to find Java and it doesn't work with Java 17
    # unset JAVA_HOME so it is using java8, which is set by the wrapper script
    unset JAVA_HOME

    # nix-shell sets temp to /run/user/$UID, which will not have enough space.
    unset TMP TEMP TMPDIR TEMPDIR

    # We have patched the update URL so include the updater app.
    export OFFICIAL_BUILD=true
    DEVICE=redfin
    BUILD_ID=SQ1A.211205.008
  '';

  removeByBaseName = nameToRemove: with builtins; filter (x: baseNameOf x != nameToRemove);
  assertSomeRemoved = before: f: let after = f before; in
    with builtins; assert pkgs.lib.assertMsg (length before > length after)
      ("We wanted to remove " ++ nameToRemove ++ " but list isn't shorter: " ++ toJSON { inherit before after; });
    after;
  removeByBaseNameStrict = nameToRemove: xs: assertSomeRemoved xs (removeByBaseName nameToRemove);
  traceBaseNames = xs: with builtins; pkgs.lib.traceSeq (map baseNameOf xs);
  libcNoPatch = pkgs.glibc.overrideAttrs (x:
  #traceBaseNames x.patches
  {
    patches = removeByBaseNameStrict "dont-use-system-ld-so-preload.patch" (removeByBaseNameStrict "dont-use-system-ld-so-cache.patch" x.patches);
    #buildPhase = ''
    #  make csu/objects
    #  make subdir=elf -C ../glibc-2.32/elf ..=../ objdir=`pwd` `pwd`/elf/ld.so
    #  -> ld.so seems to need libc_pic.a so we probably cannot save much.
    #'';
  });

  # nix-shell shell.nix --run gos-interactive
  # nix-shell shell.nix --run "gos-interactive -c some-command"
  enterInteractiveScript = pkgs.writeShellScriptBin "gos-interactive" ''
    exec gos-build-env --init-file ${pkgs.writeShellScript "init-gos" ''
      # This is run instead of .bashrc so include it.
      [ -e ~/.bashrc ] && source ~/.bash_rc

      source script/envsetup.sh
      choosecombo release redfin user
      DEVICE=redfin
      BUILD_ID=SQ1A.211205.008

      echo "You can now run commands like: m target-files-package"
    ''} "$@"
  '';
in pkgs.mkShell {
  buildInputs = deps pkgs ++ [ fhs enterInteractiveScript ];

  shellHook = shellHookBase + ''
    if [ "''${0##*/}" != "rc" ] ; then
      echo "==========================================="
      echo "== Run   gos-build-env                   =="
      echo "== Then  source script/envsetup.sh       =="
      echo "== Then  choosecombo release redfin user =="
      echo "==========================================="
      echo '(use `nix-shell shell.nix --run gos-interactive` to automatically do this)'
    else
      : command has been passed to shell -> do not print anything
    fi
  '';

  # This goes directly into the chrootenv (which is what we want) but I don't
  # think that there is any way to pass a command to it.
  # The command is only available in /tmp/nix-shell-bla/rc and that file is
  # already deleted when our shellHook runs so I don't think we have any way
  # to pass this information through an exec call.
  passthru.env = fhs.env;
  passthru.libcNoPatch = libcNoPatch;
}
