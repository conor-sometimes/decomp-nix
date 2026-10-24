# Fat Princess: Fistful of Cake (PSP, USA, UCUS-98740, Redump 8076e844...). C++; the toolchain is
# likely SN Systems SNC (.cplinit sections, "EDG gcc 3.4 mode"), unconfirmed until leaf functions
# match. SNC is a Windows executable, hence wine.
#
#   fat-princess-env -c 'pspdecrypt -o BOOT.ELF EBOOT.BIN'
{ pkgs, lib, tools }:

{
  env = lib.platforms.psp.mkEnv {
    name = "fat-princess";
    wine = true;
  };
}
