#!/bin/bash
# ============================================================
# ARKA CORE - HAPTIC MODULE
# ------------------------------------------------------------
# CREATED AND DEVELOPED BY: GhasemzadehFard-Dev
# ============================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Bootstrap — shared utilities
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../utils/arka_utils.sh" 2>/dev/null || {
    LOG()  { echo ">> [ARKA_CORE] $*"; }
    WARN() { echo ">> [ARKA_CORE] WARNING: $*" >&2; }
    DIE()  { echo ">> [ARKA_CORE] ERROR: $*" >&2; exit 1; }
}

# ---------------------------------------------------------------------------
# Config — override via env before sourcing
# ---------------------------------------------------------------------------

: "${WORK_DIR:=./out/target/r8s}"
: "${AUTHOR_TAG:=GhasemzadehFard-Dev}"

# VibRune field to force-enable
: "${VIBRUNE_FIELD:=VIB_RUNE_HAPTIC_FEEDBACK_INTENSITY_LEVEL}"

VIBRUNE_SMALI="$WORK_DIR/apktool/system/framework/framework.jar/smali_classes6/com/samsung/android/vibrator/VibRune.smali"

# ---------------------------------------------------------------------------
# Helper: find the line number of the sget-boolean for the target field.
# Returns empty string if not found.
# ---------------------------------------------------------------------------

find_field_line()
{
    local FILE="$1"
    local FIELD="$2"

    # Match the static field declaration for FIELD, then find its
    # companion sget-boolean in the <clinit> that actually loads it.
    # We target the line that reads the field so we can override the
    # result register immediately after, rather than clobbering a
    # fixed line number that drifts across ROM versions.
    grep -n "sget-boolean.*->$FIELD:Z" "$FILE" | head -n1 | cut -d: -f1
}

# ---------------------------------------------------------------------------
# Patch logic
# ---------------------------------------------------------------------------

patch_vibrune()
{
    local TARGET="$VIBRUNE_SMALI"

    # ── Resolve dynamically if default path doesn't exist ──────────────────
    if [ ! -f "$TARGET" ]; then
        LOG "Default VibRune path not found — scanning apktool tree..."
        TARGET="$(find "$WORK_DIR/apktool" -type f -name "VibRune.smali" -print -quit 2>/dev/null)"
        [ -n "$TARGET" ] && [ -f "$TARGET" ] \
            || DIE "VibRune.smali not found anywhere under $WORK_DIR/apktool"
        LOG "Found: $TARGET"
    fi

    # ── Idempotency check ───────────────────────────────────────────────────
    if grep -q "$AUTHOR_TAG" "$TARGET"; then
        LOG "Haptic: already patched — skipping."
        return 0
    fi

    LOG "Applying haptic patch to: $TARGET"

    # ── Locate the sget-boolean that loads the target field ─────────────────
    local LINE_NUM
    LINE_NUM="$(find_field_line "$TARGET" "$VIBRUNE_FIELD")"

    if [ -z "$LINE_NUM" ]; then
        WARN "Field '$VIBRUNE_FIELD' not found in smali — falling back to QpRune pattern..."
        # Secondary: any boolean QpRune-style field read that controls haptics
        LINE_NUM="$(grep -n "sget-boolean.*HAPTIC\|VIBRAT" "$TARGET" | head -n1 | cut -d: -f1)"
    fi

    [ -n "$LINE_NUM" ] \
        || DIE "Could not locate a haptic boolean field in $TARGET — patch aborted."

    LOG "Target line: $LINE_NUM ($(sed -n "${LINE_NUM}p" "$TARGET" | xargs))"

    # ── Determine the destination register from the matched line ────────────
    # e.g.  sget-boolean v0, Lcom/samsung/android/vibrator/VibRune;->VIB_...:Z
    local DEST_REG
    DEST_REG="$(sed -n "${LINE_NUM}p" "$TARGET" | grep -oP '^\s+sget-boolean \K[vp]\d+')"
    : "${DEST_REG:=v0}"    # safe default

    # ── Build the patch block ───────────────────────────────────────────────
    # Strategy: comment out the sget-boolean and inject a const/4 1 override
    # immediately after it, so the register always reads true regardless of
    # the system value. The original instruction is preserved as a comment
    # for reversibility.
    local TMP
    TMP="$(mktemp)"

    awk \
        -v target="$LINE_NUM" \
        -v reg="$DEST_REG" \
        -v tag="$AUTHOR_TAG" \
    '
    NR == target {
        print "    # [" tag "] original: " $0
        print "    const/4 " reg ", 0x1    # force haptic enabled"
        next
    }
    { print }
    ' "$TARGET" > "$TMP" || { rm -f "$TMP"; DIE "awk failed — $TARGET unchanged."; }

    mv -f "$TMP" "$TARGET"
    LOG "Haptic patch applied at line $LINE_NUM (register $DEST_REG forced to 0x1)."
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

echo "----------------------------------------------------"
LOG "RUNNING HAPTIC MODULE"
echo "----------------------------------------------------"

[ -d "$WORK_DIR" ] || DIE "WORK_DIR not found: '$WORK_DIR'"

patch_vibrune

LOG "Haptic module complete."
