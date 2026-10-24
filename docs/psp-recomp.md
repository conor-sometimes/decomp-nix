# PSP static recompilation: design notes

Plan for a `psp-recomp` package: retail PSP executable (decrypted PRX) to native C, built and
run on a PC. Not started; these notes fix the design before any code. Learned from reading
[PSPRecomp](https://github.com/jessicanataliagta/PSPRecomp) (MIT; also vendored in
[fuc-recomp](https://github.com/elprogramadorloco-arch/fuc-recomp)) in 2026-10: ideas, not code.

## Shape

- **Game-neutral core + per-game profile.** The core (decoder, codegen, runtime, HLE registry)
  knows no game addresses. A profile registers by address (native fast paths, fixes) and by
  NID (Sony library functions). PSPRecomp does this well.
- **Inputs we already have:** the PRX, its relocation table (the complete truth about pointers),
  and a function list with sizes from the matching decomp (`tools/prx.py` in a decomp repo, or
  splat symbols). So analysis seeds from facts, not heuristics; heuristics only fill gaps.
- **Output: one C function per guest function**, or small clusters. Not PSPRecomp's 16 KiB
  "mega-units": they need >1-2 GB RAM per unit to compile and lose the 1:1 mapping to our
  matched symbols. Indirect jumps go through a PC -> function table built from the same list.
- **Semantics with tests from day one:** delay slots (condition evaluated before the slot),
  branch-likely (slot only when taken), FPU, VFPU (prefixes included). Unknown encodings
  compile to an `unsupported(pc, word)` trap, never a codegen failure.
- **HLE grows by need:** every import stub becomes a dispatcher exit by NID; unimplemented NIDs
  log and return. Implement in the order the game calls them. Threads are cooperative and
  switch only at HLE calls; re-enabling interrupts is a scheduling point (guest spinlocks).
- **Host:** SDL3 (window, input, audio), a Ge display-list renderer on OpenGL or Vulkan,
  ffmpeg for ATRAC3/PMF. No Windows-only APIs.

## Nix

- `pkgs/psp-recomp`: the recompiler and runtime (C++20, CMake/Ninja; core without third-party
  deps; host with SDL3, ffmpeg, a GL/Vulkan loader from nixpkgs).
- Per game: a derivation that runs the recompiler on the **user's** PRX (a path input checked by
  SHA-1, never fetched, never cached publicly) and builds the generated C. No generated code in
  any repo: it is derived from the game.
- The matching decomp and the recompilation share the function list and names; as functions
  are decompiled, the recompiled ones can be swapped for the real C.
