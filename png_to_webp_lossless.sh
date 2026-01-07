#!/usr/bin/env bash
set -euo pipefail

IMG_ROOT="img"
BACKUP_ROOT="${IMG_ROOT}/_originals_backup"

# Encoder settings
CWEBP_PNG_ARGS=(-lossless -z 9 -mt)   # PNG: lossless, max compression
CWEBP_JPG_ARGS=(-q 100 -mt)           # JPG/JPEG: max quality

# --- Checks ---
if ! command -v cwebp >/dev/null 2>&1; then
  echo "Error: 'cwebp' not found. Install it with: brew install webp"
  exit 1
fi

if [[ ! -d "$IMG_ROOT" ]]; then
  echo "Error: '$IMG_ROOT' folder not found."
  exit 1
fi

mkdir -p "$BACKUP_ROOT"

echo "Scanning '$IMG_ROOT' for PNG/JPG/JPEG (idempotent)..."
echo "Originals backup: '$BACKUP_ROOT'"
echo

# Find images, excluding the backup folder
while IFS= read -r -d '' src; do
  rel="${src#${IMG_ROOT}/}"       # relative path under img/
  dir="$(dirname "$src")"
  base="$(basename "$src")"

  ext="${base##*.}"
  ext_lc="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  stem="${base%.*}"

  webp="${dir}/${stem}.webp"
  backup="${BACKUP_ROOT}/${rel}"
  backup_dir="$(dirname "$backup")"

  # Select encoder settings
  case "$ext_lc" in
    png)
      cwebp_args=("${CWEBP_PNG_ARGS[@]}")
      ;;
    jpg|jpeg)
      cwebp_args=("${CWEBP_JPG_ARGS[@]}")
      ;;
    *)
      continue
      ;;
  esac

  # Defensive: never touch files already in backup
  if [[ "$src" == "$BACKUP_ROOT/"* ]]; then
    continue
  fi

  # If webp already exists → just ensure original is backed up
  if [[ -f "$webp" ]]; then
    if [[ -f "$src" ]]; then
      mkdir -p "$backup_dir"
      if [[ -f "$backup" ]]; then
        echo "OK (webp + backup exist): $rel"
      else
        echo "BACKUP (webp exists): $rel"
        mv -n "$src" "$backup"
      fi
    fi
    continue
  fi

  # Convert
  echo "CONVERT: $rel -> ${webp#${IMG_ROOT}/}"
  cwebp "${cwebp_args[@]}" "$src" -o "$webp" >/dev/null

  # Sanity check
  if [[ ! -s "$webp" ]]; then
    echo "Error: WebP output missing/empty for: $rel"
    exit 1
  fi

  # Backup original after successful conversion
  mkdir -p "$backup_dir"
  if [[ -f "$backup" ]]; then
    echo "WARN: Backup already exists for $rel; leaving original in place."
  else
    echo "BACKUP: $rel"
    mv -n "$src" "$backup"
  fi

done < <(
  find "$IMG_ROOT" -type f \
    \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) \
    ! -path "${BACKUP_ROOT}/*" \
    -print0
)

echo
echo "Done."
