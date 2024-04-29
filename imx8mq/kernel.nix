{ stdenv, lib, config, pkgs, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:
(pkgs.callPackage ../common/kernel {
  inherit kernelPatches;
  version = "6.1.89";
  hash = "sha256-Erq44JJhjR1O6vQgHm5wBUyUiWGYlWvYT/DpCLAmRxk=";
}).forSoc "imx8mq-mnt-reform2" "0x40480000"
