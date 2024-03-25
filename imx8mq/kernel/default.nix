{ stdenv, lib, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:

let
  inherit linux;
  reformKernel = fetchgit {
    url = "https://source.mnt.re/reform/reform-debian-packages.git";
    rev = "d4bbc527b264a4cc7fefb20ee2459c84a2154c3c";
    sha256 = "sha256-tOZbZv/qN2MHMVqJK3hKVWGfhHytOT3IWNsGkNh7sAE=";
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
