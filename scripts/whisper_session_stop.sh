#!/bin/bash

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

notify() { osascript -e "display notification \"$1\" with title \"Whisper Session\""; }

if [ ! -f "$WORK_DIR/active" ]; then
  notify "No active session"
  exit 1
fi

BASE=$(cat "$WORK_DIR/active")
PID=$(cat "$WORK_DIR/active.pid")
MODE=$(cat "$WORK_DIR/active.mode" 2>/dev/null || echo unknown)

# SIGINT so ffmpeg finalizes the WAV header(s) — hard-killing leaves a header
# claiming zero length, and Whisper reads only a fraction of the file.
kill -INT "$PID" 2>/dev/null
for i in $(seq 1 24); do
  kill -0 "$PID" 2>/dev/null || break
  sleep 0.25
done
kill -9 "$PID" 2>/dev/null

PREVOUT=$(cat "$WORK_DIR/active.prevout" 2>/dev/null)
rm -f "$WORK_DIR/active" "$WORK_DIR/active.pid" "$WORK_DIR/active.mode" "$WORK_DIR/active.prevout"

# restore the output device we switched away from (fall back to speakers if it's gone)
if [ -n "$PREVOUT" ] && [ -x "$SWITCH_AUDIO" ]; then
  "$SWITCH_AUDIO" -t output -s "$PREVOUT" >/dev/null 2>&1 \
    || "$SWITCH_AUDIO" -t output -s "$FALLBACK_OUTPUT" >/dev/null 2>&1
fi

# both = two tracks (system + mic); everything else = one track
if [ "$MODE" = both ]; then
  TRACKS=(system mic)
  WAVS=("${BASE}.system.wav" "${BASE}.mic.wav")
else
  TRACKS=(main)
  WAVS=("${BASE}.wav")
fi

for w in "${WAVS[@]}"; do
  if [ ! -s "$w" ]; then
    notify "Recording is empty — check ${BASE}.ffmpeg.log"
    exit 1
  fi
done

DUR=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "${WAVS[0]}" 2>/dev/null | cut -d. -f1)
MINS=$(( ${DUR:-0} / 60 ))
notify "Transcribing ${MINS} min…"

VAD_FLAGS=()
[ -f "$VAD_MODEL" ] && VAD_FLAGS=(--vad --vad-model "$VAD_MODEL")

for i in "${!TRACKS[@]}"; do
  T="${TRACKS[$i]}"
  "$WHISPER_DIR/build/bin/whisper-cli" \
    -m "$MODEL_LONG" \
    -f "${WAVS[$i]}" \
    -t "$THREADS" \
    -l "$LANG_OPT" \
    -otxt -osrt \
    -of "${BASE}.${T}" \
    "${VAD_FLAGS[@]}" \
    >> "${BASE}.whisper.log" 2>&1
done

NAME=$(basename "$BASE")
OUT="$VAULT_DIR/${NAME}.md"

{
  echo "---"
  echo "type: transcript"
  echo "created: $(date -Iseconds)"
  echo "duration_min: ${MINS}"
  echo "capture_mode: ${MODE}"
  echo "model: large-v3-turbo"
  echo "source: "
  echo "tags: [transcript, inbox]"
  echo "---"
  echo
  echo "> Raw transcript. Timestamped version in \`${NAME}.srt\`."
  echo
} > "$OUT"

if [ "$MODE" = both ]; then
  python3 "$SCRIPT_DIR/whisper_merge.py" "$BASE" \
    "System=${BASE}.system.srt" "Mic=${BASE}.mic.srt" >/dev/null 2>>"${BASE}.whisper.log"
  if [ ! -s "${BASE}.merged.md" ]; then
    notify "No speech found — check ${BASE}.whisper.log"
    exit 1
  fi
  cat "${BASE}.merged.md" >> "$OUT"
  mv "${BASE}.merged.srt" "$VAULT_DIR/${NAME}.srt"
  rm -f "${BASE}.merged.md" "${BASE}.system.txt" "${BASE}.system.srt" "${BASE}.mic.txt" "${BASE}.mic.srt"
else
  if [ ! -s "${BASE}.main.txt" ]; then
    notify "Transcription failed — check ${BASE}.whisper.log"
    rm -f "$OUT"
    exit 1
  fi
  cat "${BASE}.main.txt" >> "$OUT"
  mv "${BASE}.main.srt" "$VAULT_DIR/${NAME}.srt" 2>/dev/null
  rm -f "${BASE}.main.txt"
fi

# Summarize + rename from content (falls back to the original name on any failure)
NEW=$(python3 "$SCRIPT_DIR/whisper_summarize.py" "$OUT" "$VAULT_DIR/${NAME}.srt" \
  --model "$OLLAMA_MODEL" --url "$OLLAMA_URL" 2>>"${BASE}.whisper.log")
[ -n "$NEW" ] && [ -f "$NEW" ] && OUT="$NEW"

if [ "$KEEP_WAV" = true ]; then
  mkdir -p "$VAULT_DIR/audio"
  for w in "${WAVS[@]}"; do mv "$w" "$VAULT_DIR/audio/"; done
else
  rm -f "${WAVS[@]}"
fi

notify "Done: $(basename "$OUT" .md)"
open "$OUT"
