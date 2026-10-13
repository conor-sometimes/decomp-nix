# decomp-nix

Nix packages for matching decompilation projects: build environments and toolchains,
declared once and cached, instead of per-machine setup scripts, containers or distroboxes.

| Project | Platform | Nix file | What's here |
| --- | --- | --- | --- |
| [Lombyte](https://github.com/lombyte-project/Lombyte) (Ratchet & Clank) | PS2 | [projects/lombyte/default.nix](projects/lombyte/default.nix) | `lombyte.env`: build environment (Wine for the SN tools) |
| Bokura no Kazoku (private decomp) | PS2 | [projects/bokura-no-kazoku/default.nix](projects/bokura-no-kazoku/default.nix) | `bokura-no-kazoku.env`: build environment (no Wine) |

## Tools

| Package | Command | What it is |
| --- | --- | --- |
| `ghidra.ps2` | `ghidra-ps2` | Ghidra 12.0.4 + [ghidra-emotionengine-reloaded](https://github.com/chaoticgd/ghidra-emotionengine-reloaded) (EE processor, STABS) |
| `ghidra.ps1` | `ghidra-ps1` | Ghidra 12.0.4 + [ghidra_psx_ldr](https://github.com/lab313ru/ghidra_psx_ldr) (PS-X EXE, GTE, Psy-Q signatures and types) |

`ghidra-<platform> analyze BINARY OUTDIR` runs headless: import, auto-analysis, then
`OUTDIR/functions.json` (every function), `OUTDIR/symbol_addrs.txt` (named ones, splat format)
and the Ghidra project. Defined in [pkgs/ghidra/default.nix](pkgs/ghidra/default.nix); more
platforms (N64, GameCube/Wii, NDS, GBA) once their extensions build for nixpkgs' Ghidra.

Every project builds on [lib/mkDecompEnv.nix](lib/mkDecompEnv.nix) (the shared base: gcc
multilib, the tools to build old compilers, ninja, Python with decomp-permuter's packages).

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

    default.nix         entry point (non-flake): [default.nix](default.nix)
    lib/mkDecompEnv.nix the common environment base every project builds on: [lib/](lib/)
    pkgs/               shared decomp tools (ghidra-<platform>, ...)
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
