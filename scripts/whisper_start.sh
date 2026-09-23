#!/bin/bash

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

# Kill any existing recording
pkill -f "ffmpeg.*whisper_temp.wav" 2>/dev/null
sleep 0.5

# Resolve the mic device index. Defaults to 0, but looks it up by name if
# MIC_DEVICE_NAME is set in config.sh — needed once BlackHole (Session Mode,
# see below) is installed, since that can bump your real mic off index 0.
MIC_IDX=0
if [ -n "$MIC_DEVICE_NAME" ]; then
  FOUND=$(/opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
    | awk '/AVFoundation audio devices/{a=1;next} a' \
    | sed -nE "s/.*\[([0-9]+)\] ${MIC_DEVICE_NAME}\$/\1/p" | head -1)
  [ -n "$FOUND" ] && MIC_IDX="$FOUND"
fi

# Start recording in background
nohup /opt/homebrew/bin/ffmpeg -y -f avfoundation -i ":${MIC_IDX}" -ar 16000 -ac 1 -c:a pcm_s16le "$TEMP_WAV" > /dev/null 2>&1 &

echo "started" > "$STATUS_FILE"
