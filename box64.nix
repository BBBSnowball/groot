{ pkgs ? import <nixpkgs> {} }:
let
in pkgs.stdenv.mkDerivation {
  pname = "box64";
  version = "0.1.6-2021-12-22";
  src = pkgs.fetchFromGitHub {
    owner = "ptitSeb";
    repo  = "box64";
    rev   = "fbb534917a028aaae2dd6b79900425dbe5617112";
    sha256 = "sha256-uLULTQPL+btHPQv9azLyFcVLCV0NRHMUmmbXbNVNUcI=";
  };

  nativeBuildInputs = with pkgs; [ cmake python3 ];

  cmakeFlags = [ "-DARM_DYNAREC=ON" "-DCMAKE_BUILD_TYPE=RelWithDebInfo" ];

  postPatch = ''
    sed -i 's?DESTINATION /?DESTINATION ''${CMAKE_INSTALL_PREFIX}/?' CMakeLists.txt
  '';
}
