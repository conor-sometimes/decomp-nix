#!/usr/bin/env python3
"""progress-readme README.md MATCHED_FUNCS TOTAL_FUNCS MATCHED_BYTES TOTAL_BYTES [LABEL]

Rewrites the block between <!-- progress:start --> and <!-- progress:end --> in README.md (adding
it under the first heading if missing) with a progress bar and the numbers. Each project feeds it
from its own counter, e.g. `progress-readme README.md $(python3 tools/progress.py --numbers)`.
"""
import datetime, re, sys

def bar(frac, width=30):
    n = round(frac * width)
    return "█" * n + "░" * (width - n)

def main():
    if len(sys.argv) < 6:
        sys.exit(__doc__)
    path = sys.argv[1]
    mf, tf, mb, tb = (int(x) for x in sys.argv[2:6])
    label = " ".join(sys.argv[6:]) or "matched"
    pb = mb / tb if tb else 0
    pf = mf / tf if tf else 0
    block = (
        "<!-- progress:start -->\n"
        f"**Progress** ({label}, {datetime.date.today().isoformat()}):\n\n"
        f"`{bar(pb)}` **{pb:.2%}** of code bytes ({mb:,} / {tb:,})  \n"
        f"`{bar(pf)}` **{pf:.2%}** of functions ({mf:,} / {tf:,})\n"
        "<!-- progress:end -->"
    )
    text = open(path).read()
    if "<!-- progress:start -->" in text:
        text = re.sub(r"<!-- progress:start -->.*?<!-- progress:end -->", lambda _: block, text, flags=re.S)
    else:
        lines = text.split("\n")
        i = next((k for k, l in enumerate(lines) if l.startswith("# ")), -1)
        lines.insert(i + 1, "\n" + block)
        text = "\n".join(lines)
    open(path, "w").write(text)
    print(f"{path}: {pb:.2%} of bytes, {pf:.2%} of functions")

if __name__ == "__main__":
    main()
