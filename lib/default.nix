{ pkgs, tools }:

{
  mkDecompEnv = import ./mkDecompEnv.nix { inherit pkgs tools; };
}
