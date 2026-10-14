# mkDecompEnv: the common base of a matching-decomp build environment, as an FHS environment
# (a bubblewrap namespace with the /usr/lib layout prebuilt Linux binaries expect).
#
#   mkDecompEnv { name = "lombyte"; wine = true; }      # -> a `lombyte-env` command
#
# A project's Python venv (.venv) must be created and used inside its env: it points at the env's
# python, which only exists there.
#
# The base covers what decomp toolchains usually need: gcc with 32-bit support, the tools to build
# old compilers from source, ninja, and Python with decomp-permuter's packages. A project adds
# only what's special about it.
{ pkgs, tools }:

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
  multiArch = true;   # include the 32-bit (i686) side: without it multiPkgs and /lib/ld-linux.so.2 are missing
  targetPkgs = p: with p; [
    bashInteractive coreutils findutils gnugrep gnused gawk diffutils patch which file
    curl git gnumake gnutar gzip xz unzip
    xxd                  # hex dumps (Bokura PoC feedback)
    gcc_multi binutils   # gcc -m32: 32-bit tools and old compilers built from source
    flex bison m4 perl texinfo
    ninja
    zstd                 # libzstd.so.1 for the decompals binutils
    tools.objdiff        # objdiff-cli: per-function diffs and the progress report, in every env
    coccinelle           # spatch: type-aware renames across C (a field of one struct, not every same-named field)
    tools.rename-field   # rename-field STRUCT OLD NEW: Coccinelle-based struct field rename
    tools.decomp-guard   # decomp-guard install: pre-commit hook that refuses game data
    tools.rank-functions # rank-functions: unmatched functions, easiest first
    tools.perm-lines # perm-lines: statement-order brute force (C or C++), parallel
    tools.progress-readme # progress-readme README.md ...: the progress section at the top of a README
    (python3.withPackages (ps: with ps; [ pycparser toml levenshtein ] ++ pythonPackages ps))  # decomp-permuter
  ] ++ pkgs.lib.optional wine p.wineWow64Packages.stable
    ++ packages p;
  # 32-bit runtime for prebuilt i386 compilers (glibc comes with the FHS base)
  multiPkgs = p: with p; [ stdenv.cc.cc.lib zlib zstd ] ++ multiPackages p;
  profile = pkgs.lib.optionalString wine ''
    export WINEDEBUG=-all
  '' + profile;
  runScript = "bash";
}
