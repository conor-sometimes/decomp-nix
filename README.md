# decomp-nix

Declarative, reproducible build environments and toolchains for **matching decompilation** — the
whole fragile stack declared once in Nix and cached, instead of per-machine setup scripts,
containers or distroboxes.

Matching decomp needs an exact toolchain: decade-old console compilers (patched 1997 GCCs, Sony
EE-GCC, Psy-Q), Windows-only SDK assemblers run under Wine, and Ghidra with the right processor
module — normally a brittle per-machine install. Here it's one Nix closure: a fresh clone plus one
command is the exact environment a project needs, byte-for-byte. Three real decompilations build
identically from it today — Lombyte (Ratchet & Clank, PS2), Bokura no Kazoku (PS2) and Crash Bash
(PS1) — and because every environment is a Nix derivation, a change that leaves the derivation hash
unchanged is a **provable** no-op (the refactor receipt you can't get on an ordinary OS).

## Quick start

    nix develop github:conor-sometimes/decomp-nix#crash-bash   # drop into the PS1 build environment
    nix run    github:conor-sometimes/decomp-nix#ghidra-ps2     # or just grab one tool

## Projects

Every project environment — a decomp, a Python library, a Rust crate — lives under
[projects/](projects/), is declared the same way, and is run the same way:

    nix run .#<project> -- -c 'cmd'     # run a command in any project env
    nix develop .#<project>             # drop into it (fhs envs)

Each project picks a **runtime** (how the env is realised, not a different kind of thing):

- **fhs** ([lib/mkDecompEnv.nix](lib/mkDecompEnv.nix)) — a `buildFHSEnv` shell with the toolchain on
  the host, for prebuilt compilers that expect `/usr/lib`. The decomp envs.
- **container** ([lib/mkToolbox.nix](lib/mkToolbox.nix)) — an on-demand OCI image (nix-built, in the
  store; nothing runs until a job does) that `podman run --rm`s with CPU/memory caps and the project
  bind-mounted at `/work`, then tears down. For offloading slow suites, resource caps, keeping a
  runtime off the host. (A different lifecycle from the always-on agent-containment boxes — here the
  container is for reproducibility and caps, not isolation.)

| Project | Runtime | Nix file | What's here |
| --- | --- | --- | --- |
| [Lombyte](https://github.com/lombyte-project/Lombyte) (Ratchet & Clank, PS2) | fhs | [projects/lombyte/default.nix](projects/lombyte/default.nix) | `lombyte-env`: PS2 build env (Wine for the SN tools) |
| Bokura no Kazoku (PS2 decomp) | fhs | [projects/bokura-no-kazoku/default.nix](projects/bokura-no-kazoku/default.nix) | `bokura-env`: PS2 env, four per-unit toolchains (EE-GCC 2.96 ±`-Wa,-g`, ee-gcc 2.9-991111/-01 with 2.96's as) |
| Crash Bash (PS1 decomp) | fhs | [projects/crash-bash/default.nix](projects/crash-bash/default.nix) | `crash-bash-env`: PS1 env (Psy-Q GCC 2.8.1, maspsx, mipsel binutils, just, uv) |
| Fat Princess (PSP decomp) | fhs | [projects/fat-princess/default.nix](projects/fat-princess/default.nix) | `fat-princess-env`: PSP env (pspdecrypt, pspdev binutils+VFPU, SNC/mwccpsp/psp-gcc, ghidra-psp, Wine); `just build` rebuilds the PRX byte-for-byte |
| pktlib (Python) | container | [projects/pktlib/default.nix](projects/pktlib/default.nix) | uv + Python 3.11–3.14 + just, to offload pktlib's property-based / mutation / soak suites |

    nix run .#pktlib -- -c 'just test'            # a command in its on-demand container
    nix run .#pktlib -- --cpus 4 -- just soak 1   # with explicit caps

Add one: a dir under [projects/](projects/) and a line in [default.nix](default.nix). A container
project's `uv sync` (or any network fetch) only works where the host's egress allows it.

## Tools

| Package | Command | What it is |
| --- | --- | --- |
| `ghidra.ps2` | `ghidra-ps2` | Ghidra 12.0.4 + [ghidra-emotionengine-reloaded](https://github.com/chaoticgd/ghidra-emotionengine-reloaded) (EE processor, STABS) |
| `ghidra.ps1` | `ghidra-ps1` | Ghidra 12.0.4 + [ghidra_psx_ldr](https://github.com/lab313ru/ghidra_psx_ldr) (PS-X EXE, GTE, Psy-Q signatures and types) |
| `ghidra.psp` | `ghidra-psp` | Ghidra 12.0.4 + [ghidra-allegrex](https://github.com/kotcrab/ghidra-allegrex) (Allegrex/VFPU, PSP ELF/PRX loader, NID names) |
| `objdiff` | `objdiff-cli` | per-function object diffs and progress reports; in every env |
| `binutils-mips-ps2` | `mips-ps2-decompals-*` | R5900-aware binutils (as, ld, objcopy, objdump, ...); in PS2 envs |
| (nixpkgs) | `spatch` | Coccinelle, type-aware renames across C; in every env |
| `rename-field` | `rename-field STRUCT OLD NEW [PATH...]` | IDA-style field rename: only where the type really is that struct (Coccinelle); prints what it couldn't reach (macro args, unparseable code) |
| `ccc` | `stdump`, `uncc`, `demangle` | PS2 symbol tables: STABS/ELF/SNDLL types and signatures, skeleton sources, GCC 2.x demangling; in PS2 envs |
| `decomp-guard` | `decomp-guard install` / `check` | pre-commit hook that refuses game data (extensions, boot-executable names, ELF/PS-X EXE/ISO/ROM bytes, generated paths, big binaries, text files over 5 MB, mostly-Japanese text such as extracted script dumps); plain bash, also runs without Nix; in every env |
| `lane-merge` | `lane-merge resolve` / `check [--fix]` / `fix-includes` / `alias-undefined LOG` | merging parallel lanes in a splat decomp: union-resolves symbol files and notes, takes the C side over a leftover INCLUDE_ASM, finds one address with two names, renames INCLUDE_ASMs another lane renamed, aliases old names callers still use; in every env |
| `decomp-where` | `decomp-where TARGET BUILT MAP` | when a build stops matching: the first symbols that moved (and the last one that didn't), or every function holding differing bytes; ELF, PS-X EXE or raw; in every env |
| `split-units` | `split-units ASM... --range LO HI --rom-delta D --rodata LO HI` | cuts code with no vtables into plausible translation units (splat yaml lines): only where no .rodata literal is shared across the cut; `--size-only` for libraries; in every env |
| `sjis-strings` | `sjis-strings FILE...` | Japanese (Shift-JIS) strings in an ELF's data sections or any file, as TSV with the space each has; in every env |
| `compiler-sweep` | `compiler-sweep SNIPPET --target ELF --addr A [--name F]` | compiles one function with every EE-GCC under `$DECOMP_COMPILERS`, as C and C++, with/without `-Wa,-g`, with each other build's assembler, and ranks the variants against the target: finds a unit's toolchain in a minute; in PS2 envs |
| (nixpkgs) | `vgmstream-cli` | game audio (Sony XWB/ADS/VAG, ...) to WAV; in PS2 envs |
| `perm-lines` | `perm-lines SRC --cc CMD --symbol NAME --target-elf ELF --addr A` | statement-order brute force for MIPS, C or C++ (decomp-permuter is C only): reorders the lines marked `//@p`, compiles in parallel, reads objects without objdump, hill-climbs on swaps past 5040 orders and prints the closest order; in every env |
| `old-gcc.*` | (folders) | old console GCCs from decompals/old-gcc, e.g. `old-gcc.gcc-2_8_1-psx` |
| `ee-gcc.*` | (folders) | Sony EE-GCC builds from decomp.me's mirror (2.96, 2.9-991111/-01/a, 2.9-990721, 3.2-040921), under `$DECOMP_COMPILERS` in PS2 envs |
| `maspsx` | `maspsx` | Psy-Q assembler behaviour for GNU as (PS1) |
| `asm-differ` | `asm-differ` | quick per-function terminal diffs (diff.py) |
| `binutils-mipsel` | `mipsel-linux-gnu-*` | little-endian MIPS binutils (PS1; PSP too: `as -march=allegrex`, `objdump -m mips:allegrex`) |
| `pspdecrypt` | `pspdecrypt` | decrypts retail PSP executables (`~PSP` EBOOT.BIN, PRX) to plain ELF; UMDs zero the plain BOOT.BIN; in PSP envs |
| `binutils-allegrex` | `psp-as`, `psp-ld`, `psp-objdump`, ... | [pspdev binutils](https://github.com/pspdev/binutils-gdb) 2.44 with the VFPU (mainline has the Allegrex, not its vector unit); in PSP envs |
| `psp-compilers.*` | (folders) | PSP compilers from decomp.me's mirror (SNC 1.2.7503.0, mwccpsp 3.0.1 builds 121-219, psp-gcc 1.3.1/1.7.1), under `$DECOMP_COMPILERS` in PSP envs |

`ghidra-<platform> analyze BINARY OUTDIR` runs headless: import, auto-analysis, then
`OUTDIR/functions.json` (every function), `OUTDIR/symbol_addrs.txt` (named ones, splat format)
and the Ghidra project. Defined in [pkgs/ghidra/default.nix](pkgs/ghidra/default.nix); more
platforms (N64, GameCube/Wii, NDS, GBA) once their extensions build for nixpkgs' Ghidra.

PS1 projects use [lib/platforms/ps1.nix](lib/platforms/ps1.nix) (`lib.platforms.ps1.mkEnv`): mipsel
binutils, maspsx, asm-differ, ghidra-ps1, just and uv, plus the old PS1 compilers as folders under
`$DECOMP_COMPILERS` (gcc-2.8.1-psx, ...; link a project's `tools/<name>` there).

PS2 projects use [lib/platforms/ps2.nix](lib/platforms/ps2.nix) (`lib.platforms.ps2.mkEnv`): the
shared base plus the same PS2 toolbox everywhere (binutils-mips-ps2, ccc, ghidra-ps2, compiler-sweep, vgmstream, and the EE-GCC builds under `$DECOMP_COMPILERS`). Its header has PS2 matching notes (mixed toolchains in one game, the GNU as 2.10 `lui` bug).

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
