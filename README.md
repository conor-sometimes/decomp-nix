# decomp-nix

Nix packages for matching decompilation projects: build environments and toolchains,
declared once and cached, instead of per-machine setup scripts, containers or distroboxes.

| Project | Platform | What's here |
| --- | --- | --- |
| [Lombyte](https://github.com/lombyte-project/Lombyte) (Ratchet & Clank) | PS2 | `lombyte.env`: build environment (FHS env, Wine, gcc multilib, Python) |

## Use

From a project clone:

    nix-shell -A lombyte.env.env /path/to/decomp-nix     # or: nix-build -A lombyte.env

On NixOS, add the package to `environment.systemPackages`:

    (import (fetchTarball "https://github.com/conor-sometimes/decomp-nix/archive/<rev>.tar.gz")
      { inherit pkgs; }).lombyte.env

## Rules

- No game data, no copyrighted binaries: only Nix expressions with upstream URLs and
  SHA-256 pins, the same downloads each project's own setup scripts make.
- Toolchain pins follow each project's own pins exactly; a pin-check flags drift.
- x86_64-linux (the PS1/PS2 toolchains are x86 Linux and Windows binaries).

## Layout

    default.nix         entry point (non-flake)
    lib/mkDecompEnv.nix the common environment base every project builds on
    pkgs/               shared decomp tools (permuter, m2c, ...)
    projects/<name>/    one project's environment and toolchain

## Adding a project

    # projects/<name>/default.nix
    { pkgs, lib }:
    {
      env = lib.mkDecompEnv {
        name = "<name>";             # -> a <name>-env command
        wine = false;                # true if a compiler or assembler is a Windows .exe
        packages = p: [ ];           # anything else the build needs
      };
    }

then one line in default.nix: `<name> = import ./projects/<name> { inherit pkgs lib; };`
