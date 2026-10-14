#!/usr/bin/env python3
"""perm-lines SRC --cc CMD --symbol NAME (--target-elf ELF --addr ADDR [--size N] | --target-obj OBJ)
              [--mark //@p] [-j JOBS] [--limit N] [--seed S] [--out FILE]

Statement-order brute force for MIPS matching decomps, C or C++ (the source is never parsed).
Lines of SRC ending in the marker (default `//@p`) are reordered among their own positions; each
order is compiled with CMD and function SYMBOL in the object is compared with the target bytes.

  --cc      compile command; {src} and {obj} are replaced, e.g.
            'ee-gcc -O2 -G0 -Iinclude -c -o {obj} {src}'
  target    --target-elf: the original executable (stripped is fine) and the function's address;
            --size in bytes (default: our compiled size). --target-obj: an object that has SYMBOL.

Speed: JOBS compiles at once (default half the cores); objects are parsed here, not with objdump;
tried orders are cached. Up to --limit orders (default 5040: 7 lines) all are tried; more and it
hill-climbs on swaps (keeps a swap unless the diff count gets worse, random restarts) and prints
the closest order when none matches. Score = differing words with relocated fields masked
(R_MIPS_26, HI16, LO16, GPREL16), +1000 when the instruction count differs (trailing nops ignored).
Exit 0 on a match (the order is printed and written to --out if given), 1 otherwise.
"""
import argparse, itertools, math, os, random, re, shlex, struct, subprocess, sys, tempfile
from multiprocessing import Pool

MASK = {4: 0xFC000000, 5: 0xFFFF0000, 6: 0xFFFF0000, 7: 0xFFFF0000}  # R_MIPS_26, HI16, LO16, GPREL16


def read_obj(path, symbol):
    """(words, {byte offset in function: mask}) of SYMBOL in a little-endian ELF32 object."""
    b = open(path, "rb").read()
    shoff, = struct.unpack_from("<I", b, 0x20)
    shnum, shstrndx = struct.unpack_from("<HH", b, 0x30)
    sh = [struct.unpack_from("<10I", b, shoff + 40 * i) for i in range(shnum)]
    name = lambda tab, o: b[sh[tab][4] + o:b.index(b"\0", sh[tab][4] + o)].decode()
    hit = None
    for s in sh:
        if s[1] == 2:  # SHT_SYMTAB
            for k in range(s[5] // 16):
                st_name, val, size, info, _, shndx = struct.unpack_from("<IIIBBH", b, s[4] + 16 * k)
                if st_name and info & 0xF == 2 and name(s[6], st_name) == symbol:
                    hit = (shndx, val, size)
    if hit is None:
        raise KeyError(symbol)
    sec, val, size = hit
    code = b[sh[sec][4] + val:sh[sec][4] + val + size]
    masks = {}
    for s in sh:
        if s[1] == 9 and s[7] == sec:  # SHT_REL for that section
            for k in range(s[5] // 8):
                off, info = struct.unpack_from("<II", b, s[4] + 8 * k)
                if val <= off < val + size and info & 0xFF in MASK:
                    masks[off - val] = MASK[info & 0xFF]
    return list(struct.unpack_from(f"<{size // 4}I", code)), masks


def read_elf(path, addr, size):
    """SIZE bytes at virtual address ADDR of an ELF executable (via its program headers)."""
    b = open(path, "rb").read()
    phoff, = struct.unpack_from("<I", b, 0x1C)
    phentsize, phnum = struct.unpack_from("<HH", b, 0x2A)
    for i in range(phnum):
        _, off, vaddr, _, filesz, _, _, _ = struct.unpack_from("<8I", b, phoff + phentsize * i)
        if vaddr <= addr < vaddr + filesz:
            o = off + addr - vaddr
            return list(struct.unpack_from(f"<{size // 4}I", b, o))
    raise ValueError(f"{addr:#x} is in no loaded segment of {path}")


def trim(w):
    w = list(w)
    while w and w[-1] == 0:
        w.pop()
    return w


G = {}


def init(args, lines, idx, target):
    G.update(args=args, lines=lines, idx=idx, target=target,
             dir=tempfile.mkdtemp(prefix="perm-lines-"))


def score(order):
    a = G["args"]
    body = list(G["lines"])
    for k, l in zip(G["idx"], order):
        body[k] = l
    src = os.path.join(G["dir"], "t" + os.path.splitext(a.src)[1])
    obj = os.path.join(G["dir"], "t.o")
    open(src, "w").write("".join(body))
    cmd = a.cc.replace("{src}", shlex.quote(src)).replace("{obj}", shlex.quote(obj))
    if subprocess.run(cmd, shell=True, capture_output=True).returncode:
        return 10**6, order
    try:
        mine, masks = read_obj(obj, a.symbol)
    except KeyError:
        return 10**6, order
    theirs = G["target"] or read_elf(a.target_elf, a.addr, 4 * len(mine))
    m, t = trim(mine), trim(theirs)
    bad = 0 if len(m) == len(t) else 1000
    bad += sum((x ^ y) & masks.get(4 * i, 0xFFFFFFFF) != 0 for i, (x, y) in enumerate(zip(m, t)))
    return bad, order


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[1], formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src")
    p.add_argument("--cc", required=True)
    p.add_argument("--symbol", required=True)
    p.add_argument("--target-elf")
    p.add_argument("--addr", type=lambda s: int(s, 0))
    p.add_argument("--size", type=lambda s: int(s, 0))
    p.add_argument("--target-obj")
    p.add_argument("--mark", default="//@p")
    p.add_argument("-j", "--jobs", type=int, default=max(1, (os.cpu_count() or 2) // 2))
    p.add_argument("--limit", type=int, default=5040)
    p.add_argument("--seed", type=int, default=0)
    p.add_argument("--out")
    a = p.parse_args()
    if bool(a.target_elf) == bool(a.target_obj) or (a.target_elf and a.addr is None):
        p.error("give --target-elf ELF --addr ADDR, or --target-obj OBJ")
    target = None
    if a.target_obj:
        target = read_obj(a.target_obj, a.symbol)[0]
    elif a.size:
        target = read_elf(a.target_elf, a.addr, a.size)

    lines = open(a.src).read().splitlines(keepends=True)
    idx = [k for k, l in enumerate(lines) if l.rstrip().endswith(a.mark)]
    if len(idx) < 2:
        p.error(f"fewer than two lines end in {a.mark}")
    start = tuple(lines[k] for k in idx)
    n = len(idx)
    seen = {}
    hit = None
    with Pool(a.jobs, init, (a, lines, idx, target)) as pool:
        def run(orders):
            new = [o for o in dict.fromkeys(orders) if o not in seen]
            for bad, o in pool.imap_unordered(score, new, chunksize=4):
                seen[o] = bad
                if bad == 0:
                    return o
            return None

        hit = run([start])
        print(f"{n} lines, {math.factorial(n)} orders, start DIFF {seen[start]}, {a.jobs} jobs", file=sys.stderr)
        if seen[start] >= 10**6:
            print("the source as written does not compile (or lacks the symbol)", file=sys.stderr)
            return 1
        if hit is None and math.factorial(n) <= a.limit:
            hit = run(itertools.permutations(start))
        elif hit is None:
            rng, cur = random.Random(a.seed), start
            while len(seen) < a.limit:
                swaps = []
                for i in range(n):
                    for k in range(i + 1, n):
                        l = list(cur)
                        l[i], l[k] = l[k], l[i]
                        swaps.append(tuple(l))
                hit = run(swaps)
                if hit:
                    break
                best = min(swaps, key=lambda o: seen[o])
                if seen[best] <= seen[cur] and best != cur:
                    cur = best
                else:
                    l = list(cur)
                    rng.shuffle(l)
                    cur = tuple(l)
                    hit = run([cur])
                    if hit:
                        break
    best = hit or min(seen, key=seen.get)
    body = list(lines)
    for k, l in zip(idx, best):
        body[k] = l
    if hit:
        print(f"MATCH ({len(seen)} orders tried)", file=sys.stderr)
    else:
        print(f"no order matches ({len(seen)} tried); closest DIFF {seen[best]}", file=sys.stderr)
    print("".join(best), end="")
    if a.out:
        open(a.out, "w").write("".join(body))
    return 0 if hit else 1


if __name__ == "__main__":
    sys.exit(main())
