{ stdenv, lib, config, pkgs, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:
(pkgs.callPackage ../common/kernel { inherit kernelPatches; }).forSoc "meson-g12b-bananapi-cm4-mnt-reform2" "0x1000000"
