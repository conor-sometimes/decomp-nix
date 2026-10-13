{ pkgs }:

{
  mkDecompEnv = import ./mkDecompEnv.nix { inherit pkgs; };
}
