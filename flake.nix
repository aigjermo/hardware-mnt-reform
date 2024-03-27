{
  description =
    "NixOS hardware configuration and bootable image for the MNT Reform";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

  outputs = { self, nixpkgs }:
    let
      latestKernel = "6.7.10";
      kernelBranch = (nixpkgs.lib.versions.majorVersion latestKernel) + "." + (nixpkgs.lib.versions.minorVersion latestKernel);
      nixpkgs' = nixpkgs.legacyPackages.aarch64-linux;
      asound-state = "/var/lib/alsa/asound.state";
      alsa-state-daemon-conf = "/etc/alsa/state-daemon.conf";
    in {
      overlay = final: prev:
        {
          linux = prev.callPackage ./kernel/linux-stable.nix {
            kernelPatches = [
              final.kernelPatches.bridge_stp_helper
              final.kernelPatches.request_key_helper
            ];
          };

          linux_reformImx8mq_latest =
            prev.callPackage
              (import ./kernel { version=kernelBranch; module="imx8mq-mnt-reform2"; })
              { kernelPatches = [ ]; };

          linuxPackages_reformImx8mq_latest =
            final.linuxPackagesFor final.linux_reformImx8mq_latest;

          linux_reformA311d_latest =
            prev.callPackage
              (import ./kernel { version=kernelBranch; module="meson-g12b-bananapi-cm4-mnt-reform2"; })
              { kernelPatches = [ ]; };

          linuxPackages_reformA311d_latest =
            final.linuxPackagesFor final.linux_reformA311d_latest;
            

          ubootReformImx8mq = prev.callPackage ./imx8mq/uboot { };
          ubootReformA311d = prev.callPackage ./a311d/uboot { };

          reformFirmware = prev.callPackages ./firmware.nix {
            avrStdenv = prev.pkgsCross.avr.stdenv;
            armEmbeddedStdenv = prev.pkgsCross.arm-embedded.stdenv;
          };
        };

      legacyPackages.aarch64-linux = nixpkgs'.extend self.overlay;

        
      nixosModule = { dtb, kernelPkg }: { config, lib, pkgs, ... }:
        {
          boot = {

            kernelPackages = lib.mkDefault kernelPkg;

            # Kernel params and modules are chosen to match the original System
            # image (v3).
            # See [gentoo wiki](https://wiki.gentoo.org/wiki/MNT_Reform#u-boot).
            kernelParams = [
              "console=ttymxc0,115200"
              "console=tty1"
              "pci=nomsi"
              "cma=512M"
              "no_console_suspend"
              "ro"
            ];

            # The module load order is significant, It is derived from this
            # custom script from the official system image:
            # https://source.mnt.re/reform/reform-tools/-/blob/c189f5ebb166d61c5f17c15a3c94fdb871cfb5c2/initramfs-tools/reform
            initrd.kernelModules = [
              # imx8mq-mnt-reform2
              "pwm_imx27"
              "nwl-dsi"
              "ti-sn65dsi86"
              "imx-dcss"
              "panel-edp"
              "mux-mmio"
              "mxsfb"
              "usbhid"
              "imx8mq-interconnect"
              # meson-g12b-bananapi-cm4-mnt-reform2
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
              "snd_soc_meson_g12a_tohdmimix"
              "dw_hdmi_i2s_audio"
              "cec"
              "snd_soc_hdmi_codec"
              "snd_soc_meson_codec_glue"
              "snd_soc_meson_axg_toddr"
              "snd_pcm"
              "snd"
              "display_connector"
              # ls1028a
              "cdns_mhdp_imx"
              "cdns_mhdp_drmcore"
              "mali_dp"

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

            loader = {
              generic-extlinux-compatible.enable = lib.mkDefault true;
              grub.enable = lib.mkDefault false;
              timeout = lib.mkDefault 2;
            };
            supportedFilesystems = lib.mkForce [ "vfat" "f2fs" "ntfs" "cifs" ];
          };

          boot.kernel.sysctl."vm.swappiness" = lib.mkDefault 1;

          environment.etc."systemd/system.conf".text =
            "DefaultTimeoutStopSec=15s";

          environment.systemPackages = with pkgs; [ alsa-utils brightnessctl usbutils ];

          hardware.deviceTree.name = lib.mkDefault dtb;

          hardware.pulseaudio.daemon.config.default-sample-rate =
            lib.mkDefault "48000";

          nixpkgs = {
            system = "aarch64-linux";
            overlays = [ self.overlay ];
          };

          programs.sway.extraPackages = # unbloat
            lib.mkDefault (with pkgs; [ swaylock swayidle xwayland ]);

          services.fstrim.enable = lib.mkDefault true;

          system.activationScripts.asound = ''
            if [ ! -e "/var/lib/alsa/asound.state" ]; then
              mkdir -p /var/lib/alsa
              cp ${./initial-asound.state} /var/lib/alsa/asound.state
            fi
          '';

          services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", ATTRS{id}=="wm8960audio", ENV{PULSE_PROFILE_SET}="reform.conf"
          ACTION=="add", SUBSYSTEM=="sound", KERNEL=="controlC*", KERNELS!="card*", TEST="${pkgs.alsa-utils}", TEST="${asound-state}, GOTO="alsa_restore_go", GOTO="alsa_restore_end"

          LABEL="alsa_restore_go"
          TEST!="${alsa-state-daemon-conf}",RUN+="${pkgs.alsa-utils}/bin/alsactl restore $attr{device/number}"
          TEST=="${alsa-state-daemon-conf}",RUN+="${pkgs.alsa-utils}/bin/alsactl nrestore $attr{device/number}"

          LABEL="alsa_restore_end"
          '';

          systemd.services.alsa-restore = {
            description="Save and restore ALSA mixer state";
            unitConfig = {
              ConditionPathExists = "!${alsa-state-daemon-conf}";
              ConditionPathExistsGlob = "/dev/snd/control*";
            };
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "-${pkgs.alsa-utils}/bin/alsactl -d -f ${asound-state} restore";
              ExecStop = "-${pkgs.alsa-utils}/bin/alsactl -d -f ${asound-state} store";
            };
          };
          systemd.services.alsa-state = {
            description="Save and restore ALSA mixer state while respecting ${alsa-state-daemon-conf})";
            unitConfig = {
              ConditionPathExists = "${alsa-state-daemon-conf}";
              ConditionPathExistsGlob = "/dev/snd/control*";
            };
            serviceConfig = {
              Type = "simple";
              ExecStart = "-${pkgs.alsa-utils}/bin/alsactl -d -s -n 19 -c rdaemon";
              ExecStop = "-${pkgs.alsa-utils}/bin/alsactl -d -s kill save_and_quit";
            };
          };

          environment.etc."pulse/reform.conf".text = ''
          [General]
          auto-profiles = yes

          [Mapping stereo-out]
          device-strings = hw:%f
          fallback = yes
          channel-map = left,right
          paths-output = analog-output analog-output-speaker analog-output-headphones
          direction = output
          priority = 1

          [Mapping headset-mono-in]
          device-strings = hw:%f
          fallback = yes
          channel-map = mono
          paths-input = analog-input-reform
          direction = input
          priority = 1

          [Profile output:stereo-out+input:mono-in]
          description = MNT Reform
          output-mappings = stereo-out
          input-mappings = headset-mono-in
          '';

          environment.etc."pulse/analog-input-reform.conf".text = ''
          # This file is part of PulseAudio.
          #
          # PulseAudio is free software; you can redistribute it and/or modify
          # it under the terms of the GNU Lesser General Public License as
          # published by the Free Software Foundation; either version 2.1 of the
          # License, or (at your option) any later version.
          #
          # PulseAudio is distributed in the hope that it will be useful, but
          # WITHOUT ANY WARRANTY; without even the implied warranty of
          # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
          # General Public License for more details.
          #
          # You should have received a copy of the GNU Lesser General Public License
          # along with PulseAudio; if not, see <http://www.gnu.org/licenses/>.

          ; Analog input path for MNT Reform, which has a headset mic input
          ; that is only on the left channel (mono).

          [General]
          priority = 100

          [Element Capture]
          switch = mute
          volume = ignore

          [Element Mic]
          required-absent = any

          [Element Mic Boost]
          required-absent = any

          [Element Dock Mic]
          required-absent = any

          [Element Dock Mic Boost]
          required-absent = any

          [Element Front Mic]
          required-absent = any

          [Element Front Mic Boost]
          required-absent = any

          [Element Int Mic]
          required-absent = any

          [Element Int Mic Boost]
          required-absent = any

          [Element Internal Mic]
          required-absent = any

          [Element Internal Mic Boost]
          required-absent = any

          [Element Rear Mic]
          required-absent = any

          [Element Rear Mic Boost]
          required-absent = any

          [Element Headset]
          required-absent = any

          [Element Headset Mic]
          required-absent = any

          [Element Headset Mic Boost]
          required-absent = any

          [Element Headphone Mic]
          required-absent = any

          [Element Headphone Mic Boost]
          required-absent = any

          [Element Line]
          required-absent = any

          [Element Line Boost]
          required-absent = any

          [Element Aux]
          required-absent = any

          [Element Video]
          required-absent = any

          [Element Mic/Line]
          required-absent = any

          [Element TV Tuner]
          required-absent = any

          [Element FM]
          required-absent = any

          .include analog-input.conf.common
          '';
        };

      packages.aarch64-linux = 
      let
        installer = {dtb, ubootPkg, kernelPkg}: nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            (self.nixosModule { inherit dtb kernelPkg; })
            (import ./nixos/installer.nix { inherit ubootPkg; })
          ];
        };

        installers = {
          a311d = installer {
            dtb = "amlogic/meson-g12b-bananapi-cm4-mnt-reform2.dtb";
            kernelPkg = self.legacyPackages.aarch64-linux.linuxPackages_reformA311d_latest;
            ubootPkg = self.legacyPackages.aarch64-linux.ubootReformA311d;
          };
          imx8mq = installer {
            dtb = "freescale/imx8mq-mnt-reform2.dtb";
            kernelPkgs = self.legacyPackages.aarch64-linux.linuxPackages_reformImx8mq_latest;
            ubootPkg = self.legacyPackages.aarch64-linux.ubootReformImx8mq;
          };
        };
      in
      {
        imx8mq = {
          inherit (installers.imx8mq.config.system.build) initialRamdisk kernel sdImage;
        };
        a311d = {
          inherit (installers.a311d.config.system.build) initialRamdisk kernel sdImage;
        };
      } // self.legacyPackages.aarch64-linux.reformFirmware;

      defaultPackage.aarch64-linux = builtins.abort ''
        
        Please specify a Reform module and build target!

        Examples:
        - nix build .#imx8mq.sdImage
        - nix build .#a311d.sdImage
      '';
    };
}
