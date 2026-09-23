#!/opt/homebrew/bin/python3
"""Merge per-track SRTs into one labeled, time-ordered transcript.
usage: whisper_merge.py OUT_BASE LABEL1=path1.srt LABEL2=path2.srt ...
writes OUT_BASE.merged.srt and OUT_BASE.merged.md (body only, no front matter)."""
import re, sys

TS = re.compile(r"(\d+):(\d+):(\d+)[,.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,.](\d+)")

def secs(h, m, s, ms):
    return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000

def parse(path):
    out = []
    try:
        blocks = re.split(r"\n\s*\n", open(path, encoding="utf-8").read().strip())
    except FileNotFoundError:
        return out
    for b in blocks:
        lines = [l for l in b.splitlines() if l.strip()]
        for i, l in enumerate(lines):
            m = TS.search(l)
            if m:
                g = m.groups()
                text = " ".join(x.strip() for x in lines[i + 1:]).strip()
                if text:
                    out.append((secs(*g[:4]), secs(*g[4:]), text))
                break
    return out

def fmt_srt(t):
    ms = int(round(t * 1000))
    return "%02d:%02d:%02d,%03d" % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)

def fmt_hms(t):
    t = int(t)
    return "%02d:%02d:%02d" % (t // 3600, t // 60 % 60, t % 60)

out_base = sys.argv[1]
segs = []
for arg in sys.argv[2:]:
    label, path = arg.split("=", 1)
    segs += [(s, e, label, t) for s, e, t in parse(path)]
segs.sort(key=lambda x: (x[0], x[1]))

with open(out_base + ".merged.srt", "w", encoding="utf-8") as f:
    for i, (s, e, label, t) in enumerate(segs, 1):
        f.write("%d\n%s --> %s\n[%s] %s\n\n" % (i, fmt_srt(s), fmt_srt(e), label, t))

with open(out_base + ".merged.md", "w", encoding="utf-8") as f:
    for s, e, label, t in segs:
        f.write("**[%s] %s:** %s\n\n" % (fmt_hms(s), label, t))
print(len(segs))
