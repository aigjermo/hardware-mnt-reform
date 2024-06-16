{ stdenv, lib, config, pkgs, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:
(pkgs.callPackage ../common/kernel {
  inherit kernelPatches;
  #version = "1.2.3";
  #hash = lib.fakeHash;
}).forSoc "imx8mq-mnt-reform2" "0x40480000"
