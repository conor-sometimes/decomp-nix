#!/usr/bin/env python3
"""sjis-strings: list the Shift-JIS (Japanese) strings in an executable or data file, as UTF-8 TSV.

  sjis-strings FILE... [--all] [--min 2]

For an ELF, only .rodata/.data/.sdata are scanned and addresses are virtual; for anything else,
the whole file, with file offsets. Columns: file, section, address, bytes (with NUL, i.e. the
space a replacement has in place), text.

A string counts when it is NUL-terminated, decodes cleanly as cp932, has full-width kana and at
least --min Japanese characters, and has no half-width katakana (a run of bytes 0xA1-0xDF is
almost always float or pointer data, not text). --all keeps those too.
Game text: keep the output out of git (decomp-guard refuses mostly-Japanese files).
"""
import argparse
import re
import struct
import sys

KANA = re.compile(r'[\u3041-\u30fa]')
JP = re.compile(r'[\u3040-\u30ff\u3400-\u9fff\uff00-\uffef\u3000-\u303f]')
HALF = re.compile(r'[\uff61-\uff9f]')
RUN = re.compile(rb'(?:[\x81-\x9f\xe0-\xfc][\x40-\xfc]|[\x09\x0a\x0d\x20-\x7e\xa1-\xdf]){2,}\x00')


def regions(d):
    if d[:4] != b'\x7fELF':
        return [('file', 0, 0, len(d))]
    shoff, = struct.unpack_from('<I', d, 0x20)
    shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x2E)
    if not shnum:
        return [('file', 0, 0, len(d))]
    secs = [struct.unpack_from('<IIIIII', d, shoff + i * shentsize) for i in range(shnum)]
    strtab = secs[shstrndx]
    out = []
    for s in secs:
        name = d[strtab[4] + s[0]:].split(b'\0', 1)[0].decode(errors='replace')
        if name in ('.rodata', '.data', '.sdata') and s[1] != 8:   # not NOBITS
            out.append((name, s[3], s[4], s[5]))
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    p.add_argument('files', nargs='+')
    p.add_argument('--all', action='store_true')
    p.add_argument('--min', type=int, default=2)
    a = p.parse_args()
    print('file\tsection\taddress\tbytes\ttext')
    for path in a.files:
        d = open(path, 'rb').read()
        for name, addr, off, size in regions(d):
            blob = d[off:off + size]
            for m in RUN.finditer(blob):
                t = m.group()[:-1].decode('cp932', 'replace')
                if not JP.search(t):
                    continue
                if not a.all and ('\ufffd' in t or not KANA.search(t)
                                  or len(JP.findall(t)) < a.min or HALF.search(t)):
                    continue
                t = t.replace('\t', '\\t').replace('\n', '\\n').replace('\r', '\\r')
                print(f'{path}\t{name}\t0x{addr + m.start():X}\t{len(m.group())}\t{t}')


if __name__ == '__main__':
    sys.exit(main())
