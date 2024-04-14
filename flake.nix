{
  description =
    "NixOS hardware configuration and bootable image for the MNT Reform";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

  outputs = { self, nixpkgs }:
    let
      nixpkgs' = nixpkgs.legacyPackages.aarch64-linux;

      a311dInstaller = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.a311d.nixosModule
          ./a311d/nixos/sd-image.nix
        ];
      };

      imx8mqInstaller = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.imx8mq.nixosModule
          ./imx8mq/nixos/sd-image.nix
        ];
      };

      overlay = final: prev: {
        linux = (prev.callPackage ./common/kernel.nix {
          kernelPatches = [
            final.kernelPatches.bridge_stp_helper
            final.kernelPatches.request_key_helper
          ];
        }).linux;

        # callPackages is not well-documented. Here's what I found:
        # https://github.com/NixOS/nixpkgs/issues/36354#issuecomment-776859596
        reformFirmware = prev.callPackages ./common/firmware.nix {
          avrStdenv = prev.pkgsCross.avr.stdenv;
          armEmbeddedStdenv = prev.pkgsCross.arm-embedded.stdenv;
        };
      };
    in
    {
      legacyPackages.aarch64-linux = nixpkgs'.extend overlay;

      nixpkgs = {
        system = "aarch64-linux";
        overlays = [ overlay ];
      };

      imx8mq = {
        inherit (imx8mqInstaller.config.system.build) initialRamdisk kernel sdImage;
        nixosModule = import ./imx8mq;
        reform-uboot = nixpkgs'.callPackage ./imx8mq/uboot { };
      };

      a311d = {
        inherit (a311dInstaller.config.system.build) initialRamdisk kernel sdImage;
        nixosModule = import ./a311d;
        reform-uboot = nixpkgs'.callPackage ./a311d/uboot { };
      };

      packages.aarch64-linux = {
        imx8mq = self.imx8mq;
        a311d = self.a311d;
        default = builtins.abort ''
          Please specify a Reform module and build target!

          Examples:
          - nix build .#imx8mq.sdImage
          - nix build .#a311d.sdImage
        '';
      } // self.legacyPackages.aarch64-linux.reformFirmware;
    };
}
