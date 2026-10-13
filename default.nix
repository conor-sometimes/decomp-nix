# Nix packages for matching decompilations. Non-flake entry point:
#   nix-build -A lombyte.env          # or: nix-shell -A lombyte.env.env
#   (import (fetchTarball ".../archive/<rev>.tar.gz") { }).lombyte.env
#
# Builds use the nixpkgs pinned in flake.lock (the one pin, shared with flake.nix), not the
# caller's channel: tool versions (Ghidra and its extensions above all) must match exactly.
# Bump with `nix flake update`. Passing your own `pkgs` overrides the pin, at your own risk.
let
  locked = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
  pinned = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  }) { };
in
{ pkgs ? pinned }:

let
  tools = {
    objdiff = import ./pkgs/objdiff { inherit pkgs; };
    binutils-mips-ps2 = import ./pkgs/binutils-mips-ps2 { inherit pkgs; };
    rename-field = import ./pkgs/rename-field { inherit pkgs; };
    ccc = import ./pkgs/ccc { inherit pkgs; };
    decomp-guard = import ./pkgs/decomp-guard { inherit pkgs; };
    old-gcc = import ./pkgs/old-gcc { inherit pkgs; };   # old-gcc.gcc-2_8_1-psx, ...
    ee-gcc = import ./pkgs/ee-gcc { inherit pkgs; };     # ee-gcc.ee-gcc2_96, ... (PS2)
    maspsx = import ./pkgs/maspsx { inherit pkgs; };
    asm-differ = import ./pkgs/asm-differ { inherit pkgs; };
    binutils-mipsel = import ./pkgs/binutils-mipsel { inherit pkgs; };
    ghidra = import ./pkgs/ghidra { inherit pkgs; };   # ghidra.ps2, ghidra.ps1
  };
  lib = import ./lib { inherit pkgs tools; };
in
{
  inherit lib;
  inherit (tools) objdiff binutils-mips-ps2 rename-field ccc ghidra decomp-guard old-gcc ee-gcc maspsx asm-differ binutils-mipsel;
  lombyte = import ./projects/lombyte { inherit pkgs lib tools; };
  bokura-no-kazoku = import ./projects/bokura-no-kazoku { inherit pkgs lib tools; };
  crash-bash = import ./projects/crash-bash { inherit pkgs lib tools; };
}
