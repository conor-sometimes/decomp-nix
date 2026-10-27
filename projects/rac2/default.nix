# Ratchet & Clank 2: Going Commando (PS2, USA v1.01 SCUS_972.68; OpenRAC rac2-decomp).
# Same engine family as Lombyte (R&C1). Its C compiler is GNU EE 2.9-ee-991111b, rebuilt from
# public source by the project's own tools/compiler/build.sh (which applies Lombyte's sce-991111b
# patch stack); its assembler and linker are SN ProDG 2.0's Ps2EeAs.exe / ld.exe (32-bit Windows,
# via Wine), supplied by the user (we reuse Lombyte's copies, which hash-match the ones rac2 wants).
#
# The base PS2 env already provides everything the build needs: gcc -m32 (gcc_multi) + binutils to
# build the old compiler from source, flex/bison/m4/texinfo, ninja, curl/git/make/patch, and
# (wine=true) wineWow64 to run the 32-bit SN .exe. The project's Python venv (.venv:
# splat64/spimdisasm/rabbitizer, requirements.txt) is created inside the env.
#
#   rac2-env                                   # a shell in a rac2-decomp clone
#   rac2-env -c 'bash tools/compiler/build.sh' # build the EE-GCC 2.9 compiler once
#   rac2-env -c 'python3 tools/build.py all'   # build + match-check every program
{ pkgs, lib, tools }:

{
  env = lib.platforms.ps2.mkEnv {
    name = "rac2";
    wine = true;
  };
}
