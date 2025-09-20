#!/usr/bin/env bash
set -euo pipefail

# Usage: prepare_recovery.sh <DIRECT_DOWNLOAD_URL> <WORK_DIR>
# Example: ./prepare_recovery.sh "https://drive.google.com/uc?export=download&id=FILE_ID" work

# Input arguments
URL="${1:-}"
ROOT="${2:-work}"

# Directories
IN_DIR="$ROOT/in"
OUT_DIR="$ROOT/out"
mkdir -p "$IN_DIR" "$OUT_DIR"
cd "$IN_DIR"

# Download recovery image
echo "📥 Downloading recovery image..."
curl -L --fail --retry 4 --connect-timeout 20 "$URL" -o recovery.img

# Log file type and checksum
echo "🔍 Checking file type..."
file recovery.img | tee "$ROOT/recovery.file.txt"
sha256sum recovery.img | tee "$ROOT/recovery.sha256.txt"

# Decompress if LZ4
case "$(file -b recovery.img)" in
  *LZ4*) 
    echo "🧩 Detected LZ4 compression. Decompressing..."
    lz4 -d -f recovery.img recovery.raw.img
    ;;
  *)
    echo "📦 No compression detected. Copying as-is..."
    cp -f recovery.img recovery.raw.img
    ;;
esac

# Validate decompressed image
echo "🔍 Validating decompressed image..."
file recovery.raw.img | tee "$ROOT/recovery.raw.file.txt"
file recovery.raw.img | grep -q 'Android boot image' || {
  echo "❌ Not a valid Android recovery image." >&2
  exit 2
}

# Replace original for downstream steps
mv -f recovery.raw.img recovery.img
echo "✅ Recovery image is ready at: $IN_DIR/recovery.img"
