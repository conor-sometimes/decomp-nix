# PS2 platform: the same toolbox in every PS2 decomp's environment, so a fix or upgrade lands in
# all of them at once.
#
#   platforms.ps2.mkEnv { name = "bokura"; }               # plus any mkDecompEnv option
#
# Adds to the shared base: R5900-aware binutils (mips-ps2-decompals-*), ccc (stdump, uncc,
# demangle), ghidra-ps2 (Ghidra + the Emotion Engine extension, `ghidra-ps2 analyze`), and the
# Sony EE-GCC builds as folders under $DECOMP_COMPILERS (ee-gcc2.96, ee-gcc2.9-991111, ...):
# link a project's tools/compilers/<name> to $DECOMP_COMPILERS/<name>; compiler-sweep (try a
# function against every one of them, C and C++, with/without `as -g`, with each other's as);
# vgmstream-cli (Sony XWB/ADS/VAG... audio to WAV, for exploring a disc's sound banks).
#
# PS2 matching notes (Bokura no Kazoku, 2026-10):
# - One game can mix toolchains: the game code in EE-GCC 2.96 with `-Wa,-g` (GNU as then stops
#   moving instructions into delay slots: retail `jal f; nop` where it could have filled the slot),
#   C-style code without it, Sony SDK libraries in ee-gcc 2.9-991111 or -01, sometimes assembled by
#   2.96's as (`-B <2.96>/ee/bin/`). Set flags per unit in the Makefile; compiler-sweep finds them.
# - GNU as 2.10 (in the EE-GCC builds) can assemble a `lui` as a copy of the following `lw`,
#   depending on where the function lands: a C function that matched alone fails after an
#   unrelated change earlier in the file. `asm(".p2align 3");` right before the function (it is
#   8-aligned anyway, so it emits nothing) fixes it.
{ mkPlatform, tools, pkgs }:

let
  # decomp-permuter scores by disassembling the target with `mips-linux-gnu-objdump -drz -m mips:4300`.
  # Provide that name, backed by the R5900 PS2 binutils (translate the generic mips:4300 -> mips:5900).
  permuterObjdump = pkgs.writeShellScriptBin "mips-linux-gnu-objdump" ''
    args=()
    for a in "$@"; do [ "$a" = mips:4300 ] && a=mips:5900; args+=("$a"); done
    exec ${tools.binutils-mips-ps2}/bin/mips-ps2-decompals-objdump "''${args[@]}"
  '';
  ps2Tools = [ tools.binutils-mips-ps2 tools.ccc tools.ghidra.ps2 permuterObjdump
               tools.compiler-sweep pkgs.vgmstream ];
  compilers = pkgs.symlinkJoin {
    name = "ps2-compilers";
    paths = builtins.attrValues tools.ee-gcc;
  };
in
mkPlatform {
  tools = ps2Tools;
  inherit compilers;
}
