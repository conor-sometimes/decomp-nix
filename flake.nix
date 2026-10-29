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
      projects = d.projects;   # every project env: { name; run; shell; image; runtime }
      # package sets (ghidra.ps2, ee-gcc.ee-gcc2_96, ...) flattened to ghidra-ps2, ee-gcc2_96, ...
      nested = lib.concatMapAttrs (n: set:
        lib.mapAttrs' (k: v: lib.nameValuePair (if lib.hasPrefix n k then k else "${n}-${k}") v)
          (lib.filterAttrs (_: lib.isDerivation) set))
        (lib.filterAttrs (n: v: builtins.isAttrs v && !(lib.isDerivation v) && n != "lib" && n != "projects") d);
      tools = lib.filterAttrs (_: lib.isDerivation) d;

      # One shape for every project, whatever its runtime: `.run` is the command runner, `.shell`
      # the interactive env (null for container projects), `.image` the OCI image (null for fhs).
      projRun    = lib.mapAttrs (_: p: p.run) projects;
      projImages = lib.concatMapAttrs (n: p: lib.optionalAttrs (p.image != null) { "${n}-image" = p.image; }) projects;
      projShells = lib.mapAttrs (_: p: p.shell) (lib.filterAttrs (_: p: p.shell != null) projects);
      projApps   = lib.mapAttrs (n: p: {
        type = "app";
        program = "${p.run}/bin/${p.run.name}";
        meta.description = "Run a command in the ${n} ${p.runtime} project env (-- -c 'cmd')";
      }) projects;
    in
    {
      lib = d.lib;

      # tools + flattened tool sets + every project's runner (+ <name>-image for container projects)
      packages.${system} = tools // nested // projRun // projImages;

      # `nix develop .#<project>`: interactive shell (fhs project envs; container projects have none)
      devShells.${system} = projShells;

      # `nix run .#<project> -- -c 'cmd'`: run a command in any project env, identical across runtimes
      apps.${system} = projApps;
    };
}
