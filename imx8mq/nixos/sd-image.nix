{ config, lib, pkgs, ... }:
{
  imports = [
    ../../common/nixos/installer.nix
  ];

  sdImage = {
    ubootPackage = pkgs.ubootReformImx8mq;
    dd = {
      bs = "1k";
      seek = "33";
    };
  };
}
