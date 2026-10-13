# PS1 platform: the same toolbox in every PS1 decomp's environment.
#
#   platforms.ps1.mkEnv { name = "crash-bash"; }           # plus any mkDecompEnv option
#
# Adds to the shared base: mipsel binutils (mipsel-linux-gnu-* too), maspsx, asm-differ,
# ghidra-ps1, just, uv; and the old PS1 compilers as folders under $DECOMP_COMPILERS
# (gcc-2.8.1-psx, ...): link a project's tools/<name> to $DECOMP_COMPILERS/<name>.
{ mkDecompEnv, tools, pkgs }:

let
  compilers = pkgs.symlinkJoin {
    name = "ps1-compilers";
    paths = [ tools.old-gcc.gcc-2_8_1-psx ];
  };
  ps1Tools = [ tools.binutils-mipsel tools.maspsx tools.asm-differ tools.ghidra.ps1 pkgs.just pkgs.uv ];
in
{
  tools = ps1Tools;
  inherit compilers;
  mkEnv = args@{ packages ? (p: [ ]), profile ? "", ... }:
    mkDecompEnv (args // {
      packages = p: ps1Tools ++ packages p;
      profile = ''
        export DECOMP_COMPILERS=${compilers}
      '' + profile;
    });
}
