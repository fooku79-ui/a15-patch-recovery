#!/usr/bin/env bash
set -euo pipefail

# Usage: enable_fastbootd.sh <AIK_DIR>
# In our workflow we pass: work/AIK (AIK-Linux clone)
AIK_DIR="${1:-}"
if [[ -z "${AIK_DIR}" || ! -d "${AIK_DIR}" ]]; then
  echo "Usage: $0 <AIK_WORK_DIR>" >&2
  exit 1
fi

# Paths
AIK_BIN_CANDIDATES=(
  "$AIK_DIR/bin/magiskboot"
  "$AIK_DIR/magiskboot"
)
MAGISKBOOT=""
for c in "${AIK_BIN_CANDIDATES[@]}"; do
  if [[ -x "$c" ]]; then MAGISKBOOT="$c"; break; fi
done
if [[ -z "$MAGISKBOOT" ]]; then
  echo "magiskboot not found in $AIK_DIR (bin/magiskboot). Make sure AIK-Linux is cloned." >&2
  exit 2
fi

# Our workflow layout:
# work/
#   in/recovery.img         (downloaded & normalized)
#   AIK/                    (AIK-Linux repo)
#   out/                    (where we put final image)
ROOT="$(cd "$AIK_DIR/.." && pwd)"
IN_IMG="$ROOT/in/recovery.img"
OUT_DIR="$ROOT/out"
WORK_DIR="$ROOT/phhwork"

mkdir -p "$OUT_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -f "$IN_IMG" "$WORK_DIR/r.img"

# Optional signing key (not actually used by magiskboot repack here)
if [[ ! -f "$WORK_DIR/phh.pem" ]]; then
  openssl genrsa -f4 -out "$WORK_DIR/phh.pem" 4096 >/dev/null 2>&1 || true
fi

(
  set -e
  cd "$WORK_DIR"

  # Unpack with magiskboot
  "$MAGISKBOOT" unpack r.img

  RAMDISK="ramdisk.cpio"
  if [[ -f vendor_ramdisk/recovery.cpio ]]; then
    RAMDISK="vendor_ramdisk/recovery.cpio"
  fi

  # Extract ramdisk to get system/bin/recovery from within
  "$MAGISKBOOT" cpio "$RAMDISK" extract || true

  # Safety check
  if [[ ! -f system/bin/recovery ]]; then
    echo "system/bin/recovery not found in ramdisk — device layout may differ." >&2
    echo "Proceeding anyway (no hexpatches applied)." >&2
  else
    set +e
    # ---- BEGIN HEX PATCHES (from your script) ----
    "$MAGISKBOOT" hexpatch system/bin/recovery e10313aaf40300aa6ecc009420010034 e10313aaf40300aa6ecc0094
    "$MAGISKBOOT" hexpatch system/bin/recovery eec3009420010034 eec3009420010035
    "$MAGISKBOOT" hexpatch system/bin/recovery 3ad3009420010034 3ad3009420010035
    "$MAGISKBOOT" hexpatch system/bin/recovery 50c0009420010034 50c0009420010035
    "$MAGISKBOOT" hexpatch system/bin/recovery 080109aae80000b4 080109aae80000b5
    "$MAGISKBOOT" hexpatch system/bin/recovery 20f0a6ef38b1681c 20f0a6ef38b9681c
    "$MAGISKBOOT" hexpatch system/bin/recovery 23f03aed38b1681c 23f03aed38b9681c
    "$MAGISKBOOT" hexpatch system/bin/recovery 20f09eef38b1681c 20f09eef38b9681c
    "$MAGISKBOOT" hexpatch system/bin/recovery 26f0ceec30b1681c 26f0ceec30b9681c
    "$MAGISKBOOT" hexpatch system/bin/recovery 24f0fcee30b1681c 24f0fcee30b9681c
    "$MAGISKBOOT" hexpatch system/bin/recovery 27f02eeb30b1681c 27f02eeb30b9681c
    "$MAGISKBOOT" hexpatch system/bin/recovery b4f082ee28b1701c b4f082ee28b970c1
    "$MAGISKBOOT" hexpatch system/bin/recovery 9ef0f4ec28b1701c 9ef0f4ec28b9701c
    "$MAGISKBOOT" hexpatch system/bin/recovery 9ef00ced28b1701c 9ef00ced28b9701c
    "$MAGISKBOOT" hexpatch system/bin/recovery 2001597ae0000054 2001597ae1000054
    "$MAGISKBOOT" hexpatch system/bin/recovery 2001597ac0000054 2001597ac1000054
    "$MAGISKBOOT" hexpatch system/bin/recovery 9ef0fcec28b1701c 9ef0fced28b1701c
    "$MAGISKBOOT" hexpatch system/bin/recovery 9ef00ced28b1701c 9ef00ced28b9701c
    "$MAGISKBOOT" hexpatch system/bin/recovery 24f0f2ea30b1681c 24f0f2ea30b9681c
    "$MAGISKBOOT" hexpatch system/bin/recovery e0031f2a8e000014 200080528e000014
    "$MAGISKBOOT" hexpatch system/bin/recovery 41010054a0020012f44f48a9 4101005420008052f44f48a9
    set -e
    cp -f system/bin/recovery ../reco-patched || true
  fi

  # Put patched recovery back into ramdisk and repack
  if [[ -f system/bin/recovery ]]; then
    "$MAGISKBOOT" cpio "$RAMDISK" 'add 0755 system/bin/recovery system/bin/recovery'
  fi
  "$MAGISKBOOT" repack r.img new-boot.img

  # Output to workflow's expected location
  cp -f new-boot.img "$OUT_DIR/patched-recovery.img"
)

echo "[*] Done. Output at: $OUT_DIR/patched-recovery.img"
