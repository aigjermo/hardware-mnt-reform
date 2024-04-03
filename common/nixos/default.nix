{ config, lib, pkgs, ... }:
let
  asound-state = "/var/lib/alsa/asound.state";
  alsa-state-daemon-conf = "/etc/alsa/state-daemon.conf";
  overlay = final: prev:
    {
  #    linux = prev.callPackage ../kernel/linux-stable.nix {
  #      kernelPatches = [
  #        final.kernelPatches.bridge_stp_helper
  #        final.kernelPatches.request_key_helper
  #      ];
  #    };

      reformFirmware = prev.callPackages ../firmware.nix {
        avrStdenv = prev.pkgsCross.avr.stdenv;
        armEmbeddedStdenv = prev.pkgsCross.arm-embedded.stdenv;
      };
    };
in
{
  nixpkgs = {
    system = "aarch64-linux";
    overlays = [ overlay ];
  };

  environment.etc."systemd/system.conf".text =
    "DefaultTimeoutStopSec=15s";

  environment.systemPackages = with pkgs; [ alsa-utils brightnessctl usbutils ];

  hardware.pulseaudio.daemon.config.default-sample-rate =
    lib.mkDefault "48000";

  programs.sway.extraPackages = # unbloat
    lib.mkDefault (with pkgs; [ swaylock swayidle xwayland ]);

  services.fstrim.enable = lib.mkDefault true;

  system.activationScripts.asound = ''
    if [ ! -e "/var/lib/alsa/asound.state" ]; then
      mkdir -p /var/lib/alsa
      cp ${../initial-asound.state} /var/lib/alsa/asound.state
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
}
