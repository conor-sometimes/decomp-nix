{ pkgs, tools }:

let
  mkDecompEnv = import ./mkDecompEnv.nix { inherit pkgs tools; };
  mkPlatform = import ./mkPlatform.nix { inherit mkDecompEnv; };
in
{
  inherit mkDecompEnv;
  platforms = {
    ps2 = import ./platforms/ps2.nix { inherit mkPlatform tools pkgs; };
    ps1 = import ./platforms/ps1.nix { inherit mkPlatform tools pkgs; };
  };
}
