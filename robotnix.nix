let
  fileExists = name: builtins.getDir ./. ? name;
  private = if fileExists "private.nix" then source ./private.nix else {};
  myDomain = private.domain or "groot.example.com";
  configuration = {
    imports = [ ./keys-metadata/metadata.nix ];
    device = "redfin";
    flavor = "grapheneos";
    apps.fdroid.enable = true;
    apps.seedvault.enable = true;
    signing.enable = true;
    #signing.keyStorePath = "/nope";
    #signing.keyStoreUseDummy = true;
    apps.updater.enable = true;
    apps.updater.url = "https://${myDomain}/ota/";
    #signing.avb.fingerprint = "26ce01f78fb5361aa4a5e5f0b1b7e290cf83944fa9bdd5f7e95afc8aa1f1fc26";
    #apps.prebuilt."Auditor".fingerprint = "F68296AFE8C9B06AA69AD6EB4B1A222460FE8AE343AC3ADB910CDA5650FDF100";
    #apps.prebuilt."vanadium".fingerprint = "F68296AFE8C9B06AA69AD6EB4B1A222460FE8AE343AC3ADB910CDA5650FDF100";
    #apps.prebuilt."F-Droid".fingerprint = "F68296AFE8C9B06AA69AD6EB4B1A222460FE8AE343AC3ADB910CDA5650FDF100";
    #apps.prebuilt.asdf.fingerprint = "asdf";
    apps.auditor.enable = true;
    apps.auditor.domain = "attestation.${myDomain}";
  };
  robotnix = import ./robotnix { inherit configuration; };
in {
  inherit (robotnix)
    #factoryImg
    releaseScript
    generateKeysScript
    generateKeysInfo
    generateKeysShell
    keyTools
    config;
  inherit (robotnix.config.build)
    otaTools;
}
