{
  description =
    "NixOS hardware configuration and bootable image for the MNT Reform";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

  outputs = { self, nixpkgs }:
    let
      nixpkgs' = nixpkgs.legacyPackages.aarch64-linux;
    in
    {
      nixpkgs = {
        system = "aarch64-linux";
        overlays = [
          (final: prev: {
            linux = (prev.callPackage ./common/kernel.nix {
              kernelPatches = [
                final.kernelPatches.bridge_stp_helper
                final.kernelPatches.request_key_helper
              ];
            }).linux;
          })
        ];
      };

      imx8mq_nixosModule = import ./imx8mq;
      a311d_nixosModule = import ./a311d;

      packages.aarch64-linux = 
      let
        a311dInstaller = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            self.a311d_nixosModule
            ./a311d/nixos/sd-image.nix
          ];
        };

        imx8mqInstaller = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            self.imx8mq_nixosModule
            ./imx8mq/nixos/sd-image.nix
          ];
        };
      in
      {
        imx8mq = {
          inherit (imx8mqInstaller.config.system.build) initialRamdisk kernel sdImage;
        };

        a311d = {
          inherit (a311dInstaller.config.system.build) initialRamdisk kernel sdImage;
        };

        default = builtins.abort ''
          Please specify a Reform module and build target!

          Examples:
          - nix build .#imx8mq.sdImage
          - nix build .#a311d.sdImage
        '';
      };# // self.legacyPackages.aarch64-linux.reformFirmware;
    };
}
