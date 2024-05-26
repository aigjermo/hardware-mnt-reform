{ stdenv, lib, config, buildLinux, fetchurl, fetchgit, linux, kernelPatches, modDirVersionArg ? null, version ? "6.6.32", hash ? "sha256-qqgk6vB/YZEdIrdf8JCkA8PdC9c+I5M+C7qLWXFDbOE=", ... }@args:
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

  reformKernel = fetchgit {
    url = "https://source.mnt.re/reform/reform-debian-packages.git";
    rev = "0698154c5cfeae0fa44454c9bcdcd1aa57f4d0f0";
    hash = "sha256-83TxrJws4YgUEEqvMZzphpIsK5g21AY8Hss7K4h4Ssc=";
  } + "/linux";
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
      patches = if branch == "6.1" then
          lib.filesystem.listFilesRecursive "${reformKernel}/patches${branch}"
        else
          lib.filesystem.listFilesRecursive "${reformKernel}/patches${branch}/${soc}";
      reformPatches = map (patch: { inherit patch; name=patch; }) patches;
    in lib.lists.unique (kernelPatches ++ reformPatches);
    features = {
      efiBootStub = false;
      iwlwifi = false;
    } // (args.features or { });

    extraConfig = builtins.readFile ./kernel-config;
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
