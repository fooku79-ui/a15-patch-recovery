#!/usr/bin/env bash
set -euo pipefail

# Usage: prepare_recovery.sh <DIRECT_DOWNLOAD_URL> <WORK_DIR>
# Example: ./prepare_recovery.sh "https://drive.google.com/uc?export=download&id=FILE_ID" work

# Input arguments with validation
URL="${1:-}"
ROOT="${2:-work}"

if [ -z "$URL" ]; then
    echo "❌ Error: Direct download URL is required" >&2
    echo "Usage: $0 <DIRECT_DOWNLOAD_URL> [WORK_DIR]" >&2
    echo "Example: $0 'https://drive.google.com/uc?export=download&id=FILE_ID' work" >&2
    exit 1
fi

# Directories
IN_DIR="$ROOT/in"
OUT_DIR="$ROOT/out"
mkdir -p "$IN_DIR" "$OUT_DIR"

# Change to input directory
cd "$IN_DIR"

# Download recovery image
echo "📥 Downloading recovery image..."
echo "URL: $URL"
if ! curl -L --fail --retry 4 --connect-timeout 20 "$URL" -o recovery.img; then
    echo "❌ Download failed. Please check the URL and try again." >&2
    exit 1
fi

# Verify download succeeded and file has content
if [ ! -s recovery.img ]; then
    echo "❌ Downloaded file is empty or doesn't exist." >&2
    exit 1
fi

# Log file type and checksum
echo "🔍 Checking file type..."
file recovery.img | tee "$ROOT/recovery.file.txt"
sha256sum recovery.img | tee "$ROOT/recovery.sha256.txt"

# Get file size for logging
FILE_SIZE=$(stat -c%s recovery.img 2>/dev/null || echo "unknown")
echo "📊 File size: $FILE_SIZE bytes"

# Decompress if LZ4
case "$(file -b recovery.img)" in
  *LZ4*) 
    echo "🧩 Detected LZ4 compression. Decompressing..."
    if ! lz4 -d -f recovery.img recovery.raw.img; then
        echo "❌ LZ4 decompression failed." >&2
        exit 2
    fi
    ;;
  *)
    echo "📦 No compression detected. Copying as-is..."
    cp -f recovery.img recovery.raw.img
    ;;
esac

# Validate decompressed image exists and has content
if [ ! -s recovery.raw.img ]; then
    echo "❌ Decompressed image is empty or doesn't exist." >&2
    exit 2
fi

# Validate decompressed image format
echo "🔍 Validating decompressed image..."
file recovery.raw.img | tee "$ROOT/recovery.raw.file.txt"

# Fixed validation - handles both "Android boot image" and "Android bootimg" formats
if ! file recovery.raw.img | grep -q -E "(Android boot|Android bootimg)"; then
    echo "❌ Not a valid Android recovery image." >&2
    echo "File type detected: $(file -b recovery.raw.img)" >&2
    echo "Expected: Android boot image or Android bootimg" >&2
    exit 2
fi

# Get decompressed file size for logging
RAW_SIZE=$(stat -c%s recovery.raw.img 2>/dev/null || echo "unknown")
echo "📊 Decompressed size: $RAW_SIZE bytes"

# Replace original for downstream steps
mv -f recovery.raw.img recovery.img

echo "✅ Recovery image is ready at: $IN_DIR/recovery.img"

# Optional: Log final image info
echo "📋 Final image info:"
file recovery.img
ls -lh recovery.img
