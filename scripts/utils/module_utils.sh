#
# Copyright (C) 2025 Salvo Giangreco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

# ─── Bootstrap ────────────────────────────────────────────────────────────────
source "$SRC_DIR/scripts/utils/smali_utils.sh"

# ─── Shell compatibility guard ────────────────────────────────────────────────
# Require bash 4.0+ for associative arrays and other features used below.
if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "ERROR: module_utils.sh requires bash >= 4.0" >&2
    return 1
fi

# ─── Internal helpers ─────────────────────────────────────────────────────────

# _GET_PROP_LOCATION [partition] <prop>
# Prints the list of prop files that contain the given key.
_GET_PROP_LOCATION()
{
    local FILES
    FILES="$(_GET_PROP_FILES_PATH "$1")"

    if IS_VALID_PARTITION_NAME "$1"; then
        shift
    fi

    _CHECK_NON_EMPTY_PARAM "PROP" "$1" || return 1

    local PROP="$1"
    local f

    # Use process substitution to avoid a subshell; faster than piping.
    while IFS= read -r f; do
        [[ -f "$f" ]] && grep -q "^${PROP}=" "$f" 2>/dev/null && printf '%s\n' "$f"
    done <<< "$FILES"
}

# _SANITISE_PATH <path>
# Strips leading slashes from a path fragment.
_SANITISE_PATH()
{
    local p="$1"
    while [[ "${p:0:1}" == "/" ]]; do
        p="${p:1}"
    done
    printf '%s' "$p"
}

# _PROP_FILE_FOR_PARTITION <partition>
# Resolves the canonical build.prop path for the given partition.
_PROP_FILE_FOR_PARTITION()
{
    local PARTITION="$1"
    case "$PARTITION" in
        system)       printf '%s/system/system/build.prop'                    "$WORK_DIR" ;;
        system_ext)
            if "${TARGET_HAS_SYSTEM_EXT:-false}"; then
                      printf '%s/system_ext/etc/build.prop'                   "$WORK_DIR"
            else
                      printf '%s/system/system/system_ext/etc/build.prop'     "$WORK_DIR"
            fi ;;
        system_dlkm)  printf '%s/system_dlkm/etc/build.prop'                  "$WORK_DIR" ;;
        vendor)       printf '%s/vendor/build.prop'                            "$WORK_DIR" ;;
        vendor_dlkm)  printf '%s/vendor_dlkm/etc/build.prop'                  "$WORK_DIR" ;;
        odm_dlkm)     printf '%s/vendor/odm_dlkm/etc/build.prop'              "$WORK_DIR" ;;
        odm)          printf '%s/odm/etc/build.prop'                           "$WORK_DIR" ;;
        product)      printf '%s/product/etc/build.prop'                       "$WORK_DIR" ;;
        *)            return 1 ;;
    esac
}

# ─── Public API ───────────────────────────────────────────────────────────────

# ABORT [message]
# Stops the build process and optionally logs a message.
ABORT()
{
    [[ -n "${1:-}" ]] && LOGE "$1"
    return 1
}

# APPLY_PATCH <partition> <apk/jar> <patch>
# Applies a unified diff patch to the decoded APK/JAR directory.
APPLY_PATCH()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE"      "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "PATCH"     "$3" || return 1

    local PARTITION="$1"
    local FILE
    FILE="$(_SANITISE_PATH "$2")"
    local PATCH="$3"

    IS_VALID_PARTITION_NAME "$PARTITION" || {
        LOGE "\"$PARTITION\" is not a valid partition name"
        return 1
    }

    [[ -f "$PATCH" ]] || {
        LOGE "File not found: ${PATCH//$SRC_DIR\//}"
        return 1
    }

    DECODE_APK "$PARTITION" "$FILE" || return 1

    local SUBJECT
    SUBJECT="$(grep "^Subject:" "$PATCH" | sed 's/.*PATCH] //; s/.*PATCH .\/.] //')"
    LOG "- Applying \"$SUBJECT\" to /$PARTITION/$FILE"

    EVAL "LC_ALL=C git apply \
        --directory=\"$APKTOOL_DIR/$PARTITION/${FILE//system\//}\" \
        --verbose --unsafe-paths \"$PATCH\""
}

# DECODE_APK <partition> <apk/jar>
# Decodes the APK/JAR with apktool; skips if already decoded.
DECODE_APK()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE"      "$2" || return 1

    local PARTITION="$1"
    local FILE="${2//system\//}"   # normalise once, reuse

    if [[ ! -d "$APKTOOL_DIR/$PARTITION/$FILE" ]]; then
        "$SRC_DIR/scripts/apktool.sh" d "$PARTITION" "$2"
        return $?
    fi

    return 0
}

# DOWNLOAD_FILE <url> <output path>
# Downloads a file with retry logic, checksum-safe atomic write, and a
# progress indicator. Requires curl >= 7.x (available on all modern platforms).
DOWNLOAD_FILE()
{
    _CHECK_NON_EMPTY_PARAM "URL"    "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "OUTPUT" "$2" || return 1

    local URL="$1"
    local OUTPUT="$2"
    local TMP="${OUTPUT}.tmp.$$"
    local RETRIES=3
    local ATTEMPT=0

    mkdir -p "$(dirname "$OUTPUT")"

    while (( ATTEMPT < RETRIES )); do
        (( ATTEMPT++ ))
        # --fail        → non-zero exit on HTTP errors (4xx/5xx)
        # --location    → follow redirects
        # --retry 2     → curl-level retry on transient network errors
        # --retry-delay → back-off between curl retries
        # --silent + --show-error → suppress progress but still show errors
        if EVAL "curl --fail --location --retry 2 --retry-delay 3 \
                      --silent --show-error \
                      -o \"$TMP\" \"$URL\""; then
            mv "$TMP" "$OUTPUT"
            return 0
        fi

        LOGW "Download attempt $ATTEMPT/$RETRIES failed for: $URL"
        rm -f "$TMP"
        sleep $(( ATTEMPT * 2 ))
    done

    LOGE "All $RETRIES download attempts failed for: $URL"
    return 1
}

# GET_GALAXY_STORE_DOWNLOAD_URL <package name>
# Returns a download URI from Samsung servers for the given package.
GET_GALAXY_STORE_DOWNLOAD_URL()
{
    _CHECK_NON_EMPTY_PARAM "PACKAGE" "$1" || return 1

    local PACKAGE="$1"
    local SDK_VER ONE_UI_VER
    SDK_VER="$(GET_PROP "system" "ro.build.version.sdk")"
    ONE_UI_VER="$(GET_PROP "system" "ro.build.version.oneui")"
    local OS="sdkVer=${SDK_VER}&oneUiVersion=${ONE_UI_VER}"

    # Device profiles: add entries here to support more regions/models.
    local -a DEVICES=(
        "deviceId=SM-S928B&mcc=262&mnc=01&csc=EUX"   # S23 Ultra EUR
        "deviceId=SM-S9380&mcc=460&mnc=00&csc=CHC"   # S25 Ultra CHN
    )

    local i OUT
    for i in "${DEVICES[@]}"; do
        OUT="$(curl --fail --location --silent --show-error \
            "https://vas.samsungapps.com/stub/stubDownload.as?appId=${PACKAGE}&${i}&${OS}&extuk=0191d6627f38685f&pd=0")" || continue

        if grep -q "Download URI Available" <<< "$OUT"; then
            grep "downloadURI" <<< "$OUT" \
                | cut -d ">" -f 2 \
                | sed -e 's/<!\[CDATA\[//g; s/\]\]//g'
            return 0
        fi
    done

    LOGE "No download URI found for app \"$PACKAGE\""
    return 1
}

# GET_FLOATING_FEATURE_CONFIG <config>
# Returns the value of a SecFloatingFeatureSet entry.
GET_FLOATING_FEATURE_CONFIG()
{
    _CHECK_NON_EMPTY_PARAM "CONFIG" "$1" || return 1

    local CONFIG="$1"
    local FILE="$WORK_DIR/system/system/etc/floating_feature.xml"

    [[ -f "$FILE" ]] || {
        LOGE "File not found: ${FILE//$WORK_DIR/}"
        return 1
    }

    # grep -oP is a GNU extension; fall back to POSIX awk for macOS/BSD hosts.
    if grep --version 2>&1 | grep -q "GNU"; then
        grep -oP "(?<=<${CONFIG}>)[^<]+" "$FILE" 2>/dev/null
    else
        awk -v tag="$CONFIG" \
            'match($0, "<"tag">([^<]+)</"tag">", a) { print a[1] }' "$FILE"
    fi
}

# HEX_PATCH <file> <old hex pattern> <new hex pattern>
# Applies a hex-level binary patch; idempotent and atomic.
HEX_PATCH()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FROM" "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "TO"   "$3" || return 1

    local FILE="$1"
    local FROM TO
    # Normalise to lower-case, strip any embedded whitespace supplied by caller.
    FROM="$(tr -d '[:space:]' <<< "$2" | tr '[:upper:]' '[:lower:]')"
    TO="$(tr   -d '[:space:]' <<< "$3" | tr '[:upper:]' '[:lower:]')"

    [[ -f "$FILE" ]] || {
        LOGE "File not found: ${FILE//$WORK_DIR/}"
        return 1
    }

    # Read hex once into a variable to avoid three xxd invocations.
    local HEX_CONTENT
    HEX_CONTENT="$(xxd -p "$FILE" | tr -d '\n ')"

    if [[ "$HEX_CONTENT" == *"$TO"* ]]; then
        LOGW "\"$TO\" already applied in ${FILE//$WORK_DIR/}"
        return 0
    fi

    if [[ "$HEX_CONTENT" != *"$FROM"* ]]; then
        LOGE "No \"$FROM\" match in ${FILE//$WORK_DIR/}"
        return 1
    fi

    LOG "- Patching \"$FROM\" → \"$TO\" in ${FILE//$WORK_DIR/}"

    # Atomic write: patch to a temp file, then replace.
    local TMP="${FILE}.tmp.$$"
    printf '%s' "${HEX_CONTENT//$FROM/$TO}" | xxd -r -p > "$TMP" || {
        rm -f "$TMP"
        LOGE "xxd write failed for ${FILE//$WORK_DIR/}"
        return 1
    }
    mv "$TMP" "$FILE"
}

# SET_FLOATING_FEATURE_CONFIG <config> <value|-d|--delete>
# Sets or deletes a SecFloatingFeatureSet entry; atomic and idempotent.
SET_FLOATING_FEATURE_CONFIG()
{
    _CHECK_NON_EMPTY_PARAM "CONFIG" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "VALUE"  "$2" || return 1

    local CONFIG="$1"
    local VALUE="$2"
    local FILE="$WORK_DIR/system/system/etc/floating_feature.xml"
    local LOG_PATH="/system/system/etc/floating_feature.xml"

    [[ -f "$FILE" ]] || {
        LOGE "File not found: ${FILE//$WORK_DIR/}"
        return 1
    }

    local DELETE=false
    [[ "$VALUE" == "-d" || "$VALUE" == "--delete" ]] && DELETE=true

    if grep -q "$CONFIG" "$FILE"; then
        if $DELETE; then
            LOG "- Deleting \"$CONFIG\" in $LOG_PATH"
            sed -i "/$CONFIG/d" "$FILE"
        else
            LOG "- Replacing \"$CONFIG\" with \"$VALUE\" in $LOG_PATH"
            # Use a numeric address to avoid regex quoting issues with complex values.
            local LINE_NUM
            LINE_NUM="$(grep -n "<${CONFIG}>" "$FILE" | head -1 | cut -d: -f1)"
            sed -i "${LINE_NUM}c\\    <${CONFIG}>${VALUE}</${CONFIG}>" "$FILE"
        fi
    elif ! $DELETE; then
        LOG "- Adding \"$CONFIG\" = \"$VALUE\" in $LOG_PATH"
        # Remove closing tag, append new entry, re-add closing tag.
        sed -i "/<\/SecFloatingFeatureSet>/d" "$FILE"
        grep -q "Added by scripts" "$FILE" || \
            printf '    <!-- Added by scripts/utils/module_utils.sh -->\n' >> "$FILE"
        printf '    <%s>%s</%s>\n' "$CONFIG" "$VALUE" "$CONFIG" >> "$FILE"
        printf '</SecFloatingFeatureSet>\n' >> "$FILE"
    fi

    return 0
}

# SET_PROP <partition> <prop> <value|-d|--delete>
# Sets, adds, or deletes a build prop; partition CANNOT be omitted.
SET_PROP()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "PROP"      "$2" || return 1

    local PARTITION="$1"
    local PROP="$2"
    local VALUE="${3:-}"

    IS_VALID_PARTITION_NAME "$PARTITION" || {
        LOGE "\"$PARTITION\" is not a valid partition name"
        return 1
    }

    local DELETE=false
    [[ "$VALUE" == "-d" || "$VALUE" == "--delete" ]] && DELETE=true

    local CURRENT
    CURRENT="$(GET_PROP "$PARTITION" "$PROP")"

    if [[ -n "$CURRENT" ]]; then
        # Prop exists: update or delete it in every file that contains it.
        local FILES f
        FILES="$(_GET_PROP_LOCATION "$PARTITION" "$PROP")"

        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            local LOG_F="${f//$WORK_DIR/}"
            if $DELETE; then
                LOG "- Deleting \"$PROP\" in $LOG_F"
                sed -i "/^${PROP}=/d" "$f"
            else
                LOG "- Replacing \"$PROP\" = \"$VALUE\" in $LOG_F"
                # Use line-number addressing to be safe with special characters.
                local LINES
                LINES="$(grep -n "^${PROP}=" "$f" | cut -d: -f1)"
                while IFS= read -r l; do
                    [[ -n "$l" ]] && sed -i "${l}c\\${PROP}=${VALUE}" "$f"
                done <<< "$LINES"
            fi
        done <<< "$FILES"

    elif ! $DELETE; then
        # Prop doesn't exist yet: append to the canonical file.
        local FILE
        FILE="$(_PROP_FILE_FOR_PARTITION "$PARTITION")" || {
            LOGE "\"$PARTITION\" has no known build.prop location"
            return 1
        }

        if [[ ! -f "$FILE" ]]; then
            LOGW "File not found: ${FILE//$WORK_DIR/}"
            return 0
        fi

        LOG "- Adding \"$PROP\" = \"$VALUE\" in ${FILE//$WORK_DIR/}"
        grep -q "Added by scripts" "$FILE" || \
            printf '# Added by scripts/utils/module_utils.sh\n' >> "$FILE"
        printf '%s=%s\n' "$PROP" "$VALUE" >> "$FILE"
    fi

    return 0
}

# SET_PROP_IF_DIFF <partition> <prop> <expected value>
# Calls SET_PROP only when the current value differs from the expected one.
SET_PROP_IF_DIFF()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "PROP"      "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "EXPECTED"  "$3" || return 1

    local PARTITION="$1"
    local PROP="$2"
    local EXPECTED="$3"

    IS_VALID_PARTITION_NAME "$PARTITION" || {
        LOGE "\"$PARTITION\" is not a valid partition name"
        return 1
    }

    local CURRENT
    CURRENT="$(GET_PROP "$PARTITION" "$PROP")"

    # Skip if already at the desired value; set if absent or different.
    if [[ -z "$CURRENT" || "$CURRENT" != "$EXPECTED" ]]; then
        SET_PROP "$PARTITION" "$PROP" "$EXPECTED"
    fi
}
