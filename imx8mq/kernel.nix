{ stdenv, lib, config, pkgs, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:
(pkgs.callPackage ../common/kernel {
  inherit kernelPatches;
  version = "6.1.87";
  hash = "sha256-/HrxanLoruR5C3lvG/UAPLDeYJXqH/19fHyaVnjZUSQ=";
}).forSoc "imx8mq-mnt-reform2" "0x40480000"
