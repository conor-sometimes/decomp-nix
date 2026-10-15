# Bokura no Kazoku (PS2, Japan, SCPS-15088, 2005). No Windows tools, so no Wine. Toolchains, set
# per unit in the decomp's Makefile (all under $DECOMP_COMPILERS):
#   game C++ units and dklib     EE-GCC 2.96, -O2 -G0 -fno-strict-aliasing -fno-exceptions, -Wa,-g
#   C-style game units           the same without -Wa,-g
#   part of dklib (IPU, MPEG)    ee-gcc 2.9-991111, C++, -O2 -G0 -fno-exceptions, 2.96's as (-B)
#   Sony SDK libraries           ee-gcc 2.9-991111-01, -x c -O2 -G0, 2.96's as (-B)
#   newlib libm                  EE-GCC 2.96
#
#   bokura-env                      # a shell
#   bokura-env -c 'make'            # one command, from inside the decomp repo
{ pkgs, lib, tools }:

{
  env = lib.platforms.ps2.mkEnv {
    name = "bokura";
  };
}
