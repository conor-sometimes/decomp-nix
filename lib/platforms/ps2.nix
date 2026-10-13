# PS2 platform: the same toolbox in every PS2 decomp's environment, so a fix or upgrade lands in
# all of them at once.
#
#   platforms.ps2.mkEnv { name = "bokura"; }               # plus any mkDecompEnv option
#
# Adds to the shared base: R5900-aware binutils (mips-ps2-decompals-*), ccc (stdump, uncc,
# demangle), and ghidra-ps2 (Ghidra + the Emotion Engine extension, `ghidra-ps2 analyze`).
{ mkDecompEnv, tools }:

let
  ps2Tools = [ tools.binutils-mips-ps2 tools.ccc tools.ghidra.ps2 ];
in
{
  tools = ps2Tools;
  mkEnv = args@{ packages ? (p: [ ]), ... }:
    mkDecompEnv (args // { packages = p: ps2Tools ++ packages p; });
}
