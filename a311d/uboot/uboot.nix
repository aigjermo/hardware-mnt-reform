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

  postBuild = ''
    #make -j$(nproc) #TODO: Don't use all cores unless asked!
    #env --chdir=../fip ./build-fip.sh bananapi-cm4io ../u-boot/u-boot.bin mnt-reform2-a311d
    #cp fip/mnt-reform2-a311d/u-boot.bin.sd.bin $out/flash.bin
    #dd if=/dev/zero of=$out/flash.bin bs=512 count=1 conv=notrunc
    #printf @AML | cmp --bytes=4 --ignore-initial=0:528 - $out/flash.bin
    #printf MNTREFORMAMLBOOT | dd of=$out/flash.bin bs=512 conv=notrunc seek=1
    #printf @AML | cmp --bytes=4 --ignore-initial=0:492048 - $out/flash.bin
    #printf MNTREFORMAMLBOOT | dd of=$out/flash.bin bs=512 conv=notrunc seek=961
  '';
}
