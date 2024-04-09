{ lib, pkgs, ... }:
{
  boot = {
    loader = {
      generic-extlinux-compatible.enable = lib.mkDefault true;
      grub.enable = lib.mkDefault false;
      timeout = lib.mkDefault 2;
    };
    supportedFilesystems = lib.mkForce [ "vfat" "f2fs" "ntfs" "cifs" ];
    kernel.sysctl."vm.swappiness" = lib.mkDefault 1;
  };
}
