{ lib, stdenv, buildPackages, fetchurl, perl, buildLinux, modDirVersionArg ? null, ... } @ args:

with lib;

buildLinux (args // rec {
  version = "6.7-rc8";

  # modDirVersion needs to be x.y.z, will automatically add .0 if needed
  majorVersion = lib.head (splitVersion version);
  modDirVersion = if (modDirVersionArg == null) then concatStringsSep "." (take 3 (splitVersion "${version}.0")) else modDirVersionArg;

  # branchVersion needs to be x.y
  extraMeta.branch = versions.majorMinor version;

  src = fetchurl {
    url = "https://git.kernel.org/torvalds/t/linux-${version}.tar.gz";
    sha256 = "sha256-QwbLsbM7L9Z6htmj5Pq6mpVBM5jD2c9XmR7peACgZAo=";
  };
} // (args.argsOverride or {}))
