{ fetchgit, pkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "reform-a311d-uboot-patches";
  version = "2024-04-08";
  src = fetchgit {
    url = "https://source.mnt.re/reform/reform-a311d-uboot.git";
    rev = "dc3f62b194f1562faea3b41fd3a47645d1e647f5";
    sha256 = "sha256-ARS0e6kd0a6zXcQr4Qdy0TG07lEUFFB5k8txnHCsX90=";
  };
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir $out
    cp * $out/
  '';
}
