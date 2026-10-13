# PS2 platform: the same toolbox in every PS2 decomp's environment, so a fix or upgrade lands in
# all of them at once.
#
#   platforms.ps2.mkEnv { name = "bokura"; }               # plus any mkDecompEnv option
#
# Adds to the shared base: R5900-aware binutils (mips-ps2-decompals-*), ccc (stdump, uncc,
# demangle), ghidra-ps2 (Ghidra + the Emotion Engine extension, `ghidra-ps2 analyze`), and the
# Sony EE-GCC builds as folders under $DECOMP_COMPILERS (ee-gcc2.96, ee-gcc2.9-991111, ...):
# link a project's tools/compilers/<name> to $DECOMP_COMPILERS/<name>.
{ mkDecompEnv, tools, pkgs }:

let
  ps2Tools = [ tools.binutils-mips-ps2 tools.ccc tools.ghidra.ps2 ];
  compilers = pkgs.symlinkJoin {
    name = "ps2-compilers";
    paths = builtins.attrValues tools.ee-gcc;
  };
in
{
  tools = ps2Tools;
  inherit compilers;
  mkEnv = args@{ packages ? (p: [ ]), profile ? "", ... }:
    mkDecompEnv (args // {
      packages = p: ps2Tools ++ packages p;
      profile = ''
        export DECOMP_COMPILERS=${compilers}
      '' + profile;
    });
}
