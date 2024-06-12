{ lib, config, pkgs, versions, ... }@args:
let
  overlay = final: prev:
  {
    linux_reformImx8mq_latest = prev.callPackage ./kernel.nix { kernelPatches = [ ]; };
    linuxPackages_reformImx8mq_latest = final.linuxPackagesFor final.linux_reformImx8mq_latest;
    ubootReformImx8mq = prev.callPackage ./uboot { };
  };
in
{
  imports = [
    ../common/nixos
    ../common/boot.nix
  ];

  nixpkgs.overlays = [ overlay ];

  boot = {
    # Kernel params and modules are chosen to match the original System image (v3).
    # See [gentoo wiki](https://wiki.gentoo.org/wiki/MNT_Reform#u-boot).
    kernelPackages = lib.mkDefault pkgs.linuxPackages_reformImx8mq_latest;
    kernelParams = [
      "ro"
      "no_console_suspend"
      "earlycon=ec_imx6q,0x30860000,115200"
      "cma=512M"
      "pci=nomsi"
      "console=ttymxc0,115200"
      "console=tty1"
    ];
    initrd.kernelModules = [
      "nwl-dsi"
      "imx-dcss"
      "reset_imx7"
      "mux_mmio"
      "fixed"
      "i2c-imx"
      "fan53555"
      "i2c_mux_pca954x"
      "pwm_imx27"
      "pwm_bl"
      "panel_edp"
      "ti_sn65dsi86"
      "phy-fsl-imx8-mipi-dphy"
      "mxsfb"
      "usbhid"
      "imx8mq-interconnect"
      "nvme"
    ];
    # hack to remove ATA modules
    initrd.availableKernelModules = lib.mkForce ([
      "cryptd"
      "dm_crypt"
      "dm_mod"
      "input_leds"
      "mmc_block"
      "nvme"
      "usbhid"
      "xhci_hcd"
    ] ++ config.boot.initrd.luks.cryptoModules);
  };
  hardware.deviceTree.name = lib.mkDefault "freescale/imx8mq-mnt-reform2.dtb";
}
