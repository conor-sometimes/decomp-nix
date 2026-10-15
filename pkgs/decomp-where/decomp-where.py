#!/usr/bin/env python3
"""decomp-where: when a matching build stops matching, say where.

  decomp-where TARGET BUILT MAP [--symbols config/symbol_addrs.txt] [-n 15]

TARGET is the original executable, BUILT the one the build produced, MAP the linker map
(ld -Map). Both executables are ELF or PS-X EXE (or raw images loaded at --base).

Prints:
- the size difference, if any;
- the first symbols whose address in MAP differs from symbol_addrs.txt (a function before them
  grew or shrank: start there, it is usually the last one that did not move);
- every function holding differing bytes (same size, wrong content: a stale INCLUDE_ASM, an
  assembler bug, a wrong compiler flag for that unit), with the first differing word.
"""
import argparse
import bisect
import re
import struct
import sys


def segments(data, base):
    """[(vaddr, file_offset, size)] of the loaded image."""
    if data[:4] == b'\x7fELF':
        phoff, = struct.unpack_from('<I', data, 0x1C)
        phentsize, phnum = struct.unpack_from('<HH', data, 0x2A)
        segs = []
        for i in range(phnum):
            typ, off, vaddr, _, filesz = struct.unpack_from('<IIIII', data, phoff + i * phentsize)
            if typ == 1 and filesz:
                segs.append((vaddr, off, filesz))
        return segs
    if data[:8] == b'PS-X EXE':
        t_addr, t_size = struct.unpack_from('<II', data, 0x18)
        return [(t_addr, 0x800, t_size)]
    return [(base, 0, len(data))]


def image(data, base):
    """{vaddr: byte} as one flat bytes object plus its start address."""
    segs = segments(data, base)
    lo = min(v for v, _, _ in segs)
    hi = max(v + n for v, _, n in segs)
    buf = bytearray(hi - lo)
    for v, off, n in segs:
        buf[v - lo:v - lo + n] = data[off:off + n]
    return lo, bytes(buf)


def map_symbols(path):
    out = {}
    for line in open(path, errors='replace'):
        m = re.match(r'\s+0x0*([0-9a-fA-F]+)\s+([A-Za-z_.$][\w.$]*)\s*$', line)
        if m:
            out[m.group(2)] = int(m.group(1), 16)
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    p.add_argument('target')
    p.add_argument('built')
    p.add_argument('map')
    p.add_argument('--symbols', default='config/symbol_addrs.txt')
    p.add_argument('--base', type=lambda s: int(s, 0), default=0, help='load address for raw images')
    p.add_argument('-n', type=int, default=15)
    a = p.parse_args()

    t_lo, t = image(open(a.target, 'rb').read(), a.base)
    b_lo, b = image(open(a.built, 'rb').read(), a.base)
    if (t_lo, len(t)) != (b_lo, len(b)):
        print(f'size: target 0x{t_lo:X}+0x{len(t):X}, built 0x{b_lo:X}+0x{len(b):X} '
              f'({len(b) - len(t):+d} bytes)')

    mapped = map_symbols(a.map)
    want = {}
    try:
        for line in open(a.symbols):
            m = re.match(r'\s*([A-Za-z_.$][\w.$]*)\s*=\s*(0x[0-9A-Fa-f]+)', line)
            if m:
                want[m.group(1)] = int(m.group(2), 16)
    except FileNotFoundError:
        pass
    shifted = sorted((want[n], n, v) for n, v in mapped.items() if n in want and want[n] != v)
    if shifted:
        good = sorted(want[n] for n, v in mapped.items() if n in want and want[n] == v and want[n] < shifted[0][0])
        print(f'{len(shifted)} symbol(s) moved; the first:')
        for w, n, v in shifted[:a.n]:
            print(f'  0x{w:08X} -> 0x{v:08X} ({v - w:+d})  {n}')
        if good:
            last = good[-1]
            name = next(n for n, v in want.items() if v == last)
            print(f'  last symbol still in place: 0x{last:08X} {name} (the culprit is at or after it)')
        return 1

    funcs = sorted((v, n) for n, v in mapped.items())
    keys = [v for v, _ in funcs]
    seen, n_bytes = [], 0
    lo = max(t_lo, b_lo)
    for i in range(min(t_lo + len(t), b_lo + len(b)) - lo):
        va = lo + i
        if t[va - t_lo] == b[va - b_lo]:
            continue
        n_bytes += 1
        j = bisect.bisect_right(keys, va) - 1
        name = funcs[j][1] if j >= 0 else '?'
        if not seen or seen[-1][0] != name:
            w = va & ~3
            tw = t[w - t_lo:w - t_lo + 4][::-1].hex()
            bw = b[w - b_lo:w - b_lo + 4][::-1].hex()
            seen.append((name, va, tw, bw))
    if not n_bytes:
        print('no differing bytes' + (' (sizes differ, see above)' if len(t) != len(b) else ''))
        return 0 if len(t) == len(b) else 1
    print(f'{n_bytes} byte(s) differ in {len(seen)} place(s):')
    for name, va, tw, bw in seen[:a.n]:
        print(f'  0x{va:08X} {name}: target {tw}, built {bw}')
    return 1


if __name__ == '__main__':
    sys.exit(main())
