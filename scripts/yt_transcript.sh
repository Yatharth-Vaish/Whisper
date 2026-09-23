#!/bin/bash
# For anything with existing captions (YouTube, most lecture platforms) —
# skip recording entirely and pull the subtitles instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

[ -z "$1" ] && { echo "usage: yt_transcript.sh <url>"; exit 1; }
mkdir -p "$VAULT_DIR"
TMP=$(mktemp -d)
cd "$TMP" || exit 1
"$YTDLP" --write-auto-sub --write-sub --sub-lang en \
  --skip-download --convert-subs srt -o "%(title)s" "$1" >/dev/null 2>&1

FOUND=0
for f in *.srt; do
  [ -e "$f" ] || continue
  FOUND=1
  NAME=$(echo "${f%.en.srt}" | tr ' /' '--' | tr -cd '[:alnum:]-_')
  OUT="$VAULT_DIR/$(date +%Y-%m-%d)_${NAME}.md"
  {
    echo "---"
    echo "type: transcript"
    echo "created: $(date -Iseconds)"
    echo "source: $1"
    echo "method: yt-dlp-subs"
    echo "tags: [transcript, inbox]"
    echo "---"
    echo
    sed -E '/^[0-9]+$/d; /-->/d; /^[[:space:]]*$/d' "$f" | awk '$0!=prev{print} {prev=$0}'
  } > "$OUT"
  echo "$OUT"
done
cd /; rm -rf "$TMP"
[ "$FOUND" = 0 ] && { echo "no English subtitles found for $1 — use session capture instead"; exit 2; }
exit 0
