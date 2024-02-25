{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/23.11";
    flake-utils.url = "github:numtide/flake-utils";
    # The new version of cloud-init (23.xx) aborts with all kind of exceptions
    # (e.g. "cloud-init --debug status" -> "AttributeError: 'Namespace' object has no attribute 'action'"
    # and especially the schema validation wants some data source and
    # debug logging doesn't seem to work either.
    # -> Just use the older version (22.xx).
    nixpkgs-cloud-init.url = "github:nixos/nixpkgs/22.11";
  };

  outputs = { self, nixpkgs, flake-utils, nixpkgs-cloud-init }:
  flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    pkgs-cloud-init = nixpkgs-cloud-init.legacyPackages.${system};
  in {
    apps.hcloud-create = { type = "app"; program = "TODO"; };
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [ pkgs-cloud-init.cloud-init hcloud openssl openssh curl netcat ];
    };
  });
}
