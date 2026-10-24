# PSP platform: the same toolbox in every PSP decomp's environment.
#
#   platforms.psp.mkEnv { name = "fat-princess"; wine = true; }   # plus any mkDecompEnv option
#
# Adds to the shared base: pspdev binutils (psp-as, psp-ld, ...: the only GNU assembler with the
# VFPU), pspdecrypt (retail EBOOT.BIN -> plain ELF/PRX: UMDs zero the plain
# BOOT.BIN), little-endian MIPS binutils (GNU binutils knows the Allegrex since 2.42:
# `as -march=allegrex`, `objdump -m mips:allegrex`), asm-differ, ghidra-psp (Ghidra +
# ghidra-allegrex: Allegrex/VFPU processor, PSP ELF/PRX loader, NID names for imports), 7zz
# (reads a UMD image directly; bsdtar and xorriso can't), just, uv;
# and the PSP compilers as folders under $DECOMP_COMPILERS (pspsnc_1.2.7503.0, mwccpsp_3.0.1_*,
# psp-gcc-*): link a project's tools/compilers/<name> to $DECOMP_COMPILERS/<name>.
#
# PSP notes:
# - Retail executables are relocatable PRX (ELF type 0xffa0) linked at 0 with .rel.* sections:
#   every pointer is relocated, so splitting and a shiftable build start with the data you need.
# - SNC (EDG front end) leaves `.cplinit`/`.linkonce.d` sections and "EDG gcc 3.4 mode" strings,
#   and loads constants with `ori` (GCC uses `addiu`); mwccpsp builds run under wine like SNC.
#   SNC's `-g` changes code generation (one return point, no inlining), so match per unit.
# - Link a PRX at 64 KiB-aligned bases and take them back out of the relocated fields afterwards
#   (as SN's pspprxgen did); rabbitizer's VFPU syntax for vpfxd/vrot isn't gas's: emit those as
#   .word. Worked example: Fat Princess (fat-princess-decomp, tools/prx.py and tools/mkprx.py).
{ mkPlatform, tools, pkgs }:

let
  # decomp-permuter scores by disassembling with `mips-linux-gnu-objdump -drz -m mips:4300`:
  # provide that name, little-endian and Allegrex-aware.
  permuterObjdump = pkgs.writeShellScriptBin "mips-linux-gnu-objdump" ''
    args=()
    for a in "$@"; do [ "$a" = mips:4300 ] && a=mips:allegrex; args+=("$a"); done
    exec ${tools.binutils-mipsel}/bin/mipsel-linux-gnu-objdump "''${args[@]}"
  '';
  compilers = pkgs.symlinkJoin {
    name = "psp-compilers";
    paths = builtins.attrValues tools.psp-compilers;
  };
in
mkPlatform {
  tools = [ tools.binutils-mipsel tools.binutils-allegrex tools.pspdecrypt tools.asm-differ tools.ghidra.psp permuterObjdump
            pkgs._7zz pkgs.just pkgs.uv ];
  inherit compilers;
}
