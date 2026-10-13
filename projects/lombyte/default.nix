# Lombyte (Ratchet & Clank, PS2) build environment: an FHS environment (a bubblewrap namespace
# with the /usr/lib layout prebuilt Linux binaries expect) with everything Lombyte's setup.sh
# wants from an Ubuntu box, plus Wine for the SN compiler and the permuter's Python packages.
#
#   lombyte-env                     # a shell
#   lombyte-env -c 'make elf'       # one command, from inside a Lombyte clone
#
# The PS2 compilers are still installed per clone by Lombyte's setup.sh (pinned by SHA-256), so
# byte matching never depends on nixpkgs versions. Packaging them here is the next step.
{ pkgs }:

{
  env = pkgs.buildFHSEnv {
    name = "lombyte-env";
    targetPkgs = p: with p; [
      bashInteractive coreutils findutils gnugrep gnused gawk diffutils patch which file
      curl git gnumake gnutar gzip xz unzip
      gcc_multi binutils   # gcc -m32: setup.sh's 32-bit check and the game compiler's source build
      flex bison m4 perl texinfo
      ninja
      (python3.withPackages (ps: with ps; [ pycparser toml levenshtein ]))  # setup.sh's venv base; decomp-permuter
      wineWow64Packages.stable   # the SN compiler and assembler are Windows executables
    ];
    # 32-bit runtime for the prebuilt PS2 compilers (glibc comes with the FHS base)
    multiPkgs = p: with p; [ stdenv.cc.cc.lib zlib ];
    profile = ''
      export WINEDEBUG=-all
    '';
    runScript = "bash";
  };
}
