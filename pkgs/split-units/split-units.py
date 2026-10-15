#!/usr/bin/env python3
"""split-units: cut a stretch of code with no vtables into plausible translation units, as splat
yaml lines.

  split-units ASM... --range LO HI --rom-delta D [--prefix Unit] [--size-only]
              --rodata LO HI [--insns 2500] [--funcs 60] [--type cpp]

ASM: the splat asm of the range (one .s or many); LO/HI: the virtual address range; D: vaddr minus
ROM offset (PS2 ELF with .text at file 0x1000 for 0x100000: 0xFF000).

The rule (from Bokura no Kazoku, where it turned ~4,900 functions into lane work): each unit's
string literals sit together in .rodata, in unit order, so a cut is only allowed between two
functions where no literal is shared across it: every .rodata address used after the cut is above
every one used before it. Within that, a unit closes after ~--insns instructions or --funcs
functions. --size-only drops the literal rule (libraries whose literals are shared everywhere,
or one object per function anyway).

Matching doesn't depend on the cuts (functions keep their addresses either way); they decide
which functions share a .cpp, i.e. where static helpers and literals can live once data is
converted. Treat them as plausible, not proven.
"""
import argparse
import re


def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    p.add_argument('asm', nargs='+')
    p.add_argument('--range', nargs=2, required=True, type=lambda s: int(s, 0), metavar=('LO', 'HI'))
    p.add_argument('--rom-delta', required=True, type=lambda s: int(s, 0))
    p.add_argument('--prefix', default='Unit')
    p.add_argument('--size-only', action='store_true')
    p.add_argument('--rodata', nargs=2, type=lambda s: int(s, 0), metavar=('LO', 'HI'),
                   help='.rodata range (needed unless --size-only: .data/.bss words are shared across units)')
    p.add_argument('--insns', type=int, default=2500)
    p.add_argument('--funcs', type=int, default=60)
    p.add_argument('--type', default='cpp', help='splat segment type (c, cpp, asm)')
    a = p.parse_args()
    lo, hi = a.range
    if not a.size_only and not a.rodata:
        p.error('--rodata LO HI is needed for the literal rule (or use --size-only)')

    funcs = {}
    for path in a.asm:
        for part in re.split(r'\nglabel ', '\n' + open(path, errors='replace').read())[1:]:
            name, body = part.split('\n', 1)
            addrs = re.findall(r'/\* \w+ ([0-9A-F]{8}) ', body)
            if not addrs:
                continue
            va = int(addrs[0], 16)
            if not lo <= va < hi:
                continue
            refs = [int(x, 16) for x in re.findall(r'%(?:hi|lo)\((?:D|jtbl)_([0-9A-F]{8})\)', body)]
            refs = [r for r in refs if a.rodata and a.rodata[0] <= r < a.rodata[1]]
            funcs[va] = (len(addrs), refs)
    order = sorted(funcs)
    if not order:
        raise SystemExit('no functions in range')
    sufmin = [1 << 40] * (len(order) + 1)
    for i in range(len(order) - 1, -1, -1):
        sufmin[i] = min([sufmin[i + 1]] + funcs[order[i]][1])
    cuts, mx, n, ins = [order[0]], 0, 0, 0
    for i, va in enumerate(order):
        size, refs = funcs[va]
        n += 1
        ins += size
        mx = max([mx] + refs)
        if i + 1 < len(order) and (ins >= a.insns or n >= a.funcs) and (a.size_only or sufmin[i + 1] > mx):
            cuts.append(order[i + 1])
            n = ins = 0
    for va in cuts:
        print(f'      - [0x{va - a.rom_delta:X}, {a.type}, {a.prefix}{va:06X}]')


if __name__ == '__main__':
    main()
