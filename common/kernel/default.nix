{ stdenv, lib, buildLinux, fetchurl, fetchgit, kernelPatches, modDirVersionArg ? null, version ? "6.6.33", hash ? "sha256-oT68INwqdXImmZSa90qoakzl1UTW2qpqfeToyBtA3pc=", ... }@args:
let
  branch = lib.versions.majorMinor version;

  linux = with lib; buildLinux (args // rec {
    inherit version;

    # modDirVersion needs to be x.y.z, will automatically add .0 if needed
    majorVersion = lib.head (splitVersion version);
    modDirVersion = if (modDirVersionArg == null) then concatStringsSep "." (take 3 (splitVersion "${version}.0")) else modDirVersionArg;

    # branchVersion needs to be x.y
    extraMeta.branch = branch;

    src = fetchurl {
      inherit hash;
      url = "mirror://kernel/linux/kernel/v${majorVersion}.x/linux-${version}.tar.xz";
    };
  } // (args.argsOverride or {}));

  reformKernel = stdenv.mkDerivation {
    name = "reform-debian-packages-patches";
    src = fetchgit {
      url = "https://source.mnt.re/reform/reform-debian-packages.git";
      rev = "b7826966eee3453a33fb66d85cb279987080f53f";
      hash = "sha256-ODK72WwZ1JzQF+hM2qG80UdDGUrr5C9OnxvTrOgBaD8=";
    };
    dontConfigure = true;
    dontBuild = true;
    postUnpack = ''
      cd reform-debian-packages*
      # Remove patch added in 6.6.33
      sed -i "908,954d" linux/patches${branch}/meson-g12b-bananapi-cm4-mnt-reform2/0000-v9_20231124_neil_armstrong_drm_meson_add_support_for_mipi_dsi_display.patch
      cd ..
    '';
    installPhase = ''
      mkdir -p $out
      cp -r linux/patches${branch} $out
      cp linux/*.dts $out/
    '';
  };
in
{
  inherit linux;

  forSoc = soc: loadAddr: lib.overrideDerivation (buildLinux (args // {
    inherit (linux) src version;

    # modDirVersion needs to be x.y.z, will automatically add .0 if needed
    majorVersion = with lib; head (splitVersion version);
    modDirVersion = with lib; if (modDirVersionArg == null) then concatStringsSep "." (take 3 (splitVersion "${version}.0")) else modDirVersionArg;

    # branchVersion needs to be x.y
    extraMeta.branch = branch;
    kernelPatches = let
      patches = lib.filesystem.listFilesRecursive "${reformKernel}/patches${branch}";
      reformPatches = map (patch: { inherit patch; name=patch; }) patches;
    in lib.lists.unique (kernelPatches ++ reformPatches);
    features = {
      efiBootStub = false;
      iwlwifi = false;
    } // (args.features or { });

    structuredExtraConfig = import ./kernel-config.nix { kernel = lib.kernel; };
    #enableParallelBuilding = true;
    #ignoreConfigErrors = true;
    #autoModules = false;
    #kernelPreferBuiltin = true;
    allowImportFromDerivation = true;

  } // (args.argsOverride or { }))) (attrs: {
    makeFlags = attrs.makeFlags ++ [ "LOADADDR=${loadAddr}" ];
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
    '';
  });
}
