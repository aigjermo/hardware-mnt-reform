{ stdenv, lib, buildLinux, fetchurl, fetchgit, linux_6_1, kernelPatches, ... }@args:

let
  linux = linux_6_1;
  reformKernel = fetchgit {
    url = "https://source.mnt.re/reform/reform-debian-packages.git";
    rev = "f5d832b5056644177dd0f1ec22bc8000f327a59d";
    sha256 = "sha256-gpekrGKD/dpDNPA2rOzEnM1wcFP14bgk7Dpqe6B/tAM=";
  } + "/linux";
in lib.overrideDerivation (buildLinux (args // {
  inherit (linux) src version;

  features = {
    efiBootStub = false;
    iwlwifi = false;
  } // (args.features or { });

  kernelPatches = let
    patches = lib.filesystem.listFilesRecursive "${reformKernel}/patches6.1";
    reformPatches = map (patch: { inherit patch; }) patches;
  in lib.lists.unique (kernelPatches ++ reformPatches ++ [
    {
      name = "MNT-Reform-imx8mq-config-upstream";
      patch = null;
      extraConfig = builtins.readFile ./kernel-config;
    }
  ]);

  allowImportFromDerivation = true;

} // (args.argsOverride or { }))) (attrs: {
  postPatch = attrs.postPatch + ''
    cp ${reformKernel}/*.dts arch/arm64/boot/dts/freescale/
    echo 'dtb-$(CONFIG_ARCH_MXC) += imx8mq-mnt-reform2.dtb imx8mq-mnt-reform2-hdmi.dtb' >> \
      arch/arm64/boot/dts/freescale/Makefile
  '';
  makeFlags = attrs.makeFlags ++ [ "LOADADDR=0x40480000" ];
})
