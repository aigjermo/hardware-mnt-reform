{ buildUBoot, fetchgit }:

buildUBoot rec {
  pname = "uboot-reform2-imx8mq";
  version = "2023-10-18";
  src = fetchgit {
    url = "https://source.mnt.re/reform/reform-boundary-uboot.git";
    rev = version;
    sha256 = "sha256-IVUEN0uxfveiOgWCobOQrQvWHPbVSueb/m743GtsOwQ=";
  };
  defconfig = "nitrogen8m_som_4g_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];
  filesToInstall = [ "flash.bin" ];
  patches = [
    ./reform-ramdisk-addr.patch
  ];
  configurePhase = "cp mntreform-config .config";
  makeFlags = filesToInstall;
}
