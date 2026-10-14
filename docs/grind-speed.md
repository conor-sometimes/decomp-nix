# Grind speed — ideas & experiments (scratchpad)

Making the matching grind (perm-lines + decomp-permuter) faster, especially for **Lombyte** (Wine +
SN tools — the slow case). Measured on hokkaido. Working notes; promote what proves out.

## Baseline (Lombyte, EE-GCC 2.95.2 via Wine, warm)
- Per-candidate `compile.sh`: **~685 ms**.
- Split: `ee-gcc295.exe` (Wine) ~280 ms · `Ps2EeAs.exe` (Wine) ~200 ms · 5 Python starts
  (`splitfn` + `padless-asm` ×4) ~200 ms.
- Wine cold-start **1044 ms** once, **~135 ms** warm (wineserver persists within a session).
- Native EE-GCC 2.96 (Bokura) for contrast: ~10 ms/compile. We're ~70× slower, so the fixed
  per-compile *overhead* is a huge fraction for us — the batching / warm-compiler wins are bigger here.

## Ideas, ranked (win × applicability to Lombyte)
1. **Batch N candidates per compiler run** — the jackpot. C adaptation (no C++ class trick needed):
   emit `fn_v0..fn_vN`, renamed copies each with its own statement order, into ONE TU; one
   `ee-gcc295` + one `Ps2EeAs`; read each function symbol. Amortises both Wine launches + Python over
   N. Est. 3-5×+, grows with N. **Premise to validate: N copies in one TU each byte-match a solo
   compile.** (ee-gcc 2.95 at -O2 has no IPA/LTO, so functions should be independent — very likely true.)
2. **Persistent `wineserver -p`** — keep Wine warm across runs; never pay the 1 s cold-start again.
3. **Slim compile for grinding** — perm-lines masks relocs (R_MIPS_26/HI16/LO16/GPREL16), so the
   `externs`/`reference`/`finish` steps (which resolve symbols → the masked relocs) may be skippable:
   same diff, fewer steps. **Validate: slim diff == full diff.**
4. **/dev/shm temps** — `compile.sh` mktemps on disk; move to tmpfs. Cheap.
5. **Collapse `padless-asm` 4 calls → 1 process** — saves ~3 Python starts (~150 ms).
6. **Cache on normalised source** — marker-position changes often yield the same source.

Less useful for perm-lines specifically: early-reject-on-instruction-count (reordering preserves the
count, so it almost never fires — it's for the *permuter*, which changes code); skip-the-driver (the
SN driver is a Wine `.exe`).

## Compile server (the big build = #1 + #2)
A long-lived process that holds a warm `wineserver -p`, accepts K candidate sources, emits one TU of
K renamed functions, runs one `ee-gcc295` + one `Ps2EeAs`, and returns each function's bytes. perm-lines
gets a "batch" mode that writes K variants and asks the server for K diffs. The marginal cost per
candidate drops toward just cc1's per-function time.

## Experiments
- [x] **batching premise HOLDS** (Lombyte, FUN_L08_002d23f0): the function's 826 asm lines are
      byte-identical whether compiled solo or as one of several copies in a TU (ee-gcc 2.95 -O2 has no
      IPA/LTO, so functions are independent). Always recompile a found match solo to be sure.
- [x] **ee-gcc compile-step scaling** (one TU, warm): 262 ms/candidate at N=1 -> 48 at N=10 -> 34 at
      N=20 -> 27 at N=40.
- [x] **FULL batched compile PROVEN** (ee-gcc295 + Ps2EeAs, one pass each over N=20 candidates):
      **1037 ms total = 51 ms/candidate, vs ~685 ms solo -> ~13x**. All 20 functions present and
      individually readable in the one object (symbol + addr + size). Slim compile is implicit: we read
      the Ps2EeAs object directly and mask relocs (no padless externs/reference/finish needed).
- [x] `/dev/shm` temps work (used throughout these tests).

## VALIDATED recipe (the compile server / batch grinder)
1. Generate K candidate sources (perm-lines: K statement orderings of the marked function).
2. Emit ONE TU: the shared prelude once, then K renamed copies `FUN_..._v0 .. FUN_..._v{K-1}`
   (C: just rename the function; no C++ subclass trick).
3. One `ee-gcc295 -S` + one `Ps2EeAs` -> one object holding K functions.
4. For each `_vi`, read its bytes from that object and compare to the target (mask R_MIPS_26/HI16/
   LO16/GPREL16) -> K diffs. No padless pipeline, no per-candidate process spawn.
5. Keep a `wineserver -p` warm so step 3 never pays the 1 s cold-start.
Net: ~685 ms/candidate -> ~50 ms/candidate (~13x), before even raising K past 20.

## Next
- [ ] Build it: a perm-lines **batch mode** (writes K variants, one compile, K scores) is the home for
      this — coordinate with the Bokura window (their tool); this doc is the validated Lombyte recipe.
      Or a standalone batch grinder that reuses perm-lines' read_obj.
