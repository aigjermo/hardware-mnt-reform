{ stdenv, lib, config, pkgs, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:
(pkgs.callPackage ../common/kernel {
  inherit kernelPatches;
  version = "6.1.84";
  hash = "sha256-r5fS6+FHZdDbOvZWAwna8IU12iW/rTbl+z5DbyKhcHo=";
}).forSoc "imx8mq-mnt-reform2" "0x40480000"
