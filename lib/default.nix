{ pkgs, tools }:

let
  mkDecompEnv = import ./mkDecompEnv.nix { inherit pkgs tools; };
in
{
  inherit mkDecompEnv;
  platforms = {
    ps2 = import ./platforms/ps2.nix { inherit mkDecompEnv tools; };
  };
}
