#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${1:-work}"
echo "[*] Pretend patch running in $WORKDIR"
# Later we can add real fastbootd edits here (props + init.rc tweaks)
