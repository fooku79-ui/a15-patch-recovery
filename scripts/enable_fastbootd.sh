#!/usr/bin/env bash
set -euo pipefail

AIK_DIR="${1:-}"
if [[ -z "${AIK_DIR}" || ! -d "${AIK_DIR}" ]]; then
  echo "Usage: $0 <AIK_WORK_DIR>" >&2
  exit 1
fi

cd "$AIK_DIR"
[[ -d ramdisk ]] || { echo "No ramdisk found (unpack failed)"; exit 2; }

echo "[*] Enabling fastbootd…"

# 1) Ensure fastbootd is marked available in common prop files
PROP_FILES=(
  "ramdisk/default.prop"
  "ramdisk/system/etc/prop.default"
  "ramdisk/system_root/default.prop"
)
for pf in "${PROP_FILES[@]}"; do
  if [[ -f "$pf" ]]; then
    if grep -qE '^ro\.fastbootd\.available=' "$pf"; then
      sed -i 's/^ro\.fastbootd\.available=.*/ro.fastbootd.available=1/' "$pf"
      echo "  * Updated $pf"
    else
      echo "ro.fastbootd.available=1" >> "$pf"
      echo "  + Added to $pf"
    fi
  fi
done

# 2) Inject a minimal fastbootd service if it doesn't exist
INIT_CANDIDATES=(
  "ramdisk/init.recovery.rc"
  "ramdisk/etc/init.recovery.rc"
  "ramdisk/init.rc"
)

read -r -d '' FASTBOOTD_BLOCK <<'EOF' || true
# ---- BEGIN ADDED: fastbootd ----
service fastbootd /sbin/fastbootd
    class main
    oneshot
    disabled
    seclabel u:r:fastbootd:s0

on property:sys.fastbootd=1
    start fastbootd
# ---- END ADDED: fastbootd ----
EOF

ADDED=0
for initf in "${INIT_CANDIDATES[@]}"; do
  if [[ -f "$initf" ]]; then
    if ! grep -qE '^service[[:space:]]+fastbootd[[:space:]]' "$initf"; then
      printf "\n%s\n" "$FASTBOOTD_BLOCK" >> "$initf"
      echo "  + Injected fastbootd service into $initf"
      ADDED=1
      break
    else
      echo "  * fastbootd service already present in $initf"
      ADDED=1
      break
    fi
  fi
done

if [[ "$ADDED" -eq 0 ]]; then
  echo "  ! No init.recovery file found to patch (device layout may differ)."
fi

echo "[*] Patch complete."
