# Nix packages for matching decompilations. Non-flake entry point:
#   nix-build -A lombyte.env          # or: nix-shell -A lombyte.env.env
#   (import (fetchTarball ".../archive/<rev>.tar.gz") { inherit pkgs; }).lombyte.env
{ pkgs ? import <nixpkgs> { } }:

let
  lib = import ./lib { inherit pkgs; };
in
{
  inherit lib;
  lombyte = import ./projects/lombyte { inherit pkgs lib; };
  bokura-no-kazoku = import ./projects/bokura-no-kazoku { inherit pkgs lib; };
}
