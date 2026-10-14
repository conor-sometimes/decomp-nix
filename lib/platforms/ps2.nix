# PS2 platform: the same toolbox in every PS2 decomp's environment, so a fix or upgrade lands in
# all of them at once.
#
#   platforms.ps2.mkEnv { name = "bokura"; }               # plus any mkDecompEnv option
#
# Adds to the shared base: R5900-aware binutils (mips-ps2-decompals-*), ccc (stdump, uncc,
# demangle), ghidra-ps2 (Ghidra + the Emotion Engine extension, `ghidra-ps2 analyze`), and the
# Sony EE-GCC builds as folders under $DECOMP_COMPILERS (ee-gcc2.96, ee-gcc2.9-991111, ...):
# link a project's tools/compilers/<name> to $DECOMP_COMPILERS/<name>.
{ mkPlatform, tools, pkgs }:

let
  # decomp-permuter scores by disassembling the target with `mips-linux-gnu-objdump -drz -m mips:4300`.
  # Provide that name, backed by the R5900 PS2 binutils (translate the generic mips:4300 -> mips:5900).
  permuterObjdump = pkgs.writeShellScriptBin "mips-linux-gnu-objdump" ''
    args=()
    for a in "$@"; do [ "$a" = mips:4300 ] && a=mips:5900; args+=("$a"); done
    exec ${tools.binutils-mips-ps2}/bin/mips-ps2-decompals-objdump "''${args[@]}"
  '';
  ps2Tools = [ tools.binutils-mips-ps2 tools.ccc tools.ghidra.ps2 permuterObjdump ];
  compilers = pkgs.symlinkJoin {
    name = "ps2-compilers";
    paths = builtins.attrValues tools.ee-gcc;
  };
in
mkPlatform {
  tools = ps2Tools;
  inherit compilers;
}
