{ lib, stdenv, buildPackages, fetchurl, perl, buildLinux, modDirVersionArg ? null, ... } @ args:

with lib;

buildLinux (args // rec {
  version = "6.7.10";

  # modDirVersion needs to be x.y.z, will automatically add .0 if needed
  majorVersion = lib.head (splitVersion version);
  modDirVersion = if (modDirVersionArg == null) then concatStringsSep "." (take 3 (splitVersion "${version}.0")) else modDirVersionArg;

  # branchVersion needs to be x.y
  extraMeta.branch = versions.majorMinor version;

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v${majorVersion}.x/linux-${version}.tar.xz";
    hash = "sha256-qbmfs3b5/NaZx8JSru87tbomKA6wSXEawJGy6ytIfAM=";
  };
} // (args.argsOverride or {}))
