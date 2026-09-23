# whisper-push-to-talk

Local, free, instant voice-to-text on macOS — no subscription, no internet, no data leaving your machine.

Hold a hotkey → speak → release → transcript is in your clipboard.

Built on [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal GPU acceleration for Apple Silicon.

---

## Why I built this

I was paying for a voice-to-text SaaS tool. It worked fine. But every time I used it, I had the same thought: *this is just Whisper — OpenAI open-sourced this, why am I paying?*

So one afternoon I stopped paying and built it instead. Same accuracy. Zero cost. No data sent anywhere.

This repo is that build.

---

## Requirements

- macOS (Apple Silicon recommended — M1/M2/M3/M4/M5)
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools (`xcode-select --install`)

---

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/whisper-push-to-talk.git
cd whisper-push-to-talk
bash setup.sh
```

`setup.sh` will:
- Install `ffmpeg` and `sox` via Homebrew
- Clone and build `whisper.cpp` with Metal GPU acceleration
- Download the `small.en` model (~470MB)
- Make scripts executable

---

## Configuration

Edit `config.sh` to set your paths and preferred model:

```bash
# Model options: tiny.en | base.en | small.en | medium.en | large-v3
MODEL="$WHISPER_DIR/models/ggml-small.en.bin"
```

**Model tradeoffs:**

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| tiny.en | 75MB | Fastest | Good |
| base.en | 142MB | Fast | Better |
| small.en | 466MB | Fast | Great ← recommended |
| medium.en | 1.5GB | Moderate | Excellent |
| large-v3 | 3.1GB | Slow | Best |

---

## Hotkey Setup

You need to bind `whisper_start.sh` (record) and `whisper_stop.sh` (stop + transcribe + copy) to hotkeys.

### Option A — Hammerspoon (recommended)

Install [Hammerspoon](https://www.hammerspoon.org), then add to `~/.hammerspoon/init.lua`:

```lua
local pushToTalk = false
local repoPath = os.getenv("HOME") .. "/whisper-push-to-talk"

hs.hotkey.bind({"alt", "shift"}, "R", function()
  os.execute("bash " .. repoPath .. "/scripts/whisper_start.sh &")
end)

hs.hotkey.bind({"alt", "shift"}, "S", function()
  os.execute("bash " .. repoPath .. "/scripts/whisper_stop.sh &")
end)
```

Reload config: `hs.reload()` in the Hammerspoon console.

Default hotkeys: `⌥⇧R` to start, `⌥⇧S` to stop.

### Option B — skhd

Install via Homebrew: `brew install koekeishiya/formulae/skhd`

Add to `~/.skhdrc`:

```
alt + shift - r : bash ~/whisper-push-to-talk/scripts/whisper_start.sh
alt + shift - s : bash ~/whisper-push-to-talk/scripts/whisper_stop.sh
```

Then: `skhd --start-service`

---

## How it works

```
Hotkey press   →   ffmpeg starts recording mic (16kHz mono WAV)
Hotkey release →   ffmpeg stops
                   whisper-cli transcribes locally via Metal GPU
                   output piped to clipboard via pbcopy
```

Everything runs locally. No API calls. No internet required after setup.

---

## Session Mode (optional): lectures, calls, videos

Push-to-talk above is for short dictation bursts. Session Mode is a second,
independent mode for **long-form recording** — a lecture, a Zoom/Meet call, a
video with no existing transcript — that writes a timestamped markdown +
SRT transcript to a folder of your choice (an Obsidian vault, say) instead of
your clipboard. It doesn't touch or depend on push-to-talk in any way.

It has three capture modes:

| Mode | Captures | Use for |
|---|---|---|
| `system` | System output audio | Videos, lectures playing on your machine |
| `mic` | Your microphone, long-form | A talk you're giving, voice memos |
| `both` | System audio **and** mic, as two separate tracks | Calls — you want both sides |

### Skip recording when a transcript already exists

For YouTube and most lecture platforms, don't record audio at all — pull the
existing subtitles instead, free and instant:

```bash
brew install yt-dlp
./scripts/yt_transcript.sh "<url>"
```

### Setup

Recording *system* audio needs a loopback trick — macOS gives no app direct
access to what's playing. [BlackHole](https://github.com/ExistentialAudio/BlackHole)
is a virtual audio driver that solves this.

```bash
bash setup-session-mode.sh
```

This installs `yt-dlp`, [switchaudio-osx](https://github.com/deweller/switchaudio-osx)
(for automatic output-device switching), BlackHole, and the `large-v3-turbo`
+ Silero VAD models used for long-form transcription (small.en is fine for a
10-second dictation burst; over 90 minutes its error rate compounds).

A few manual steps it can't do for you (all in **Audio MIDI Setup**):

1. **Approve the BlackHole driver** — System Settings → Privacy & Security →
   scroll to the bottom → Allow → reboot.
2. **Create a Multi-Output Device** named `Record+listen`: your real output
   (speakers/headphones) + BlackHole, real output listed **first** (it's the
   master clock), Drift Correction on BlackHole only. Session Mode switches
   to this automatically while recording so you can still hear things, then
   switches back when you stop.
3. **Create an Aggregate Device** named `Record both` — BlackHole + your mic
   — only needed for `both` mode.
4. **Edit `config.sh`**: set `DEV_SYSTEM_NAME` / `DEV_BOTH_NAME` /
   `DEV_MIC_NAME` / `OUTPUT_DEVICE_NAME` to the exact device names Audio MIDI
   Setup shows you, `VAULT_DIR` to wherever you want transcripts written, and
   `MIC_DEVICE_NAME` so push-to-talk keeps finding your real mic — installing
   BlackHole can bump it off device index 0.

Devices are looked up **by name**, not index, because avfoundation indices
shift whenever USB audio gear is plugged in.

### Usage

```bash
./scripts/whisper_session_start.sh lecture system   # start, labeled "lecture"
./scripts/whisper_session_stop.sh                   # stop + transcribe
./scripts/whisper_session_status.sh                 # idle, or recording + elapsed time
```

Bind these to hotkeys or Control Center shortcuts the same way as push-to-talk.
`both` mode records the mic and system audio as two genuinely separate
tracks — never mixed into one channel — because Whisper garbles overlapping
speakers badly if you mix them first. Each track is transcribed
independently, then merged back into one note by timestamp:

```
**[00:00:02] System:** ...whatever the video/call said...
**[00:00:40] Mic:** ...whatever you said...
```

### Summaries + auto-naming

On stop, each transcript gets a short summary inserted above the raw text,
and the file is renamed from `<label>.md` to `<date>_<time>_<topic-from-content>.md`
so you can tell what's in a transcript without opening it. Two tiers:

- **Built-in, no setup** — a lightweight extractive summary (picks the most
  representative sentences, titles the file from keyword frequency). No LLM,
  no network calls.
- **Local LLM** — for actual written summaries instead of extracted
  sentences: `brew install ollama && ollama pull qwen2.5:7b`, then set
  `OLLAMA_MODEL="qwen2.5:7b"` in `config.sh`. Falls back to the extractive
  tier automatically if Ollama isn't running, so a session never fails
  because of the summarizer.

### Known limitations

- **`both` mode without headphones**: system audio plays through your
  speakers, so the mic can pick up a few seconds of it bleeding into the
  start of your own speech. Use headphones (added to `Record+listen`
  instead of your speakers) to avoid this entirely.
- **English only** — both transcription (`-l en`) and the extractive
  summarizer's keyword matching assume English audio.
- If a recording is silent (VAD finds no speech), the session's raw files
  are left in `WORK_DIR` for inspection rather than silently deleted.

---

## Project structure

```
whisper-push-to-talk/
├── config.sh                       # All paths and settings — edit this
├── setup.sh                        # One-command install: push-to-talk
├── setup-session-mode.sh           # Optional: installs Session Mode's extra deps
├── scripts/
│   ├── whisper_start.sh            # Push-to-talk: start recording
│   ├── whisper_stop.sh             # Push-to-talk: stop + transcribe + copy to clipboard
│   ├── whisper_session_start.sh    # Session Mode: start (label, mode)
│   ├── whisper_session_stop.sh     # Session Mode: stop + transcribe + summarize
│   ├── whisper_session_status.sh   # Session Mode: idle / recording + elapsed time
│   ├── whisper_merge.py            # Merges System + Mic tracks by timestamp ("both" mode)
│   ├── whisper_summarize.py        # Summarizes + auto-renames a finished transcript
│   └── yt_transcript.sh            # Pulls existing captions instead of recording
└── README.md
```

---

## License

MIT
