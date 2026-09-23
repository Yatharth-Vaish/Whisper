#!/opt/homebrew/bin/python3
"""Summarize a transcript note, name it from its content, and rename the .md/.srt.

usage: whisper_summarize.py NOTE.md [NOTE.srt] [--model NAME] [--url URL]

With --model (an Ollama model) it writes an LLM summary + title; on any failure, or
with no model, it falls back to a local extractive summary (no LLM, no network).
Inserts the summary into the note, adds title/summary_method to the front matter,
renames the note and .srt to <date_time>_<slug>.*, and prints the new note path."""
import argparse, json, os, re, sys, urllib.request
from collections import Counter

STOP = set("""a about above after again all also am an and any are as at be because been before being below
between both but by can could did do does doing down during each few for from further had has have having he her
here hers herself him himself his how i if in into is it its itself just me more most my myself no nor not now of
off on once only or other our ours ourselves out over own same she should so some such than that the their theirs
them themselves then there these they this those through to too under until up very was we were what when where
which while who whom why will with would you your yours yourself yourselves
like yeah okay ok gonna wanna really actually know thing things right think want need let get got going go
one two well kind sort mean say said says see look lot bit maybe basically literally stuff way something
anything everything someone people guys guy oh um uh hey yes yep dont don't didn't doesn't isn't wasn't im i'm
ive i've youre you're thats that's its it's theres there's cant can't wont won't gotta cause come comes
came make makes made take takes took back still even much many every never always use used using""".split())

def read_note(path):
    txt = open(path, encoding="utf-8").read()
    m = re.match(r"(---\n.*?\n---\n)(.*)", txt, re.S)
    fm, body = (m.group(1), m.group(2)) if m else ("", txt)
    return fm, body

def clean_body(body):
    out = []
    for line in body.splitlines():
        if line.startswith(">") or not line.strip() or line.startswith("## Summary"):
            continue
        line = re.sub(r"^\*\*\[\d+:\d+:\d+\]\s*[^*]*:\*\*\s*", "", line)
        out.append(line.strip())
    return " ".join(out)

def words(s):
    return [w for w in re.findall(r"[a-zA-Z][a-zA-Z'-]{2,}", s.lower())]

def extractive(text):
    sents = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]
    toks = [w for w in words(text) if w not in STOP]
    tf = Counter(toks)
    bigrams = Counter()
    for s in sents:
        ws = [w for w in words(s)]
        for a, b in zip(ws, ws[1:]):
            if a not in STOP and b not in STOP:
                bigrams[(a, b)] += 1
    title_words = []
    for (a, b), c in bigrams.most_common(1):
        if c >= 2:
            title_words += [a, b]
    for w, _ in tf.most_common(8):
        if len(title_words) >= 4:
            break
        if w not in title_words:
            title_words.append(w)
    title = " ".join(title_words[:4]) or "untitled transcript"
    scored = []
    for i, s in enumerate(sents):
        ws = [w for w in words(s) if w not in STOP]
        n = len(words(s))
        if 6 <= n <= 45 and ws:
            scored.append((sum(tf[w] for w in ws) / (n ** 0.6), i))
    top = sorted(sorted(scored, reverse=True)[:5], key=lambda x: x[1])
    bullets = [sents[i] for _, i in top]
    topics = ", ".join(w for w, _ in tf.most_common(6))
    return title, bullets, topics

def ollama(url, model, prompt, want_json):
    body = {"model": model, "prompt": prompt, "stream": False,
            "options": {"num_ctx": 8192, "temperature": 0.2}}
    if want_json:
        body["format"] = "json"
    req = urllib.request.Request(url.rstrip("/") + "/api/generate",
                                 json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=900) as r:
        return json.loads(r.read())["response"]

def llm(url, model, text):
    ws = text.split()
    chunks = [" ".join(ws[i:i + 2500]) for i in range(0, len(ws), 2500)] or [""]
    if len(chunks) > 1:
        notes = [ollama(url, model, "Summarize this transcript excerpt in 4-6 short bullet points:\n\n" + c, False)
                 for c in chunks]
        source = "\n\n".join(notes)
    else:
        source = chunks[0]
    r = ollama(url, model,
               'Read this transcript (or notes on it). Reply with JSON only: {"title": "<= 6 words, '
               'describing the topic>", "summary": ["3-7 concise bullet strings"]}\n\n' + source, True)
    j = json.loads(r)
    bullets = [str(b).strip() for b in j["summary"] if str(b).strip()]
    title = str(j["title"]).strip()
    if not title or not bullets:
        raise ValueError("empty LLM result")
    return title, bullets

def slug(t):
    s = re.sub(r"[^a-z0-9]+", "-", t.lower()).strip("-")
    return "-".join(s.split("-")[:8]) or "untitled"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("note"); ap.add_argument("srt", nargs="?")
    ap.add_argument("--model", default=""); ap.add_argument("--url", default="http://localhost:11434")
    a = ap.parse_args()

    fm, body = read_note(a.note)
    text = clean_body(body)
    if len(text.split()) < 15:            # too little speech to summarize
        print(a.note); return

    method, topics = "extractive", ""
    title = bullets = None
    if a.model:
        try:
            title, bullets = llm(a.url, a.model, text); method = "ollama:" + a.model
        except Exception as e:
            sys.stderr.write("LLM summary failed (%s); using extractive\n" % e)
    if not title:
        title, bullets, topics = extractive(text)

    base = os.path.basename(a.note)[:-3]
    stamp = re.match(r"\d{4}-\d{2}-\d{2}_\d{4}", base)
    prefix = stamp.group(0) if stamp else base
    new_base = prefix + "_" + slug(title)
    d = os.path.dirname(a.note)
    n = 2; cand = new_base
    while os.path.exists(os.path.join(d, cand + ".md")) and cand != base:
        cand = "%s-%d" % (new_base, n); n += 1
    new_base = cand

    block = "## Summary (%s)\n\n%s\n\n" % (
        method if method != "extractive" else "auto-extract, no LLM",
        "\n".join("- " + b for b in bullets))
    if topics:
        block += "**Topics:** %s\n\n" % topics
    block += "---\n\n"

    lines = body.split("\n")
    idx = next((i for i, l in enumerate(lines) if l.startswith(">")), -1)
    lines.insert(idx + 2 if idx >= 0 else 0, block)
    body = "\n".join(lines).replace(base + ".srt", new_base + ".srt")
    if fm:
        fm = fm.rstrip("\n")[:-3].rstrip("\n") + "\ntitle: \"%s\"\nsummary_method: %s\n---\n" % (
            title.replace('"', "'"), method)

    new_note = os.path.join(d, new_base + ".md")
    open(new_note, "w", encoding="utf-8").write(fm + body)
    if new_note != a.note:
        os.remove(a.note)
    if a.srt and os.path.exists(a.srt) and os.path.basename(a.srt) != new_base + ".srt":
        os.rename(a.srt, os.path.join(d, new_base + ".srt"))
    print(new_note)

main()
