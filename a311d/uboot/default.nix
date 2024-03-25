# Keep it simple for now and just pull the uboot binary from mnt.re
# Would be nice to actually build from source, but that's a task for a hypothetical future where I have more time.
{ pkgs }:
let
  pname = "reform-a311d-uboot";
  version = "2023-10-18";
in
pkgs.stdenv.mkDerivation {
  inherit pname version;
  src = pkgs.fetchurl {
    url = "https://source.mnt.re/reform/"+pname+"/-/jobs/artifacts/${version}/raw/flash.bin?job=build";
    hash = "sha256-u5Ta3eACYHTs9bYx55buNShqGShGvZAruucBX32Rt8E=";
  };
  dontUnpack = true;
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir $out
    cp $src $out/flash.bin
  '';
}
