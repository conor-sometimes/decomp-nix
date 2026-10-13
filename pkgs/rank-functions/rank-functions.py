#!/usr/bin/env python3
"""rank-functions [--src DIR] [--asm DIR] [-n N] [--json]: unmatched functions, easiest first.

Finds every function still pulled in by an INCLUDE_ASM(...) in the sources, reads its splat
assembly, and scores how hard it probably is to match: instructions, branches, loops (backward
branches), calls, indirect calls/jumps (virtual calls, jump tables), float ops and stack frame size.
Lower = easier. A heuristic for picking work, not a promise.
"""
import argparse, json, os, re, sys

INSN = re.compile(r"/\*\s*[0-9A-Fa-f]+\s+([0-9A-Fa-f]{8})\s+[0-9A-Fa-f]{8}\s*\*/\s+([a-z0-9.]+)\s*(.*)")
LABEL = re.compile(r"^\s*\.?L([0-9A-Fa-f]{8}):")
INCLUDE = re.compile(r'INCLUDE_ASM\(\s*"[^"]*"\s*,\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)')
BRANCH = re.compile(r"^b(eq|ne|lt|le|gt|ge|c1|c0|eqz|nez|gez|gtz|lez|ltz)[a-z]*$|^b$")
WEIGHTS = {"insns": 1, "branches": 4, "loops": 10, "calls": 5, "indirect": 25, "floats": 2, "frame": 1 / 16, "jumptables": 40}

def features(path):
    f = dict.fromkeys(WEIGHTS, 0)
    for line in open(path, errors="replace"):
        m = INSN.search(line)
        if not m:
            continue
        addr, op, args = int(m.group(1), 16), m.group(2), m.group(3)
        f["insns"] += 1
        if BRANCH.match(op):
            f["branches"] += 1
            t = re.search(r"\.?L([0-9A-Fa-f]{8})", args)
            if t and int(t.group(1), 16) <= addr:
                f["loops"] += 1
        elif op == "jal":
            f["calls"] += 1
        elif op == "jalr":
            f["calls"] += 1; f["indirect"] += 1
        elif op == "jr" and "$31" not in args and "$ra" not in args:
            f["jumptables"] += 1
        if op.endswith((".s", ".d")) or op in ("lwc1", "swc1", "mtc1", "mfc1", "ctc1", "cfc1") or op.startswith("c."):
            f["floats"] += 1
        if op in ("addiu", "daddiu") and re.match(r"\$(29|sp),\s*\$(29|sp),\s*-0x([0-9A-Fa-f]+)", args):
            f["frame"] = max(f["frame"], int(re.match(r"\$(29|sp),\s*\$(29|sp),\s*-0x([0-9A-Fa-f]+)", args).group(3), 16))
    return f

def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--src", default="src"); ap.add_argument("--asm", default="asm")
    ap.add_argument("-n", type=int, default=30); ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    pending = {}
    for root, _, files in os.walk(a.src):
        for fn in files:
            if fn.endswith((".c", ".cpp", ".cc", ".h", ".inc")):
                p = os.path.join(root, fn)
                for m in INCLUDE.finditer(open(p, errors="replace").read()):
                    pending.setdefault(m.group(1), p)
    asm = {}
    for root, _, files in os.walk(a.asm):
        for fn in files:
            if fn.endswith(".s"):
                asm.setdefault(fn[:-2], os.path.join(root, fn))
    rows = []
    for name, src in pending.items():
        if name not in asm:
            continue
        f = features(asm[name])
        score = round(sum(WEIGHTS[k] * v for k, v in f.items()), 1)
        why = ", ".join(f"{v} {k}" for k, v in f.items() if v and k not in ("insns", "frame")) or "straight-line"
        rows.append({"score": score, "name": name, "insns": f["insns"], "src": src, "why": why, **f})
    rows.sort(key=lambda r: (r["score"], r["insns"]))
    if a.json:
        json.dump(rows[: a.n] if a.n else rows, sys.stdout, indent=1); print(); return
    print(f"{len(rows)} unmatched functions with assembly ({len(pending) - len(rows)} INCLUDE_ASM without a .s found)")
    print(f"{'score':>7} {'insns':>5}  function                          source / why")
    for r in rows[: a.n] if a.n else rows:
        print(f"{r['score']:7.1f} {r['insns']:5d}  {r['name']:<33} {r['src']}  ({r['why']})")

if __name__ == "__main__":
    main()
