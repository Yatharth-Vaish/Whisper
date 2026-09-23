#!/bin/bash

# ─────────────────────────────────────────────
# whisper-push-to-talk — Session Mode setup (optional)
# Installs the extra dependencies for long-form / system-audio capture.
# Push-to-talk works without any of this — only run it if you want Session Mode.
# ─────────────────────────────────────────────

set -e

echo "→ Installing yt-dlp, switchaudio-osx, BlackHole..."
brew install yt-dlp switchaudio-osx blackhole-2ch

echo ""
echo "⚠ BlackHole needs one manual step: System Settings → Privacy & Security →"
echo "  scroll down → Allow the driver, then reboot. Re-run this script after"
echo "  that if 'system_profiler SPAudioDataType | grep -i blackhole' is empty."
echo ""

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_DIR/config.sh"

echo "→ Downloading large-v3-turbo model (~1.6GB) for long-form transcription..."
cd "$WHISPER_DIR"
bash ./models/download-ggml-model.sh large-v3-turbo

echo "→ Downloading Silero VAD model..."
bash ./models/download-vad-model.sh silero-v5.1.2 || \
  echo "  (not found — pull the latest whisper.cpp and rebuild to get this script)"

echo "→ Making session scripts executable..."
chmod +x "$REPO_DIR/scripts/whisper_session_start.sh"
chmod +x "$REPO_DIR/scripts/whisper_session_stop.sh"
chmod +x "$REPO_DIR/scripts/whisper_session_status.sh"
chmod +x "$REPO_DIR/scripts/yt_transcript.sh"

echo ""
echo "✓ Session Mode dependencies installed."
echo ""
echo "Still needed, by hand (see README → Session Mode → Audio Routing):"
echo "  1. Approve the BlackHole driver + reboot (if not done above)"
echo "  2. In Audio MIDI Setup, create a Multi-Output Device named 'Record+listen'"
echo "     (your real output + BlackHole, real output listed first)"
echo "  3. Create an Aggregate Device named 'Record both' (BlackHole + your mic),"
echo "     needed only for 'both' mode"
echo "  4. Edit config.sh: set DEV_SYSTEM_NAME / DEV_BOTH_NAME / DEV_MIC_NAME /"
echo "     OUTPUT_DEVICE_NAME to the exact device names Audio MIDI Setup shows you"
echo "  5. Set VAULT_DIR in config.sh to wherever you want transcripts written"
echo "  6. Set MIC_DEVICE_NAME in config.sh so push-to-talk keeps finding your"
echo "     real mic now that BlackHole may have taken over device index 0"
echo ""
echo "Optional — local LLM summaries instead of the built-in extractive one:"
echo "  brew install ollama && ollama pull qwen2.5:7b"
echo "  then set OLLAMA_MODEL=\"qwen2.5:7b\" in config.sh"
