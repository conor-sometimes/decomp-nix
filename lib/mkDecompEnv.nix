# mkDecompEnv: the common base of a matching-decomp build environment, as an FHS environment
# (a bubblewrap namespace with the /usr/lib layout prebuilt Linux binaries expect).
#
#   mkDecompEnv { name = "lombyte"; wine = true; }      # -> a `lombyte-env` command
#
# The base covers what decomp toolchains usually need: gcc with 32-bit support, the tools to build
# old compilers from source, ninja, and Python with decomp-permuter's packages. A project adds
# only what's special about it.
{ pkgs }:

{
  name,
  wine ? false,                # Windows-only compilers or assemblers (Wine, wow64 mode)
  packages ? (p: [ ]),         # extra packages for the environment
  multiPackages ? (p: [ ]),    # extra libraries needed in both 64- and 32-bit form
  pythonPackages ? (ps: [ ]),  # extra Python packages
  profile ? "",                # extra shell setup
}:

pkgs.buildFHSEnv {
  name = "${name}-env";
  targetPkgs = p: with p; [
    bashInteractive coreutils findutils gnugrep gnused gawk diffutils patch which file
    curl git gnumake gnutar gzip xz unzip
    gcc_multi binutils   # gcc -m32: 32-bit tools and old compilers built from source
    flex bison m4 perl texinfo
    ninja
    (python3.withPackages (ps: with ps; [ pycparser toml levenshtein ] ++ pythonPackages ps))  # decomp-permuter
  ] ++ pkgs.lib.optional wine p.wineWow64Packages.stable
    ++ packages p;
  # 32-bit runtime for prebuilt i386 compilers (glibc comes with the FHS base)
  multiPkgs = p: with p; [ stdenv.cc.cc.lib zlib ] ++ multiPackages p;
  profile = pkgs.lib.optionalString wine ''
    export WINEDEBUG=-all
  '' + profile;
  runScript = "bash";
}
