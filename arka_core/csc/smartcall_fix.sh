#!/bin/bash
# ============================================================
# ARKA CORE - SMART CALL (CSC) MODULE
# ------------------------------------------------------------
# CREATED AND DEVELOPED BY: zurai02
# ============================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Bootstrap — locate source tree and shared utilities
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../utils/arka_utils.sh" 2>/dev/null || {
    # Minimal fallbacks if run standalone
    LOG()  { echo ">> [ARKA_CORE] $*"; }
    WARN() { echo ">> [ARKA_CORE] WARNING: $*" >&2; }
    DIE()  { echo ">> [ARKA_CORE] ERROR: $*" >&2; exit 1; }
}

# ---------------------------------------------------------------------------
# Config — override via env before sourcing
# ---------------------------------------------------------------------------

: "${WORK_DIR:=./out/target/r8s}"
: "${SC_PROVIDER:=whitepages}"                        # Smart Call SVC provider
: "${SC_PROVIDER_FULL:=whitepages,whitepages,off}"    # CSC svc-provider triple
: "${AUTHOR_TAG:=GhasemzadehFard Hook}"

FF_PATH="$WORK_DIR/system/system/etc/floating_feature.xml"
PROP_PATH="$WORK_DIR/system/system/build.prop"

# ---------------------------------------------------------------------------
# Helper: atomic in-place XML patch
# Replace a closing tag with injected elements + that closing tag.
# Usage: xml_inject <file> <closing_tag> <content_to_inject>
# ---------------------------------------------------------------------------

xml_inject()
{
    local FILE="$1"
    local CLOSE_TAG="$2"
    local INJECT="$3"
    local TMP
    TMP="$(mktemp)"

    # Use awk for reliable multi-line injection (avoids sed portability issues)
    awk -v close="</${CLOSE_TAG}>" -v inject="$INJECT" '
        $0 ~ close { print inject }
        { print }
    ' "$FILE" > "$TMP" && mv -f "$TMP" "$FILE"
}

# ---------------------------------------------------------------------------
# Helper: remove all lines matching a key from an XML file, then inject
# Usage: xml_patch <file> <closing_tag> key1 key2 ... -- inject_line1 inject_line2
# ---------------------------------------------------------------------------

xml_remove_keys()
{
    local FILE="$1"; shift
    local KEYS=("$@")
    local SED_ARGS=()

    for key in "${KEYS[@]}"; do
        SED_ARGS+=(-e "/$key/d")
    done

    sed -i "${SED_ARGS[@]}" "$FILE"
}

# ---------------------------------------------------------------------------
# 1. floating_feature.xml
# ---------------------------------------------------------------------------

patch_floating_feature()
{
    [ -f "$FF_PATH" ] || { WARN "floating_feature.xml not found — skipping."; return 0; }

    LOG "Patching floating_feature.xml..."

    xml_remove_keys "$FF_PATH" \
        "SEC_FLOATING_FEATURE_CONTACTS_SUPPORT_SMART_CALL" \
        "SEC_FLOATING_FEATURE_SMARTCALL_CONFIG_SVC_PROVIDER"

    local INJECT
    INJECT="$(printf \
        '    <SEC_FLOATING_FEATURE_CONTACTS_SUPPORT_SMART_CALL>TRUE</SEC_FLOATING_FEATURE_CONTACTS_SUPPORT_SMART_CALL>\n    <SEC_FLOATING_FEATURE_SMARTCALL_CONFIG_SVC_PROVIDER>%s</SEC_FLOATING_FEATURE_SMARTCALL_CONFIG_SVC_PROVIDER>' \
        "$SC_PROVIDER")"

    xml_inject "$FF_PATH" "SecFloatingFeatureSet" "$INJECT"

    LOG "floating_feature.xml patched."
}

# ---------------------------------------------------------------------------
# 2. cscfeature.xml (optics + prism, all CSC variants)
# ---------------------------------------------------------------------------

patch_csc_features()
{
    LOG "Patching CSC feature files..."

    local COUNT=0
    local DIRS=("$WORK_DIR/optics" "$WORK_DIR/prism")

    while IFS= read -r -d '' CSC_FILE; do
        xml_remove_keys "$CSC_FILE" \
            "CscFeature_Common_ConfigSvcProviderForUnknownNumber" \
            "CscFeature_Contact_SupportSmartCall"

        local INJECT
        INJECT="$(printf \
            '    <CscFeature_Common_ConfigSvcProviderForUnknownNumber>%s</CscFeature_Common_ConfigSvcProviderForUnknownNumber>\n    <CscFeature_Contact_SupportSmartCall>true</CscFeature_Contact_SupportSmartCall>' \
            "$SC_PROVIDER_FULL")"

        xml_inject "$CSC_FILE" "FeatureSet" "$INJECT"
        LOG "  Patched: $CSC_FILE"
        COUNT=$(( COUNT + 1 ))
    done < <(find "${DIRS[@]}" -type f -name "cscfeature.xml" -print0 2>/dev/null)

    [ "$COUNT" -eq 0 ] && WARN "No cscfeature.xml files found in optics/prism." || LOG "$COUNT CSC file(s) patched."
}

# ---------------------------------------------------------------------------
# 3. build.prop
# ---------------------------------------------------------------------------

patch_build_prop()
{
    [ -f "$PROP_PATH" ] || { WARN "build.prop not found — skipping."; return 0; }

    LOG "Patching build.prop..."
    sed -i '/ro.config.smart_call_supported/d' "$PROP_PATH"
    echo "ro.config.smart_call_supported=true" >> "$PROP_PATH"
    LOG "build.prop patched."
}

# ---------------------------------------------------------------------------
# 4. Smali hook — SemCscFeature getString + getBoolean
#
# Injects an early-return hook immediately after .locals in each whitelisted
# method so the patched values are returned before the original lookup runs.
# Uses a single awk pass (no temp-file races, atomic via mv).
# ---------------------------------------------------------------------------

patch_smali()
{
    local CSC_SMALI
    CSC_SMALI="$(find "$WORK_DIR/apktool" -type f \
        -path "*/com/samsung/android/feature/SemCscFeature.smali" \
        -print -quit 2>/dev/null)"

    [ -n "$CSC_SMALI" ] && [ -f "$CSC_SMALI" ] \
        || { WARN "SemCscFeature.smali not found — skipping Smali patch."; return 0; }

    LOG "Patching SemCscFeature.smali..."

    local TMP
    TMP="$(mktemp)"

    awk \
        -v str_key="CscFeature_Common_ConfigSvcProviderForUnknownNumber" \
        -v str_val="$SC_PROVIDER_FULL" \
        -v bool_key="CscFeature_Contact_SupportSmartCall" \
        -v tag="$AUTHOR_TAG" \
    '
    # ── Track method context ────────────────────────────────────────────────
    /^\.method public whitelist getString\(Ljava\/lang\/String;.*\)Ljava\/lang\/String;/ {
        in_str  = 1
        in_bool = 0
        print; next
    }
    /^\.method public whitelist getBoolean\(Ljava\/lang\/String;.*\)Z/ {
        in_bool = 1
        in_str  = 0
        print; next
    }
    # Reset on any other method start so hooks do not bleed across methods
    /^\.method / {
        in_str  = 0
        in_bool = 0
    }

    # ── getString hook ──────────────────────────────────────────────────────
    in_str && /^[[:space:]]*\.locals/ {
        print
        cond = "cond_sc_str_" NR
        print "    # " tag
        print "    const-string v0, \"" str_key "\""
        print "    invoke-virtual {p1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z"
        print "    move-result v0"
        print "    if-eqz v0, :" cond
        print "    const-string v0, \"" str_val "\""
        print "    return-object v0"
        print "    :" cond
        in_str = 0
        next
    }

    # ── getBoolean hook ─────────────────────────────────────────────────────
    in_bool && /^[[:space:]]*\.locals/ {
        print
        cond = "cond_sc_bool_" NR
        print "    # " tag
        print "    const-string v0, \"" bool_key "\""
        print "    invoke-virtual {p1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z"
        print "    move-result v0"
        print "    if-eqz v0, :" cond
        print "    const/4 v0, 0x1"
        print "    return v0"
        print "    :" cond
        in_bool = 0
        next
    }

    { print }
    ' "$CSC_SMALI" > "$TMP" || { rm -f "$TMP"; DIE "awk failed on $CSC_SMALI"; }

    mv -f "$TMP" "$CSC_SMALI"
    LOG "SemCscFeature.smali patched."
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

echo "----------------------------------------------------"
LOG "RUNNING SMART CALL (CSC) MODULE"
echo "----------------------------------------------------"

[ -d "$WORK_DIR" ] || DIE "WORK_DIR not found: '$WORK_DIR'"

patch_floating_feature
patch_csc_features
patch_build_prop
patch_smali

LOG "CSC module complete."
