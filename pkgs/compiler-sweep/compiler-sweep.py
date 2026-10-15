#!/usr/bin/env python3
"""compiler-sweep: which compiler, language and assembler options reproduce a PS2 function?

  compiler-sweep SNIPPET --target ELF --addr 0xADDR [--name SYMBOL] [--flags "-O2 -G0"]
                 [--toggle -fno-strict-aliasing,-fno-exceptions] [-I DIR...] [-n 15] [-j 8]

SNIPPET is a .c/.cpp file holding the function (plus whatever declarations it needs). It is
compiled with every compiler under $DECOMP_COMPILERS (each `<dir>/bin/ee-gcc`), and for each:
  - as C and as C++ (`-x c` / `-x c++`);
  - with and without `-Wa,-g` (GNU as stops filling delay slots: retail code with `nop` after
    calls it could have filled was assembled that way);
  - with its own assembler and with each other compiler's (`-B <other>/ee/bin/`: SDK libraries were
    often compiled by one EE-GCC and assembled by another's GNU as);
  - with every on/off combination of the --toggle flags.
The function's bytes are compared word by word with the target at --addr (relocated fields are
masked on both sides) and the variants printed best first: differing words, then size.

Found on Bokura no Kazoku, where three lanes each found a different setup by hand: the game in
EE-GCC 2.96 with `as -g`, C-style units without it, Sony SDK code in ee-gcc 2.9-991111 (C++, 2.96's
as) and 2.9-991111-01 (C). One sweep finds that in a minute.
"""
import argparse
import concurrent.futures as cf
import itertools
import os
import struct
import subprocess
import sys
import tempfile


def elf_sections(d):
    shoff, = struct.unpack_from('<I', d, 0x20)
    shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x2E)
    secs = [struct.unpack_from('<IIIIIIIIII', d, shoff + i * shentsize) for i in range(shnum)]
    strtab = secs[shstrndx]
    name = lambda s: d[strtab[4] + s[0]:].split(b'\0', 1)[0].decode()
    return [(name(s),) + tuple(s) for s in secs]


def func_from_obj(path, want):
    """(bytes, set of (offset, mask)) of a function in a relocatable .o."""
    d = open(path, 'rb').read()
    secs = elf_sections(d)
    idx = {i: s for i, s in enumerate(secs)}
    symtab = next(s for s in secs if s[2] == 2)
    strsec = idx[symtab[7]]
    syms = []
    for i in range(symtab[6] // 16):
        nm, val, size, info, _, shndx = struct.unpack_from('<IIIBBH', d, symtab[5] + i * 16)
        sname = d[strsec[5] + nm:].split(b'\0', 1)[0].decode()
        if info & 0xF == 2 and shndx < len(secs):   # FUNC
            syms.append((sname, val, size, shndx))
    if not syms:
        return None
    pick = [s for s in syms if s[0] == want] if want else syms[:1]
    if not pick:
        pick = [s for s in syms if want and want in s[0]][:1]
    if not pick:
        return None
    _, val, size, shndx = pick[0]
    text = idx[shndx]
    code = d[text[5] + val:text[5] + val + size]
    masks = set()
    for s in secs:
        if s[2] == 9 and s[8] == shndx:   # SHT_REL for that section
            for k in range(s[6] // 8):
                off, info = struct.unpack_from('<II', d, s[5] + k * 8)
                if val <= off < val + size:
                    typ = info & 0xFF
                    masks.add((off - val, 0x03FFFFFF if typ == 4 else 0xFFFF))
    return code, masks


def target_bytes(path, addr, n):
    d = open(path, 'rb').read()
    phoff, = struct.unpack_from('<I', d, 0x1C)
    phentsize, phnum = struct.unpack_from('<HH', d, 0x2A)
    for i in range(phnum):
        typ, off, vaddr, _, filesz = struct.unpack_from('<IIIII', d, phoff + i * phentsize)
        if typ == 1 and vaddr <= addr < vaddr + filesz:
            return d[off + addr - vaddr:off + addr - vaddr + n]
    raise SystemExit(f'0x{addr:X} is not in a loaded segment of {path}')


def score(ours, masks, target):
    words = max(len(ours), len(target)) // 4
    diff = 0
    mask_at = dict(masks)
    for w in range(words):
        a = ours[w * 4:w * 4 + 4]
        b = target[w * 4:w * 4 + 4]
        if len(a) < 4 or len(b) < 4:
            diff += 1
            continue
        x, y = struct.unpack('<I', a)[0], struct.unpack('<I', b)[0]
        m = ~mask_at.get(w * 4, 0) & 0xFFFFFFFF
        if x & m != y & m:
            diff += 1
    return diff


def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    p.add_argument('snippet')
    p.add_argument('--target', required=True)
    p.add_argument('--addr', required=True, type=lambda s: int(s, 0))
    p.add_argument('--name', help='function symbol in the object (default: the first function)')
    p.add_argument('--flags', default='-O2 -G0')
    p.add_argument('--toggle', default='-fno-strict-aliasing,-fno-exceptions')
    p.add_argument('-I', dest='inc', action='append', default=[])
    p.add_argument('--compilers', default=os.environ.get('DECOMP_COMPILERS', ''))
    p.add_argument('-n', type=int, default=15)
    p.add_argument('-j', type=int, default=os.cpu_count() or 4)
    a = p.parse_args()
    if not a.compilers or not os.path.isdir(a.compilers):
        raise SystemExit('no compiler folder: set $DECOMP_COMPILERS or pass --compilers')

    ccs = sorted(c for c in os.listdir(a.compilers) if os.path.exists(os.path.join(a.compilers, c, 'bin', 'ee-gcc')))
    as_dirs = {c: os.path.join(a.compilers, c, 'ee', 'bin') for c in ccs
               if os.path.exists(os.path.join(a.compilers, c, 'ee', 'bin', 'as'))}
    toggles = [t for t in a.toggle.split(',') if t]
    variants = []
    for cc in ccs:
        for lang in ('c', 'c++'):
            for asg in ('', '-Wa,-g'):
                for asm in [None] + [o for o in as_dirs if o != cc]:
                    for on in itertools.product((False, True), repeat=len(toggles)):
                        extra = [t for t, o in zip(toggles, on) if o]
                        if lang == 'c':
                            extra = [t for t in extra if t != '-fno-exceptions']
                            if '-fno-exceptions' in toggles and on[toggles.index('-fno-exceptions')]:
                                continue   # same as without it in C
                        variants.append((cc, lang, asg, asm, tuple(extra)))

    tmp = tempfile.mkdtemp(prefix='compiler-sweep-')
    src = os.path.abspath(a.snippet)

    def run(i, v):
        cc, lang, asg, asm, extra = v
        out = os.path.join(tmp, f'{i}.o')
        cmd = [os.path.join(a.compilers, cc, 'bin', 'ee-gcc'), '-x', lang] + a.flags.split() + list(extra)
        cmd += [f'-I{d}' for d in a.inc] + [f'-Wa,-I{d}' for d in a.inc]
        if asg:
            cmd.append(asg)
        if asm:
            cmd.append(f'-B{as_dirs[asm]}/')
        cmd += ['-c', '-o', out, src]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode:
            return v, None, r.stderr.strip().splitlines()[-1:] or ['error']
        f = func_from_obj(out, a.name)
        if not f:
            return v, None, ['function not found in object']
        return v, f, None

    results = []
    with cf.ThreadPoolExecutor(a.j) as ex:
        for v, f, err in ex.map(lambda iv: run(*iv), enumerate(variants)):
            if f is None:
                continue
            code, masks = f
            tgt = target_bytes(a.target, a.addr, len(code) + 64)
            # the target's length is unknown: compare over our size, count size in words as a tiebreak
            results.append((score(code, masks, tgt[:len(code)]), len(code) // 4, v))
    if not results:
        raise SystemExit('nothing compiled (check the snippet with one compiler by hand)')
    results.sort(key=lambda r: (r[0], r[1]))
    exact = [v for d, _, v in results if d == 0]
    if exact:
        groups = sorted({(cc, lang) for cc, lang, *_ in exact})
        print(f'{len(exact)} variant(s) match exactly, from: ' + ', '.join(f'{cc} -x {lang}' for cc, lang in groups))
        if any(v[2] for v in exact) and any(not v[2] for v in exact):
            print('  with and without -Wa,-g alike: try a function with calls or branches to tell them apart')
        if len(groups) > 1:
            print('  several compilers match: try a bigger function from the same unit')
    print(f'{len(results)} of {len(variants)} variants compiled; best first (differing words / size):')
    for diff, size, (cc, lang, asg, asm, extra) in results[:a.n]:
        how = ' '.join(x for x in [f'-x {lang}', asg, f'as from {asm}' if asm else 'own as'] + list(extra) if x)
        print(f'  {diff:4d} / {size:4d}  {cc:24s} {how}')
    return 0 if results[0][0] == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
