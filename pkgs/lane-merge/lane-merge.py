#!/usr/bin/env python3
"""lane-merge: merge parallel matching lanes (one agent or person per set of source files) into a
splat decomp without the usual breakage. Run from the decomp repo; subcommands:

  lane-merge resolve [FILE...]       resolve git conflict hunks: symbol files and notes are unioned
                                     (ours, then their new lines; exact duplicates dropped); a source
                                     hunk where one side is still only INCLUDE_ASM/INCLUDE_RODATA
                                     takes the side with C. Without FILE: every conflicted file.
                                     Needs diff3 markers (git config merge.conflictStyle diff3).
                                     Exit 1 if hunks are left for a human.
  lane-merge check [--fix]           symbol_addrs: duplicate lines, one address with two names, one
                                     name at two addresses; aliases: duplicates and names that are
                                     also in symbol_addrs (--fix drops exact duplicates and those
                                     aliases).
  lane-merge fix-includes            rewrite INCLUDE_ASM(..., func_XXXXXXXX) to the name
                                     symbol_addrs now gives that address (another lane renamed it).
  lane-merge alias-undefined LOG     append `func_X = 0xX;` to the alias file for every undefined
                                     func_X in a linker log (a caller still uses the old name).

Options: --symbols (config/symbol_addrs.txt), --aliases (config/aliases.ld), --src (src).
Lessons behind it: Bokura no Kazoku's 17-lane overnight run (decomp-nix docs).
"""
import argparse
import glob
import os
import re
import subprocess
import sys

SYM = re.compile(r'\s*([A-Za-z_.$][\w.$]*)\s*=\s*(0x[0-9A-Fa-f]+)\s*;')
UNION = re.compile(r'(symbol_addrs[^/]*\.txt|aliases[^/]*\.ld|rodata_syms[^/]*\.txt|HARD\.md|lessons\.md|\.md)$')
ASM_LINE = re.compile(r'\s*(INCLUDE_(ASM|RODATA)\(.*\);)?\s*$')


def hunks(lines):
    """Yield ('text', [lines]) and ('conflict', ours, base, theirs)."""
    i, plain = 0, []
    while i < len(lines):
        if not lines[i].startswith('<<<<<<<'):
            plain.append(lines[i])
            i += 1
            continue
        if plain:
            yield ('text', plain)
            plain = []
        parts, k = ([], [], []), 0
        i += 1
        while i < len(lines) and not lines[i].startswith('>>>>>>>'):
            if lines[i].startswith('|||||||'):
                k = 1
            elif lines[i].startswith('======='):
                k = 2
            else:
                parts[k].append(lines[i])
            i += 1
        i += 1
        yield ('conflict',) + parts
    if plain:
        yield ('text', plain)


def resolve_file(path):
    lines = open(path).read().split('\n')
    union = bool(UNION.search(path))
    out, left = [], 0
    for h in hunks(lines):
        if h[0] == 'text':
            out += h[1]
            continue
        ours, base, theirs = h[1:]
        if union:
            seen = set(ours)
            out += ours + [l for l in theirs if l not in seen and l not in base]
        elif path.endswith(('.c', '.cpp', '.cc')) and all(ASM_LINE.match(l) for l in ours) \
                and not all(ASM_LINE.match(l) for l in theirs):
            out += theirs
        elif path.endswith(('.c', '.cpp', '.cc')) and all(ASM_LINE.match(l) for l in theirs) \
                and not all(ASM_LINE.match(l) for l in ours):
            out += ours
        else:
            left += 1
            out += ['<<<<<<< ours'] + ours + ['||||||| base'] + base + ['======='] + theirs + ['>>>>>>> theirs']
    if union:
        out = dedupe_symbols(out)
    open(path, 'w').write('\n'.join(out))
    return left


def dedupe_symbols(lines):
    seen, out = set(), []
    for l in lines:
        m = SYM.match(l)
        if m:
            k = (m.group(1), int(m.group(2), 16))
            if k in seen:
                continue
            seen.add(k)
        out.append(l)
    return out


def cmd_resolve(a):
    files = a.files or subprocess.run(['git', 'diff', '--name-only', '--diff-filter=U'],
                                      capture_output=True, text=True).stdout.split()
    bad = 0
    for f in files:
        left = resolve_file(f)
        print(f'{f}: {"resolved" if not left else f"{left} hunk(s) left"}')
        if not left:
            subprocess.run(['git', 'add', f])
        bad += left
    return 1 if bad else 0


def read_syms(path):
    rows = []
    if os.path.exists(path):
        for l in open(path):
            m = SYM.match(l)
            if m:
                rows.append((m.group(1), int(m.group(2), 16)))
    return rows


def cmd_check(a):
    syms, als = read_syms(a.symbols), read_syms(a.aliases)
    by_addr, by_name = {}, {}
    for n, v in syms:
        by_addr.setdefault(v, set()).add(n)
        by_name.setdefault(n, set()).add(v)
    problems = 0
    dup = len(syms) - len(set(syms))
    if dup:
        print(f'{a.symbols}: {dup} duplicate line(s)')
        problems += 1
    for v, ns in sorted(by_addr.items()):
        if len(ns) > 1:
            print(f'0x{v:08X} has {len(ns)} names: {", ".join(sorted(ns))} (keep the one the defining unit uses)')
            problems += 1
    for n, vs in sorted(by_name.items()):
        if len(vs) > 1:
            print(f'{n} at {len(vs)} addresses: {", ".join(hex(v) for v in sorted(vs))}')
            problems += 1
    names = {n for n, _ in syms}
    clash = sorted({n for n, _ in als if n in names})
    adup = len(als) - len(set(als))
    for n in clash:
        print(f'{a.aliases}: {n} is also in {a.symbols}')
    if adup:
        print(f'{a.aliases}: {adup} duplicate line(s)')
    if a.fix:
        for path, drop in ((a.symbols, set()), (a.aliases, set(clash))):
            if not os.path.exists(path):
                continue
            out, seen = [], set()
            for l in open(path).read().split('\n'):
                m = SYM.match(l)
                if m:
                    k = (m.group(1), int(m.group(2), 16))
                    if k in seen or m.group(1) in drop:
                        continue
                    seen.add(k)
                out.append(l)
            open(path, 'w').write('\n'.join(out))
        print('fixed duplicates and aliases that are symbols; names at two addresses need a human')
    return 1 if problems or ((clash or adup) and not a.fix) else 0


def cmd_fix_includes(a):
    names = {}
    for l in open(a.symbols):
        m = SYM.match(l)
        if m and 'type:func' in l:
            names[int(m.group(2), 16)] = m.group(1)
    total = 0
    for f in sorted(glob.glob(os.path.join(a.src, '**', '*.c*'), recursive=True)):
        s = open(f).read()
        n = 0

        def sub(m):
            nonlocal n
            new = names.get(int(m.group(2), 16))
            if new and new != f'func_{m.group(2)}':
                n += 1
                return f'INCLUDE_ASM("{m.group(1)}", {new});'
            return m.group(0)
        t = re.sub(r'INCLUDE_ASM\("([^"]+)",\s*func_([0-9A-Fa-f]{8})\);', sub, s)
        if n:
            open(f, 'w').write(t)
            print(f'{f}: {n} renamed')
            total += n
    print(f'{total} INCLUDE_ASM line(s) renamed')


def cmd_alias_undefined(a):
    log = open(a.log, errors='replace').read()
    undef = sorted(set(re.findall(r"undefined reference to [`'\"](func_([0-9A-Fa-f]{8}))", log)))
    have = {n for n, _ in read_syms(a.aliases)}
    add = [(n, h) for n, h in undef if n not in have]
    with open(a.aliases, 'a') as f:
        for n, h in add:
            f.write(f'{n} = 0x{h.upper()}; /* old name still called after a rename (lane-merge) */\n')
    print(f'aliased {len(add)}: {" ".join(n for n, _ in add)}')


def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    p.add_argument('--symbols', default='config/symbol_addrs.txt')
    p.add_argument('--aliases', default='config/aliases.ld')
    p.add_argument('--src', default='src')
    sub = p.add_subparsers(dest='cmd', required=True)
    s = sub.add_parser('resolve')
    s.add_argument('files', nargs='*')
    s = sub.add_parser('check')
    s.add_argument('--fix', action='store_true')
    sub.add_parser('fix-includes')
    s = sub.add_parser('alias-undefined')
    s.add_argument('log')
    a = p.parse_args()
    return {'resolve': cmd_resolve, 'check': cmd_check, 'fix-includes': cmd_fix_includes,
            'alias-undefined': cmd_alias_undefined}[a.cmd](a) or 0


if __name__ == '__main__':
    sys.exit(main())
