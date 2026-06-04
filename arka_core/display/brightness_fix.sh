#!/bin/bash
# ============================================================
# ARKA CORE - DISPLAY & BRIGHTNESS MODULE
# ------------------------------------------------------------
# CREATED AND DEVELOPED BY: / zurai02
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
: "${ARKA_CORE_DIR:=./arka_core}"
: "${AUTHOR_TAG:=GhasemzadehFard-Dev}"

# Relative paths — resolved against WORK_DIR / ARKA_CORE_DIR at runtime
SMALI_REL="apktool/system_ext/priv-app/SystemUI/SystemUI.apk/smali_classes3/com/android/systemui/settings/brightness/BrightnessDetailAdapter.smali"
PATCH_REL="display/systemui/BrightnessDetailAdapter_Bypass.smali"

TARGET_SMALI="$WORK_DIR/$SMALI_REL"
CUSTOM_SMALI="$ARKA_CORE_DIR/$PATCH_REL"

# ---------------------------------------------------------------------------
# Helper: resolve target smali dynamically when default path drifts
# (e.g. smali_classes index shifts between ROM builds)
# ---------------------------------------------------------------------------

resolve_target()
{
    local FILE="BrightnessDetailAdapter.smali"
    local FOUND

    # Fast path — use the configured path if it exists
    [ -f "$TARGET_SMALI" ] && { echo "$TARGET_SMALI"; return 0; }

    LOG "Default path not found — scanning apktool tree for $FILE..."
    FOUND="$(find "$WORK_DIR/apktool" -type f -name "$FILE" -print -quit 2>/dev/null)"

    [ -n "$FOUND" ] && [ -f "$FOUND" ] \
        || DIE "$FILE not found anywhere under $WORK_DIR/apktool"

    LOG "Resolved: $FOUND"
    echo "$FOUND"
}

# ---------------------------------------------------------------------------
# Helper: resolve patch smali dynamically when layout changes
# ---------------------------------------------------------------------------

resolve_patch()
{
    [ -f "$CUSTOM_SMALI" ] && { echo "$CUSTOM_SMALI"; return 0; }

    LOG "Default patch path not found — scanning arka_core/display..."
    local FOUND
    FOUND="$(find "$ARKA_CORE_DIR/display" -type f -name "BrightnessDetailAdapter_Bypass.smali" -print -quit 2>/dev/null)"

    [ -n "$FOUND" ] && [ -f "$FOUND" ] \
        || DIE "Patch file not found — cannot apply display patch."

    LOG "Resolved patch: $FOUND"
    echo "$FOUND"
}

# ---------------------------------------------------------------------------
# Validate patch integrity before applying
# Ensures the custom smali contains required brightness bypass markers.
# ---------------------------------------------------------------------------

validate_patch()
{
    local PATCH="$1"

    # Must declare the correct class
    grep -q "\.class.*BrightnessDetailAdapter" "$PATCH" \
        || DIE "Patch validation failed: missing .class declaration in $PATCH"

    # Must contain the sensor privacy bypass block (restored in prior improvement)
    grep -q "sensorPrivacyManager\|isSensorPrivacyEnabled\|const/4.*0x0" "$PATCH" \
        || WARN "Patch may be missing sensor privacy bypass — verify $PATCH manually."

    # Must not be the stock unpatched file (idempotency guard)
    grep -q "$AUTHOR_TAG\|GhasemzadehFard\|Bypass" "$PATCH" \
        || WARN "Patch file does not carry an author tag — origin unverified."

    LOG "Patch validation passed."
}

# ---------------------------------------------------------------------------
# Backup original before overwriting
# Keeps one .bak copy; repeated runs do not overwrite the original backup.
# ---------------------------------------------------------------------------

backup_original()
{
    local TARGET="$1"
    local BAK="${TARGET}.bak"

    if [ -f "$TARGET" ] && [ ! -f "$BAK" ]; then
        cp -a "$TARGET" "$BAK"
        LOG "Backup saved: $BAK"
    elif [ -f "$BAK" ]; then
        LOG "Backup already exists — not overwriting: $BAK"
    fi
}

# ---------------------------------------------------------------------------
# Apply patch — atomic copy via temp file in same directory
# ---------------------------------------------------------------------------

apply_patch()
{
    local PATCH="$1"
    local TARGET="$2"
    local TMP
    TMP="$(dirname "$TARGET")/.$(basename "$TARGET").tmp"

    cp -a "$PATCH" "$TMP" \
        || DIE "Failed to stage patch to $TMP"

    mv -f "$TMP" "$TARGET" \
        || { rm -f "$TMP"; DIE "Failed to move staged patch to $TARGET"; }

    LOG "Patch applied: $(basename "$TARGET")"
}

# ---------------------------------------------------------------------------
# Idempotency check — skip if target already carries the patch
# ---------------------------------------------------------------------------

already_patched()
{
    local TARGET="$1"
    [ -f "$TARGET" ] && grep -q "$AUTHOR_TAG\|GhasemzadehFard\|Bypass" "$TARGET"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

patch_brightness_adapter()
{
    local TARGET PATCH
    TARGET="$(resolve_target)"
    PATCH="$(resolve_patch)"

    if already_patched "$TARGET"; then
        LOG "BrightnessDetailAdapter.smali already patched — skipping."
        return 0
    fi

    validate_patch "$PATCH"
    backup_original "$TARGET"
    apply_patch "$PATCH" "$TARGET"

    LOG "Display brightness patch applied successfully."
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

echo "----------------------------------------------------"
LOG "RUNNING DISPLAY & BRIGHTNESS MODULE"
echo ">> DEVELOPED BY: GhasemzadehFard-Dev / zurai02"
echo "----------------------------------------------------"

[ -d "$WORK_DIR" ] || DIE "WORK_DIR not found: '$WORK_DIR'"

patch_brightness_adapter

LOG "Display module complete."
