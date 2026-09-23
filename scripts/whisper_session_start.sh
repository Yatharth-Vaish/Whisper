#!/bin/bash

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

mkdir -p "$WORK_DIR" "$VAULT_DIR"

notify() { osascript -e "display notification \"$1\" with title \"Whisper Session\""; }

if [ -f "$WORK_DIR/active" ]; then
  notify "Session already running — stop it first"
  exit 1
fi

# $1 = label, $2 = mode (system | mic | both)
LABEL=$(echo "${1:-session}" | tr '[:upper:]' '[:lower:]' | tr ' /_' '---' | tr -cd '[:alnum:]-')
[ -z "$LABEL" ] && LABEL="session"

MODE="${2:-system}"
case "$MODE" in
  system) DEVNAME="$DEV_SYSTEM_NAME" ;;
  mic)    DEVNAME="$DEV_MIC_NAME" ;;
  both)   DEVNAME="$DEV_BOTH_NAME" ;;
  *)      notify "Unknown mode: $MODE"; exit 1 ;;
esac

DEVICE=$(dev_index "$DEVNAME")
if [ -z "$DEVICE" ]; then
  notify "Audio device not found: $DEVNAME (check config.sh)"
  exit 1
fi

BASE="$WORK_DIR/$(date +%Y-%m-%d_%H%M)_${LABEL}"

# system/both capture needs output routed through the Multi-Output device
# (BlackHole + your real output) so the recorder can hear it.
if [ "$MODE" != mic ] && [ -x "$SWITCH_AUDIO" ]; then
  PREV=$("$SWITCH_AUDIO" -c -t output)
  if [ "$PREV" != "$OUTPUT_DEVICE_NAME" ]; then
    if "$SWITCH_AUDIO" -t output -s "$OUTPUT_DEVICE_NAME" >/dev/null 2>&1; then
      echo "$PREV" > "$WORK_DIR/active.prevout"
    else
      notify "Could not switch output to $OUTPUT_DEVICE_NAME — set it manually"
    fi
  fi
fi

if [ "$MODE" = both ]; then
  # Aggregate device: ch0-1 = BlackHole (system, stereo), ch2 = mic (mono).
  # Recorded as TWO separate mono tracks (never mixed) so each is transcribed
  # on its own — mixing overlapping speakers into one channel confuses Whisper.
  nohup "$FFMPEG" -f avfoundation -i ":${DEVICE}" \
    -filter_complex "[0:a]pan=mono|c0=0.5*c0+0.5*c1[sys];[0:a]pan=mono|c0=c2[mic]" \
    -map "[sys]" -ar 16000 -c:a pcm_s16le "${BASE}.system.wav" \
    -map "[mic]" -ar 16000 -c:a pcm_s16le "${BASE}.mic.wav" \
    > "${BASE}.ffmpeg.log" 2>&1 &
else
  nohup "$FFMPEG" -f avfoundation -i ":${DEVICE}" \
    -ac 1 -ar 16000 -c:a pcm_s16le \
    "${BASE}.wav" > "${BASE}.ffmpeg.log" 2>&1 &
fi

PID=$!
sleep 1.5
if ! kill -0 "$PID" 2>/dev/null; then
  notify "ffmpeg failed to start — check ${BASE}.ffmpeg.log"
  exit 1
fi

echo "$BASE" > "$WORK_DIR/active"
echo "$PID"  > "$WORK_DIR/active.pid"
echo "$MODE" > "$WORK_DIR/active.mode"
notify "Recording: ${LABEL} (${MODE})"
