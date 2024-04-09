{ config, lib, pkgs, ... }:
{
  imports = [
    ../../common/nixos/installer.nix
  ];

  sdImage = {
    ubootPackage = pkgs.ubootReformA311d;
    dd = {
      bs = "512";
      seek = "1";
      skip = "1";
    };
  };
}
