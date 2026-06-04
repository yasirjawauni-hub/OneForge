#!/bin/bash
# ============================================================
# ARKA CORE - MASTER COMMANDER
# ------------------------------------------------------------
# CREATED AND DEVELOPED BY: GhasemzadehFard-Dev
# ============================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

BASE_DIR="$(cd "$(dirname "$0")/arka_core" 2>/dev/null && pwd)" || {
    echo "[ARKA_CORE] ERROR: Could not resolve base directory." >&2
    exit 1
}

# Target root for ODEX/VDEX cleanup — override via env if needed
: "${SYSTEM_ROOT:=./out/target/r8s/system}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

LOG()  { echo ">> [ARKA_CORE] $*"; }
WARN() { echo ">> [ARKA_CORE] WARNING: $*" >&2; }
DIE()  { echo ">> [ARKA_CORE] ERROR: $*" >&2; exit 1; }

# RUN_MODULE <label> <script_path>
# Runs a module script if it exists; warns (but does not abort) if missing.
RUN_MODULE()
{
    local LABEL="$1"
    local SCRIPT="$2"

    if [ -f "$SCRIPT" ]; then
        LOG "Running module: $LABEL"
        bash "$SCRIPT" || DIE "Module '$LABEL' failed (exit $?)."
        LOG "Module complete: $LABEL"
    else
        WARN "Module '$LABEL' not found at '$SCRIPT' — skipping."
    fi
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

LOG "Master Patcher found! Executing..."

# ---------------------------------------------------------------------------
# Modules — add new modules here; no other changes needed.
# Each entry: "Label" "relative/path/to/script.sh"
# ---------------------------------------------------------------------------

declare -a MODULES=(
    "Haptic Fix"        "haptics/vibration_fix.sh"
    "Display Fix"       "display/brightness_fix.sh"
    "Smart Call (CSC)"  "csc/smartcall_fix.sh"
)

# Iterate in pairs
for (( i=0; i<${#MODULES[@]}; i+=2 )); do
    LABEL="${MODULES[i]}"
    SCRIPT="$BASE_DIR/${MODULES[i+1]}"
    RUN_MODULE "$LABEL" "$SCRIPT"
done

# ---------------------------------------------------------------------------
# ODEX / VDEX cleanup — force the system to use patched smali
# ---------------------------------------------------------------------------

LOG "Executing ODEX/VDEX cleanup in: $SYSTEM_ROOT"

[ -d "$SYSTEM_ROOT" ] || DIE "System root not found: '$SYSTEM_ROOT'"

ODEX_TARGETS=(
    "services.odex"   "services.vdex"
    "framework.odex"  "framework.vdex"
    "SecSettings.odex" "SecSettings.vdex"
)

# Build a single -name expression for find
FIND_ARGS=()
for (( i=0; i<${#ODEX_TARGETS[@]}; i++ )); do
    [ $i -gt 0 ] && FIND_ARGS+=("-o")
    FIND_ARGS+=("-name" "${ODEX_TARGETS[i]}")
done

DELETED=$(find "$SYSTEM_ROOT" -type f \( "${FIND_ARGS[@]}" \) -print -delete | wc -l)
LOG "ODEX/VDEX cleanup complete — $DELETED file(s) removed."

LOG "All modules finished successfully."
exit 0
