#!/bin/bash

# ─────────────────────────────────────────────
# whisper-push-to-talk — setup
# Installs dependencies and downloads the model
# ─────────────────────────────────────────────

set -e

echo "→ Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "✗ Homebrew not found. Install it first: https://brew.sh"
  exit 1
fi

echo "→ Installing ffmpeg and sox..."
brew install ffmpeg sox

echo "→ Cloning whisper.cpp..."
if [ ! -d "$HOME/whisper.cpp" ]; then
  git clone https://github.com/ggerganov/whisper.cpp.git "$HOME/whisper.cpp"
else
  echo "  whisper.cpp already exists, skipping clone."
fi

echo "→ Building whisper.cpp with Metal (Apple Silicon)..."
cd "$HOME/whisper.cpp"
cmake -B build -DGGML_METAL=ON
cmake --build build --config Release

echo "→ Downloading small.en model (~470MB)..."
bash ./models/download-ggml-model.sh small.en

echo "→ Making scripts executable..."
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$REPO_DIR/scripts/whisper_start.sh"
chmod +x "$REPO_DIR/scripts/whisper_stop.sh"

echo ""
echo "✓ Setup complete."
echo ""
echo "Next: bind whisper_start.sh and whisper_stop.sh to hotkeys."
echo "See README.md → Hotkey Setup section."
