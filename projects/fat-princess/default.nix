# Fat Princess: Fistful of Cake (PSP, USA, UCUS-98740, Redump 8076e844...). C++, compiled with
# SN Systems SNC 1.2.7503.0 at -O2 (some units -O2 -g), confirmed on 1,344 functions; SNC is a
# Windows executable, hence wine. The decomp repo's `just build` rebuilds the retail PRX
# byte-for-byte with this env (pspdev binutils for the VFPU, splat from its uv.lock).
#
#   fat-princess-env -c 'just build'     # from inside the decomp repo
{ pkgs, lib, tools }:

lib.platforms.psp.mkEnv {
  name = "fat-princess";
  wine = true;
}
