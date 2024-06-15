{ stdenv, lib, config, pkgs, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:
(pkgs.callPackage ../common/kernel {
  inherit kernelPatches;
  version = "6.1.93";
  hash = "sha256-3zGvLvWSPWH63Wi/2ZH1Dy5CqROJXrSwMhTuePhyC88=";
}).forSoc "imx8mq-mnt-reform2" "0x40480000"
