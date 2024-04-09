{ lib, pkgs, buildUBoot, fetchgit, fetchFromGitHub, ... }:
let
  reform = pkgs.callPackage ./reform.nix {};
in
buildUBoot rec {
  version = "2024-04-08";
  src = fetchFromGitHub {
    owner = "u-boot";
    repo = "u-boot";
    rev = "v2024.04";
    sha256 = "sha256-IlaDdjKq/Pq2orzcU959h93WXRZfvKBGDO/MFw9mZMg=";
  };
  defconfig = "bananapi-cm4-mnt-reform2_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];
  filesToInstall = [ "u-boot.bin" ];
  makeFlags = filesToInstall;

  patches = [
    "${reform}/0000-dts-makefile.patch"
    "${reform}/0001-usb-hub-reset.patch"
  ];

  postUnpack = ''
    cp ${reform}/*.dts source/arch/arm/dts/
    cp ${reform}/*_defconfig source/configs/
  '';
}
