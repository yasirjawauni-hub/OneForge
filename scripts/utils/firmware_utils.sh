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
source "$SRC_DIR/scripts/utils/build_utils.sh" || return 1

# ─── Shell compatibility guard ────────────────────────────────────────────────
if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "ERROR: build_utils.sh requires bash >= 4.0" >&2
    return 1
fi

# ─── Internal helpers ─────────────────────────────────────────────────────────

# _CHAR_TO_ORD <char>
# Returns the ASCII ordinal of a single character (POSIX-safe, no printf %d).
_CHAR_TO_ORD()
{
    local c="$1"
    # Use LC_CTYPE=C so printf %d works on the byte value portably.
    LC_CTYPE=C printf '%d' "'$c"
}

# _STR_COMPARE <a> <b>
# Lexicographic comparison of two single characters.
# Returns 0 if a > b, 1 if a < b, 2 if a == b.
_STR_COMPARE()
{
    local a="$1" b="$2"
    local oa ob
    oa="$(_CHAR_TO_ORD "$a")"
    ob="$(_CHAR_TO_ORD "$b")"
    if   (( oa > ob )); then return 0
    elif (( oa < ob )); then return 1
    else                     return 2
    fi
}

# ─── Public API ───────────────────────────────────────────────────────────────

# COMPARE_SEC_BUILD_VERSION <string1> <string2>
# Returns 0 (true) if string1 is newer than OR equal to string2, 1 if older.
#
# Samsung build version scheme (e.g. A528BXXU1DWA4):
#   [Model][Region][FW-type][Rollback][Major][Year][Month][Incremental]
#   The last 4 chars encode Major / Year / Month / Incremental.
COMPARE_SEC_BUILD_VERSION()
{
    _CHECK_NON_EMPTY_PARAM "STRING1" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "STRING2" "$2" || return 1

    # Strip everything after the first "/" (PDA field only).
    local S1="${1%%/*}"
    local S2="${2%%/*}"

    # Validate: we need at least 4 trailing version chars.
    if (( ${#S1} < 4 || ${#S2} < 4 )); then
        LOGE "COMPARE_SEC_BUILD_VERSION: string too short (\"$1\" / \"$2\")"
        return 1
    fi

    # Extract the 4 version chars from the tail using pure-bash substrings
    # (avoids four 'cut' subshells from the original implementation).
    local S1_MAJOR="${S1: -4:1}"  S1_YEAR="${S1: -3:1}"
    local S1_MONTH="${S1: -2:1}"  S1_INC="${S1: -1:1}"

    local S2_MAJOR="${S2: -4:1}"  S2_YEAR="${S2: -3:1}"
    local S2_MONTH="${S2: -2:1}"  S2_INC="${S2: -1:1}"

    local -a S1_PARTS=( "$S1_MAJOR" "$S1_YEAR" "$S1_MONTH" "$S1_INC" )
    local -a S2_PARTS=( "$S2_MAJOR" "$S2_YEAR" "$S2_MONTH" "$S2_INC" )

    local i rc
    for (( i = 0; i < 4; i++ )); do
        _STR_COMPARE "${S1_PARTS[$i]}" "${S2_PARTS[$i]}"
        rc=$?
        (( rc == 0 )) && return 0   # S1 component is greater → newer
        (( rc == 1 )) && return 1   # S1 component is lesser  → older
        # rc == 2 → equal, continue to next component
    done

    return 0   # All components equal → treat as "not older"
}

# EXTRACT_FILE_FROM_TAR <tar> <file>
# Extracts <file> from <tar>, handling bare / .ext4 / .lz4 variants.
# Cleans up any stale copy before extracting.
EXTRACT_FILE_FROM_TAR()
{
    _CHECK_NON_EMPTY_PARAM "MODEL" "$MODEL" || return 1
    _CHECK_NON_EMPTY_PARAM "CSC"   "$CSC"   || return 1
    _CHECK_NON_EMPTY_PARAM "TAR"   "$1"     || return 1
    _CHECK_NON_EMPTY_PARAM "FILE"  "$2"     || return 1

    local TAR="$1"
    local FILE="$2"
    local DEST_DIR="$FW_DIR/${MODEL}_${CSC}"

    [[ -f "$TAR" ]] || {
        LOGE "File not found: ${TAR//$SRC_DIR\//}"
        return 1
    }

    # Remove any stale variants atomically before extracting.
    rm -f "$DEST_DIR/$FILE" "$DEST_DIR/$FILE.ext4" "$DEST_DIR/$FILE.lz4"

    if FILE_EXISTS_IN_TAR "$TAR" "$FILE"; then
        LOG "- Extracting $FILE from $(basename "$TAR")..."
        EVAL "tar xf \"$TAR\" -C \"$DEST_DIR\" \"$FILE\"" || return 1

    elif FILE_EXISTS_IN_TAR "$TAR" "$FILE.ext4"; then
        LOG "- Extracting $FILE.ext4 from $(basename "$TAR")..."
        EVAL "tar xf \"$TAR\" -C \"$DEST_DIR\" \"$FILE.ext4\"" || return 1
        mv -f "$DEST_DIR/$FILE.ext4" "$DEST_DIR/$FILE"              || return 1

    elif FILE_EXISTS_IN_TAR "$TAR" "$FILE.lz4"; then
        LOG "- Extracting $FILE.lz4 from $(basename "$TAR")..."
        EVAL "tar xf \"$TAR\" -C \"$DEST_DIR\" \"$FILE.lz4\"" || return 1
        LOG "- Decompressing $FILE.lz4..."
        # --rm removes the .lz4 source after decompression; -d = decompress.
        EVAL "lz4 -d --rm \"$DEST_DIR/$FILE.lz4\" \"$DEST_DIR/$FILE\"" || return 1

    else
        LOGE "\"$FILE\" not found in $(basename "$TAR") (tried bare/.ext4/.lz4)"
        return 1
    fi

    return 0
}

# FILE_EXISTS_IN_TAR <tar> <file>
# Returns 0 if <file> exists inside <tar>, 1 otherwise.
FILE_EXISTS_IN_TAR()
{
    _CHECK_NON_EMPTY_PARAM "TAR"  "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE" "$2" || return 1

    tar tf "$1" "$2" &>/dev/null
}

# GET_LATEST_FIRMWARE <model> <csc>
# Fetches and prints the latest firmware string (PDA/CSC/MODEM) from Samsung FOTA servers.
GET_LATEST_FIRMWARE()
{
    _CHECK_NON_EMPTY_PARAM "MODEL" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "CSC"   "$2" || return 1

    local MODEL_ARG="$1"
    local CSC_ARG="$2"
    local URL="https://fota-cloud-dn.ospserver.net/firmware/${CSC_ARG}/${MODEL_ARG}/version.xml"
    local OUT

    # --fail    → non-zero on HTTP 4xx/5xx
    # --silent  → suppress progress meter
    # --show-error → still print errors to stderr
    OUT="$(curl --fail --silent --show-error \
               --retry 5 --retry-delay 5 \
               --max-time 30 \
               "$URL")" || {
        LOGE "Failed to fetch firmware version for ${MODEL_ARG}/${CSC_ARG}"
        return 1
    }

    # Use awk instead of perl for portability (not all build hosts have perl).
    awk 'match($0, /<latest[^>]*>([^<]+)<\/latest>/, a) { print a[1] }' <<< "$OUT"
}

# PARSE_FIRMWARE_STRING <model>/<csc>/<imei-or-sn>
# Validates and exports MODEL, CSC, and either IMEI or SERIAL_NO.
PARSE_FIRMWARE_STRING()
{
    local STRING="${1:-}"

    [[ -n "$STRING" ]] || {
        LOGE "Firmware value cannot be empty"
        return 1
    }

    # Split on "/" using read for a single pass (faster than three 'cut' calls).
    local MODEL_V CSC_V THIRD_V EXTRA_V
    IFS='/' read -r MODEL_V CSC_V THIRD_V EXTRA_V <<< "$STRING"

    # Model
    [[ -n "$MODEL_V" ]] || {
        LOGE "No device model value found in \"$STRING\""
        return 1
    }

    # CSC — must be exactly 3 characters
    [[ -n "$CSC_V" ]] || {
        LOGE "No CSC value found in \"$STRING\""
        return 1
    }
    (( ${#CSC_V} == 3 )) || {
        LOGE "CSC not valid in \"$STRING\": $CSC_V"
        return 1
    }

    # IMEI / Serial number
    [[ -n "$THIRD_V" ]] || {
        LOGE "No IMEI/SN value found in \"$STRING\""
        return 1
    }

    # Serial: 11 chars starting with "R"
    if (( ${#THIRD_V} == 11 )) && [[ "$THIRD_V" == R* ]]; then
        SERIAL_NO="$THIRD_V"
        unset IMEI
    # IMEI: 8–15 digits (partial TAC allowed for samloader compatibility)
    elif (( ${#THIRD_V} >= 8 && ${#THIRD_V} <= 15 )) && [[ "$THIRD_V" =~ ^[0-9]+$ ]]; then
        IMEI="$THIRD_V"
        unset SERIAL_NO
    else
        LOGE "No valid IMEI/SN in \"$STRING\": $THIRD_V"
        return 1
    fi

    [[ -n "$EXTRA_V" ]] && LOGW "Extra fields ignored in firmware string: \"$STRING\""

    # Export only after all validation passes.
    MODEL="$MODEL_V"
    CSC="$CSC_V"
    return 0
}

# UNSPARSE_IMAGE <file> [output]
# Converts an Android sparse image to a raw image in-place or to [output].
UNSPARSE_IMAGE()
{
    _CHECK_NON_EMPTY_PARAM "FILE" "$1" || return 1

    local FILE="$1"
    local OUTPUT_PATH="${2:-}"
    local REPLACE=false

    [[ -f "$FILE" ]] || {
        LOGE "File not found: ${FILE//$SRC_DIR\//}"
        return 1
    }

    IS_SPARSE_IMAGE "$FILE" || {
        LOGW "Not an Android sparse image: ${FILE//$SRC_DIR\//}"
        return 0
    }

    if [[ -z "$OUTPUT_PATH" ]]; then
        # Write to a sibling temp file to keep the same directory (avoids
        # cross-device mv if /tmp is on a different filesystem).
        OUTPUT_PATH="${FILE}.unsparse.$$"
        REPLACE=true
    fi

    LOG "- Unsparsing $(basename "$FILE")..."
    EVAL "simg2img \"$FILE\" \"$OUTPUT_PATH\"" || {
        rm -f "$OUTPUT_PATH"
        return 1
    }

    if $REPLACE; then
        mv -f "$OUTPUT_PATH" "$FILE"
    fi

    return 0
}
