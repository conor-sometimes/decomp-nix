# Flake wrapper over default.nix (which stays the real definition, for non-flake users).
#   nix build github:conor-sometimes/decomp-nix#ghidra-ps2
#   nix develop github:conor-sometimes/decomp-nix#bokura-no-kazoku     # interactive shell in a project's env
#   nix run github:conor-sometimes/decomp-nix#bokura-no-kazoku -- -c 'make'   # one command in it
# (an FHS env's devShell is interactive only and ignores --command; use nix run for commands)
# nixpkgs here and in nixpkgs.json must name the same commit (flake.lock adds the content hash).
{
  description = "Nix packages for matching decompilations: build environments, toolchains, Ghidra per console";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/7993f34ee47e28a3d607a525aadc6c94b73be728";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (pkgs) lib;
      d = import ./default.nix { inherit pkgs; };
      projects = { inherit (d) lombyte bokura-no-kazoku crash-bash; };
      envs = lib.mapAttrs (_: p: p.env) projects;
      compilers = lib.concatMapAttrs (_: set: set) { inherit (d) old-gcc ee-gcc; };
    in
    {
      lib = d.lib;

      packages.${system} = envs // compilers // {
        inherit (d) objdiff binutils-mips-ps2 binutils-mipsel rename-field ccc decomp-guard maspsx asm-differ;
        ghidra-ps2 = d.ghidra.ps2;
        ghidra-ps1 = d.ghidra.ps1;
      };

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
