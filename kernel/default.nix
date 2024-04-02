{ version, module }:
{ stdenv, lib, buildLinux, fetchurl, fetchgit, linux, kernelPatches, ... }@args:

let
  inherit linux;
  reformKernel = fetchgit {
    url = "https://source.mnt.re/reform/reform-debian-packages.git";
    rev = "0698154c5cfeae0fa44454c9bcdcd1aa57f4d0f0";
    hash = "sha256-83TxrJws4YgUEEqvMZzphpIsK5g21AY8Hss7K4h4Ssc=";
  } + "/linux";
  version = "6.7";
  module = "meson-g12b-bananapi-cm4-mnt-reform2";
in lib.overrideDerivation (buildLinux (args // {
  inherit (linux) src version;

  features = {
    efiBootStub = false;
    iwlwifi = false;
  } // (args.features or { });

  kernelPatches = let
    patches = lib.filesystem.listFilesRecursive "${reformKernel}/patches${version}/${module}";
    reformPatches = map (patch: { inherit patch; name=patch; }) patches;
  in lib.lists.unique (kernelPatches ++ reformPatches ++ [
    {
      name = "MNT-Reform-imx8mq-config-upstream";
      patch = null;
    }
  ]);

  extraConfig = builtins.readFile ./kernel-config;
  #enableParallelBuilding = true;
  #ignoreConfigErrors = true;
  #autoModules = false;
  #kernelPreferBuiltin = true;
  allowImportFromDerivation = true;

} // (args.argsOverride or { }))) (attrs: {
  postPatch = attrs.postPatch + ''
    cp ${reformKernel}/fsl-ls1028*.dts arch/arm64/boot/dts/freescale/
    cp ${reformKernel}/imx8m*.dts arch/arm64/boot/dts/freescale/
    cp ${reformKernel}/meson*.dts arch/arm64/boot/dts/amlogic/
    sed -i '/fsl-ls1028a-rdb.dtb/a dtb-$(CONFIG_ARCH_LAYERSCAPE) += fsl-ls1028a-mnt-reform2.dtb' arch/arm64/boot/dts/freescale/Makefile
    sed -i '/imx8mq-mnt-reform2.dtb/a dtb-$(CONFIG_ARCH_MXC) += imx8mq-mnt-reform2-hdmi.dtb' arch/arm64/boot/dts/freescale/Makefile

    #   DTC     arch/arm64/boot/dts/freescale/imx8mp-mnt-pocket-reform.dtb
    # Error: ../arch/arm64/boot/dts/freescale/imx8mp-mnt-pocket-reform.dts:799.1-8 Label or path lcdif3 not found
    # Error: ../arch/arm64/boot/dts/freescale/imx8mp-mnt-pocket-reform.dts:803.1-10 Label or path hdmi_pvi not found
    # Error: ../arch/arm64/boot/dts/freescale/imx8mp-mnt-pocket-reform.dts:807.1-9 Label or path hdmi_tx not found
    # Error: ../arch/arm64/boot/dts/freescale/imx8mp-mnt-pocket-reform.dts:813.1-13 Label or path hdmi_tx_phy not found
    # FATAL ERROR: Syntax error parsing input tree 

    # Commenting out the sed line below due to the errors above.
    #sed -i '/imx8mq-mnt-reform2.dtb/a dtb-$(CONFIG_ARCH_MXC) += imx8mp-mnt-pocket-reform.dtb' arch/arm64/boot/dts/freescale/Makefile
  #sed -i 's/CONFIG_BACKLIGHT_PWM=./CONFIG_BACKLIGHT_PWM=y/' arch/arm64/configs/defconfig
  #sed -i 's/CONFIG_BACKLIGHT_LP855X=./CONFIG_BACKLIGHT_LP855X=y/' arch/arm64/configs/defconfig
  #echo "CONFIG_BACKLIGHT_CLASS_DEVICE=y" >> arch/arm64/configs/defconfig
  '';
  postConfig = ''
   Avoid "Repeated Question" errors
  sed -i 's/BACKLIGHT_CLASS_DEVICE=./BACKLIGHT_CLASS_DEVICE=y/' .config
  sed -i 's/DRM_PANEL_JDI_LT070ME05000=./DRM_PANEL_JDI_LT070ME05000=y/' .config
  sed -i 's/DWMAC_MESON=./DWMAC_MESON=y/' .config
  echo "Post-config done!"
  '';
  #makeFlags = attrs.makeFlags ++ [ "LOADADDR=0x40480000" ];
  makeFlags = attrs.makeFlags ++ [ "LOADADDR=0x1000000" ];
})
