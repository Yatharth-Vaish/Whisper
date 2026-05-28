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
