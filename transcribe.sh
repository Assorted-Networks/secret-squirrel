#!/usr/bin/env bash
# Bare-bones voice-to-text: pick a mic, press Enter to record, Enter to stop,
# and the whisper.cpp transcript is printed to stdout.
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/models}"
WHISPER_MODEL="${WHISPER_MODEL:-base.en}"
WHISPER_LANG="${WHISPER_LANG:-en}"
MODEL="$MODEL_DIR/ggml-$WHISPER_MODEL.bin"

WAV="$(mktemp --suffix=.wav)"
LOG="$(mktemp)"
rec_pid=""
cleanup() {
  [[ -n "$rec_pid" ]] && kill "$rec_pid" 2>/dev/null
  rm -f "$WAV" "$LOG"
}
trap cleanup EXIT
trap 'echo >&2; exit 130' INT TERM

# 1. Fetch the model once; it lives in the "models" volume after that.
if [[ ! -f "$MODEL" ]]; then
  echo "Model '$WHISPER_MODEL' not found, downloading to $MODEL_DIR ..." >&2
  download-ggml-model.sh "$WHISPER_MODEL" "$MODEL_DIR" >&2 || { rm -f "$MODEL"; exit 1; }
fi

# 2. Find capture devices and ask which one to use.
#    "card 1: Device [USB Mic], device 0: USB Audio [USB Audio]" -> "plughw:1,0 USB Mic - USB Audio"
mapfile -t mics < <(arecord -l 2>/dev/null |
  sed -n 's/^card \([0-9]*\): [^[]*\[\([^]]*\)\], device \([0-9]*\): [^[]*\[\([^]]*\)\].*/plughw:\1,\3 \2 - \4/p')

if (( ${#mics[@]} == 0 )); then
  echo "No microphones found. Is /dev/snd passed through (see docker-compose.yml)?" >&2
  exit 1
fi

echo "Microphones:" >&2
for i in "${!mics[@]}"; do
  printf '  %d) %s\n' "$((i + 1))" "${mics[i]#* }" >&2
done
while :; do
  read -rp "Which mic? [1-${#mics[@]}, default 1]: " n || exit 1
  n="${n:-1}"
  [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#mics[@]} )) && break
done
mic="${mics[n-1]}"
dev="${mic%% *}"

# 3. Record / transcribe loop.
echo "Using ${mic#* } ($dev). Enter starts and stops recording, Ctrl-C quits." >&2
while read -rp "[Enter] record " _; do
  arecord -q -D "$dev" -f S16_LE -r 16000 -c 1 "$WAV" &
  rec_pid=$!
  read -rp "Recording... [Enter] stop " _ || true
  # arecord finalizes the WAV on SIGTERM. A signal sent before it has started
  # can be lost, so repeat (with a gap, so a second one can't cut it off).
  while kill "$rec_pid" 2>/dev/null; do sleep 1; done
  wait "$rec_pid" || true
  rec_pid=""

  if text="$(whisper-cli -m "$MODEL" -l "$WHISPER_LANG" -nt -np -f "$WAV" 2>"$LOG")"; then
    sed 's/^[[:space:]]*//' <<<"$text"
  else
    echo "Transcription failed:" >&2
    cat "$LOG" >&2
  fi
done
