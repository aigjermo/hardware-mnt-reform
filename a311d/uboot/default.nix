{ lib, pkgs, buildUBoot, fetchFromGitHub, ... }:
let
  uboot = pkgs.callPackage ./uboot.nix {};
in
pkgs.stdenv.mkDerivation rec {
  pname = "reform-a311d-uboot";
  version = "2024-04-08";
  src = fetchFromGitHub {
    owner = "libreelec";
    repo = "amlogic-boot-fip";
    rev = "0312a79cc65bf7bb3d66d33ad0660b66146bd36d";
    sha256 = "sha256-6EIXP1g9LPYNz5jYYrY7PKeVbwSI3DeJBo5ZK17ePMg=";
  };
  buildInputs = [ pkgs.qemu ];

  postUnpack = ''
    mkdir source/mnt-reform2-a311d
  '';

  buildPhase = ''
    patchShebangs bananapi-cm4io/*.sh
    ./build-fip.sh bananapi-cm4io ${uboot}/u-boot.bin mnt-reform2-a311d
  '';

  installPhase = ''
    mkdir $out
    cp mnt-reform2-a311d/u-boot.bin.sd.bin $out/flash.bin
    dd if=/dev/zero of=$out/flash.bin bs=512 count=1 conv=notrunc
    printf @AML | cmp --bytes=4 --ignore-initial=0:528 - $out/flash.bin
    printf MNTREFORMAMLBOOT | dd of=$out/flash.bin bs=512 conv=notrunc seek=1
    printf @AML | cmp --bytes=4 --ignore-initial=0:492048 - $out/flash.bin
    printf MNTREFORMAMLBOOT | dd of=$out/flash.bin bs=512 conv=notrunc seek=961
  '';
}
