{ lib, config, pkgs, ... }@args:
let
  overlay = final: prev:
  {
    linux_reformA311d_latest = prev.callPackage ./kernel.nix { kernelPatches = [ ]; };
    linuxPackages_reformA311d_latest = final.linuxPackagesFor final.linux_reformA311d_latest;
    ubootReformA311d = prev.callPackage ./uboot { };
  };
in
{
  imports = [
    ../common/nixos
    ../common/boot.nix
  ];

  nixpkgs.overlays = [ overlay ];

  boot = {
    kernelParams = [
      "console=ttyAML0,115200"
      "console=tty1"
      "pci=pcie_bus_perf"
      "libata.force=noncq"
      "nvme_core.default_ps_max_latency_us=0"
    ];
    kernelPackages = lib.mkDefault pkgs.linuxPackages_reformA311d_latest;
    initrd.kernelModules = [
      "pwm_imx27"
      "nwl-dsi"
      "ti-sn65dsi86"
      "imx-dcss"
      "panel-edp"
      "panel-jdi-lt070me05000"
      "mux-mmio"
      "mxsfb"
      "usbhid"
      "meson_dw_hdmi"
      "meson_dw_mipi_dsi"
      "meson_canvas"
      "meson_drm"
      "dw_hdmi_i2s_audio"
      "dw_mipi_dsi"
      "meson_dw_mipi_dsi"
      "meson_vdec"
      "ao_cec_g12a"
      "panfrost"
      "snd_soc_meson_g12a_tohdmitx"
      "dw_hdmi_i2s_audio"
      "cec"
      "snd_soc_hdmi_codec"
      "snd_soc_meson_codec_glue"
      "snd_soc_meson_axg_toddr"
      "snd_pcm"
      "snd"
      "display_connector"
      "nvme"
    ];
  };
  hardware.deviceTree.name = lib.mkDefault "amlogic/meson-g12b-bananapi-cm4-mnt-reform2.dtb";
}
