let
  configuration = {
    device = "redfin";
    flavor = "grapheneos";
  };
  robotnix = import ./robotnix { inherit configuration; };
in robotnix.img
