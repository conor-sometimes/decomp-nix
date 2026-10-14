# decomp-nix

Nix packages for matching decompilation projects: build environments and toolchains,
declared once and cached, instead of per-machine setup scripts, containers or distroboxes.

| Project | Platform | Nix file | What's here |
| --- | --- | --- | --- |
| [Lombyte](https://github.com/lombyte-project/Lombyte) (Ratchet & Clank) | PS2 | [projects/lombyte/default.nix](projects/lombyte/default.nix) | `lombyte.env`: build environment (Wine for the SN tools) |
| Bokura no Kazoku (private decomp) | PS2 | [projects/bokura-no-kazoku/default.nix](projects/bokura-no-kazoku/default.nix) | `bokura-no-kazoku.env`: PS2 env; its compiler, EE-GCC 2.96 (-O2 -G0 -fno-strict-aliasing), is `$DECOMP_COMPILERS/ee-gcc2.96` |
| Crash Bash (private decomp) | PS1 | [projects/crash-bash/default.nix](projects/crash-bash/default.nix) | `crash-bash.env`: PS1 env (Psy-Q GCC 2.8.1, maspsx, mipsel binutils, just, uv) |

## Tools

| Package | Command | What it is |
| --- | --- | --- |
| `ghidra.ps2` | `ghidra-ps2` | Ghidra 12.0.4 + [ghidra-emotionengine-reloaded](https://github.com/chaoticgd/ghidra-emotionengine-reloaded) (EE processor, STABS) |
| `ghidra.ps1` | `ghidra-ps1` | Ghidra 12.0.4 + [ghidra_psx_ldr](https://github.com/lab313ru/ghidra_psx_ldr) (PS-X EXE, GTE, Psy-Q signatures and types) |
| `objdiff` | `objdiff-cli` | per-function object diffs and progress reports; in every env |
| `binutils-mips-ps2` | `mips-ps2-decompals-*` | R5900-aware binutils (as, ld, objcopy, objdump, ...); in PS2 envs |
| (nixpkgs) | `spatch` | Coccinelle, type-aware renames across C; in every env |
| `rename-field` | `rename-field STRUCT OLD NEW [PATH...]` | IDA-style field rename: only where the type really is that struct (Coccinelle); prints what it couldn't reach (macro args, unparseable code) |
| `ccc` | `stdump`, `uncc`, `demangle` | PS2 symbol tables: STABS/ELF/SNDLL types and signatures, skeleton sources, GCC 2.x demangling; in PS2 envs |
| `decomp-guard` | `decomp-guard install` / `check` | pre-commit hook that refuses game data (extensions, boot-executable names, ELF/PS-X EXE/ISO/ROM bytes, generated paths, big binaries); plain bash, also runs without Nix; in every env |
| `perm-lines` | `perm-lines SRC --cc CMD --symbol NAME --target-elf ELF --addr A` | statement-order brute force for MIPS, C or C++ (decomp-permuter is C only): reorders the lines marked `//@p`, compiles in parallel, reads objects without objdump, hill-climbs on swaps past 5040 orders and prints the closest order; in every env |
| `old-gcc.*` | (folders) | old console GCCs from decompals/old-gcc, e.g. `old-gcc.gcc-2_8_1-psx` |
| `ee-gcc.*` | (folders) | Sony EE-GCC builds from decomp.me's mirror (2.96, 2.9-991111/-01/a, 2.9-990721, 3.2-040921), under `$DECOMP_COMPILERS` in PS2 envs |
| `maspsx` | `maspsx` | Psy-Q assembler behaviour for GNU as (PS1) |
| `asm-differ` | `asm-differ` | quick per-function terminal diffs (diff.py) |
| `binutils-mipsel` | `mipsel-linux-gnu-*` | little-endian MIPS binutils (PS1) |

`ghidra-<platform> analyze BINARY OUTDIR` runs headless: import, auto-analysis, then
`OUTDIR/functions.json` (every function), `OUTDIR/symbol_addrs.txt` (named ones, splat format)
and the Ghidra project. Defined in [pkgs/ghidra/default.nix](pkgs/ghidra/default.nix); more
platforms (N64, GameCube/Wii, NDS, GBA) once their extensions build for nixpkgs' Ghidra.

PS1 projects use [lib/platforms/ps1.nix](lib/platforms/ps1.nix) (`lib.platforms.ps1.mkEnv`): mipsel
binutils, maspsx, asm-differ, ghidra-ps1, just and uv, plus the old PS1 compilers as folders under
`$DECOMP_COMPILERS` (gcc-2.8.1-psx, ...; link a project's `tools/<name>` there).

PS2 projects use [lib/platforms/ps2.nix](lib/platforms/ps2.nix) (`lib.platforms.ps2.mkEnv`): the
shared base plus the same PS2 toolbox everywhere (binutils-mips-ps2, ccc, ghidra-ps2, and the EE-GCC builds under `$DECOMP_COMPILERS`).

Every project builds on [lib/mkDecompEnv.nix](lib/mkDecompEnv.nix) (the shared base: gcc
multilib, the tools to build old compilers, ninja, Python with decomp-permuter's packages).

## Use (flake)

    nix run github:conor-sometimes/decomp-nix#bokura-no-kazoku -- -c 'make'   # a command in an env
    nix develop github:conor-sometimes/decomp-nix#crash-bash                  # an interactive shell in it
    nix build github:conor-sometimes/decomp-nix#ghidra-ps2                    # any tool

`flake.lock` is the one nixpkgs pin (default.nix reads it too; bump with `nix flake update`). [flake.nix](flake.nix) re-exposes default.nix and lists nothing by hand: add a package or project to default.nix and it appears in the flake.

## Use (without flakes)

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

## Licence

Licensed under the GNU General Public License v3.0 or later (see [LICENSE](LICENSE)). The packages only fetch upstream tools and compilers from their own release pages; each keeps its own licence.
