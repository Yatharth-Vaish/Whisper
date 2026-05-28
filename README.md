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

## Project structure

```
whisper-push-to-talk/
├── config.sh              # All paths and settings — edit this
├── setup.sh               # One-command install
├── scripts/
│   ├── whisper_start.sh   # Start recording
│   └── whisper_stop.sh    # Stop + transcribe + copy to clipboard
└── README.md
```

---

## License

MIT
