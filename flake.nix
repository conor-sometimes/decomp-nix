# Flake wrapper over default.nix (which stays the real definition, for non-flake users).
#   nix build github:conor-sometimes/decomp-nix#ghidra-ps2
#   nix develop github:conor-sometimes/decomp-nix#bokura-no-kazoku     # interactive shell in a project's env
#   nix run github:conor-sometimes/decomp-nix#bokura-no-kazoku -- -c 'make'   # one command in it
# (an FHS env's devShell is interactive only and ignores --command; use nix run for commands)
# flake.lock is the only nixpkgs pin; default.nix reads it too. Bump: nix flake update.
{
  description = "Nix packages for matching decompilations: build environments, toolchains, Ghidra per console";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (pkgs) lib;
      d = import ./default.nix { inherit pkgs; };
      # Everything is defined once, in default.nix; the flake only re-exposes it.
      projects = lib.filterAttrs (_: v: v ? env) d;                 # attrs with an env = projects
      envs = lib.mapAttrs (_: p: p.env) projects;
      # package sets (ghidra.ps2, ee-gcc.ee-gcc2_96, ...) flattened to ghidra-ps2, ee-gcc2_96, ...
      nested = lib.concatMapAttrs (n: set:
        lib.mapAttrs' (k: v: lib.nameValuePair (if lib.hasPrefix n k then k else "${n}-${k}") v)
          (lib.filterAttrs (_: lib.isDerivation) set))
        (lib.filterAttrs (n: v: builtins.isAttrs v && !(lib.isDerivation v) && !(v ? env) && n != "lib") d);
      tools = lib.filterAttrs (_: lib.isDerivation) d;
    in
    {
      lib = d.lib;

      packages.${system} = tools // nested // envs;

      # `nix develop .#<project>`: interactive shell in that project's FHS environment
      devShells.${system} = lib.mapAttrs (_: e: e.env) envs;

      # `nix run .#<project> -- -c 'cmd'`: run a command in it (what scripts should use)
      apps.${system} = lib.mapAttrs (n: e: {
        type = "app";
        program = "${e}/bin/${e.name}";
        meta.description = "Run a command in the ${n} decomp environment (${e.name} -c 'cmd')";
      }) envs;
    };
}
