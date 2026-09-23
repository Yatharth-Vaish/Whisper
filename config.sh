#!/bin/bash

# ─────────────────────────────────────────────
# whisper-push-to-talk — config
# Edit this file to match your setup.
# ─────────────────────────────────────────────

# Path to your whisper.cpp directory
WHISPER_DIR="$HOME/whisper.cpp"

# Model to use (tiny.en | base.en | small.en | medium.en | large-v3)
# Recommendation: small.en is the sweet spot for speed + accuracy on M-series
MODEL="$WHISPER_DIR/models/ggml-small.en.bin"

# Temp files (safe to leave as-is)
TEMP_WAV="$HOME/whisper_temp.wav"
OUTPUT_BASE="$HOME/whisper_output"
STATUS_FILE="$HOME/whisper_status.txt"

# Optional: exact name of your real microphone (see Audio MIDI Setup). Only
# needed if you also use Session Mode below — installing BlackHole can bump
# your mic off device index 0. Leave empty to keep the old index-0 behavior.
MIC_DEVICE_NAME=""

# ─────────────────────────────────────────────
# Session Mode (optional) — system audio / mic / both, long-form capture
# See README → Session Mode for setup. Not needed for push-to-talk above.
# ─────────────────────────────────────────────

MODEL_LONG="$WHISPER_DIR/models/ggml-large-v3-turbo.bin"
VAD_MODEL="$WHISPER_DIR/models/ggml-silero-v5.1.2.bin"
LANG_OPT="en"

# avfoundation device NAMES — set these to match Audio MIDI Setup on your
# machine exactly. Looked up by name, not index: indices shift when USB audio
# gear is plugged in.
DEV_SYSTEM_NAME="BlackHole 2ch"        # BlackHole virtual loopback (system audio)
DEV_BOTH_NAME="Record both"            # Aggregate Device: BlackHole ch0-1 + mic ch2
DEV_MIC_NAME="MacBook Air Microphone"  # your real input device
OUTPUT_DEVICE_NAME="Record+listen"     # Multi-Output Device: real output + BlackHole
FALLBACK_OUTPUT="MacBook Air Speakers" # used if the previous output is gone at stop time
SWITCH_AUDIO="/opt/homebrew/bin/SwitchAudioSource"

# Where transcripts land — point this at your notes vault, or anywhere else
VAULT_DIR="$HOME/Documents/Transcripts"
WORK_DIR="$HOME/.whisper_sessions"       # scratch dir for in-progress recordings + state

FFMPEG="/opt/homebrew/bin/ffmpeg"
FFPROBE="/opt/homebrew/bin/ffprobe"
YTDLP="/opt/homebrew/bin/yt-dlp"
THREADS=6
KEEP_WAV=false

# Summary + auto-naming. Empty OLLAMA_MODEL = built-in extractive summary
# (no LLM, no network calls). To use a local LLM instead:
#   brew install ollama && ollama pull qwen2.5:7b
# then set OLLAMA_MODEL="qwen2.5:7b" below.
OLLAMA_MODEL=""
OLLAMA_URL="http://localhost:11434"

# dev_index "<name>" -> prints the avfoundation audio index, empty if not found
dev_index() {
  "$FFMPEG" -f avfoundation -list_devices true -i "" 2>&1 \
    | awk '/AVFoundation audio devices/{a=1;next} a' \
    | sed -nE "s/.*\[([0-9]+)\] ${1}\$/\1/p" | head -1
}
