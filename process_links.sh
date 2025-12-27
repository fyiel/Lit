#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/process_links.sh          # syntax/dry-run checks only
#   ./scripts/process_links.sh --run    # actually downloads and converts

DRY=1
if [[ "${1:-}" == "--run" ]]; then
  DRY=0
fi

check_cmds() {
  local miss=()
  for c in yt-dlp jq ffmpeg; do
    if ! command -v "$c" >/dev/null 2>&1; then
      miss+=("$c")
    fi
  done
  if [[ ${#miss[@]} -gt 0 && $DRY -eq 0 ]]; then
    echo "Missing required commands: ${miss[*]}" >&2
    echo "Install them before running with --run." >&2
    exit 1
  fi
}

mkdir -p videos converts

if [[ $DRY -eq 1 ]]; then
  echo "DRY-RUN mode (no downloads or ffmpeg runs). Run with --run to execute." >&2
  bash -n "$0" || true
fi

check_cmds

if [[ $DRY -eq 1 ]]; then
  echo "Skipping downloads because dry-run requested. To perform downloads run: $0 --run" >&2
  exit 0
fi

if [[ -f links.txt ]]; then
  echo "Links in links.txt:"
  nl -ba -w1 -s': ' links.txt
  echo ""
else
  echo "links.txt not found; create it with one URL per line." >&2
  exit 1
fi

exec 3< links.txt

while IFS= read -r url <&3 || [[ -n "$url" ]]; do
  raw_url="$url"
  sanitized=$(printf '%s' "$raw_url" | sed -r $'s/\x1b\[[0-9;]*[A-Za-z]//g' | tr -d '\r')
  url="$sanitized"
  echo "Raw:       $raw_url"
  if [[ "$raw_url" != "$url" ]]; then
    echo "Sanitized: $url"
  else
    echo "Processing: $url"
  fi

  info_json=$(yt-dlp -j "$url" </dev/null)
  id=$(echo "$info_json" | jq -r '.id // empty')
  title=$(echo "$info_json" | jq -r '.title // empty')
  artist=$(echo "$info_json" | jq -r '.artist // .uploader // .creator // empty')
  album=$(echo "$info_json" | jq -r '.album // .playlist // empty')

  title=${title:-$id}
  artist=${artist:-"Unknown Artist"}
  album=${album:-"Unknown Album"}

  if [[ -z "$id" ]]; then
    echo "Could not determine id for $url; skipping." >&2
    continue
  fi

  safe_title=$(echo "${title:-$id}" | sed 's#[/:]# - #g' | tr -s ' ' '_' | tr -cd '[:alnum:]_ -')
  out_template="videos/${id}.%(ext)s"

  echo "Downloading best audio for id=$id -> ${out_template}"
  yt-dlp -f "bestaudio[ext=m4a]/bestaudio" -o "$out_template" "$url" </dev/null

  infile=$(ls videos/${id}.* 2>/dev/null | head -n1 || true)
  if [[ -z "$infile" ]]; then
    echo "Download failed or file not found for id=$id" >&2
    continue
  fi

  outfile="converts/${safe_title}.mp3"

  ffmpeg_args=( -i "$infile" -vn -c:a libmp3lame -b:a 320k -ar 44100 -ac 2 
    -metadata "title=$title" 
    -metadata "artist=$artist" 
    -metadata "album=$album" 
  )
  ffmpeg_args+=( "$outfile" )

  echo "Converting: $infile -> $outfile"
  ffmpeg -y "${ffmpeg_args[@]}" </dev/null

  echo "Done: $outfile"
done

# Close fd 3
exec 3<&-

echo "All done. Converted files are in ./converts" >&2
