#!/bin/bash

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

# Kill any existing recording
pkill -f "ffmpeg.*whisper_temp.wav" 2>/dev/null
sleep 0.5

# Start recording in background
nohup /opt/homebrew/bin/ffmpeg -y -f avfoundation -i ":0" -ar 16000 -ac 1 -c:a pcm_s16le "$TEMP_WAV" > /dev/null 2>&1 &

echo "started" > "$STATUS_FILE"
