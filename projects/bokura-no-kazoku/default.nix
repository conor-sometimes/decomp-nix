# Bokura no Kazoku (PS2, Japan, SCPS-15088). C++ built with Sony's EE-GCC (2.9x mangling,
# SDK 2.8 era, 2005); no Windows tools, so no Wine. The compiler itself comes later, once the
# exact version is confirmed on leaf functions.
#
#   bokura-env                      # a shell
#   bokura-env -c 'make'            # one command, from inside the decomp repo
{ pkgs, lib, tools }:

{
  env = lib.mkDecompEnv {
    name = "bokura";
    packages = p: [ tools.binutils-mips-ps2 ];   # mips-ps2-decompals-{as,ld,objcopy,objdump,...}
  };
}
