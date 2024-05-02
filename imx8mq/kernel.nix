{ stdenv, lib, config, pkgs, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:
(pkgs.callPackage ../common/kernel {
  inherit kernelPatches;
  version = "6.1.90";
  hash = "sha256-g6PXLnZPztosH8aKTqa5ElOijaVqaIorYXdrDRl4jh0=";
}).forSoc "imx8mq-mnt-reform2" "0x40480000"
