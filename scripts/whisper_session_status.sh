#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

if [ -f "$WORK_DIR/active" ]; then
  BASE=$(cat "$WORK_DIR/active")
  W="${BASE}.wav"; [ -f "${BASE}.mic.wav" ] && W="${BASE}.mic.wav"
  SIZE=$(stat -f%z "$W" 2>/dev/null || echo 0)
  MINS=$(( SIZE / 32000 / 60 ))   # 16kHz mono s16le ≈ 32 KB/s
  osascript -e "display notification \"Recording $(basename "$BASE") — ${MINS} min\" with title \"Whisper Session\""
else
  osascript -e 'display notification "Idle" with title "Whisper Session"'
fi
