{ lib, stdenv, buildPackages, fetchurl, perl, buildLinux, modDirVersionArg ? null, ... } @ args:

with lib;

buildLinux (args // rec {
  version = "6.1.59";

  # modDirVersion needs to be x.y.z, will automatically add .0 if needed
  majorVersion = lib.head (splitVersion version);
  modDirVersion = if (modDirVersionArg == null) then concatStringsSep "." (take 3 (splitVersion "${version}.0")) else modDirVersionArg;

  # branchVersion needs to be x.y
  extraMeta.branch = versions.majorMinor version;

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v${majorVersion}.x/linux-${version}.tar.xz";
    #sha256 = "sha256-iqj2T6YLsTOBqWCNH++90FVeKnDECyx9BnGw1kqkVZ4="; # 6.1.4
    sha256 = "sha256-Yn93JMZ1A2Y5KQ+1w54/3rPVZrgLGSxF9KgIq1TIwKA="; # 6.1.59
  };
} // (args.argsOverride or {}))
