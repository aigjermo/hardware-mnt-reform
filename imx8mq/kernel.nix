{ stdenv, lib, config, pkgs, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:
(pkgs.callPackage ../common/kernel {
  inherit kernelPatches;
  version = "6.1.92";
  hash = "sha256-kBn0J7/cnO1byVTXYNN6wIwM3/tFrSgIf8Rac+ZDNsk=";
}).forSoc "imx8mq-mnt-reform2" "0x40480000"
