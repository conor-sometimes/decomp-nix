# Nix packages for matching decompilations. Non-flake entry point:
#   nix-build -A lombyte.env          # or: nix-shell -A lombyte.env.env
#   (import (fetchTarball ".../archive/<rev>.tar.gz") { inherit pkgs; }).lombyte.env
{ pkgs ? import <nixpkgs> { } }:

let
  tools = {
    objdiff = import ./pkgs/objdiff { inherit pkgs; };
    binutils-mips-ps2 = import ./pkgs/binutils-mips-ps2 { inherit pkgs; };
  };
  lib = import ./lib { inherit pkgs tools; };
in
{
  inherit lib;
  inherit (tools) objdiff binutils-mips-ps2;
  ghidra = import ./pkgs/ghidra { inherit pkgs; };   # ghidra.ps2, ghidra.ps1
  lombyte = import ./projects/lombyte { inherit pkgs lib tools; };
  bokura-no-kazoku = import ./projects/bokura-no-kazoku { inherit pkgs lib tools; };
}
