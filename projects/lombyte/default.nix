# Lombyte (Ratchet & Clank, PS2). Its PS2 compilers are installed per clone by Lombyte's
# setup.sh (pinned by SHA-256); the SN compiler and assembler are Windows executables.
#
#   lombyte-env                     # a shell
#   lombyte-env -c 'make elf'       # one command, from inside a Lombyte clone
{ pkgs, lib, tools }:

{
  env = lib.platforms.ps2.mkEnv {
    name = "lombyte";
    wine = true;
  };
}
