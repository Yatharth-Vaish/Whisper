#!/bin/bash

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

# Stop recording
pkill -f "ffmpeg.*whisper_temp.wav"
sleep 0.3

# Transcribe
"$WHISPER_DIR/build/bin/whisper-cli" -m "$MODEL" -f "$TEMP_WAV" -otxt -of "$OUTPUT_BASE"
sleep 0.3

# Copy to clipboard
cat "${OUTPUT_BASE}.txt" | pbcopy

echo "done" > "$STATUS_FILE"
