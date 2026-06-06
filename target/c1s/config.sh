#
# Copyright (C) 2024 BlackMesa123
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

# ─── Shell compatibility guard ────────────────────────────────────────────────
if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "ERROR: requires bash >= 4.0" >&2
    return 1
fi

# ─── Universal device config resolver ────────────────────────────────────────
# _cfg <VAR> <default>
# Priority: environment → device-specific override file → default
# This single function is what makes the config universal — every value
# can be overridden per-device without touching this file.
_cfg()
{
    local VAR="$1"
    local DEFAULT="$2"
    # 1. Caller's environment wins
    if [ -n "${!VAR+x}" ]; then
        printf '%s' "${!VAR}"
        return
    fi
    # 2. Device override file (loaded below before _cfg calls)
    if [ -n "${_DEVICE_OVERRIDES[$VAR]+x}" ]; then
        printf '%s' "${_DEVICE_OVERRIDES[$VAR]}"
        return
    fi
    # 3. Hardcoded default
    printf '%s' "$DEFAULT"
}

# ─── Load device override file ────────────────────────────────────────────────
# Place a file at:
#   $SRC_DIR/target/<codename>/device.cfg
# containing lines of KEY=VALUE to override any setting below
# without modifying this universal template.
declare -A _DEVICE_OVERRIDES=()
_OVERRIDE_FILE="${SRC_DIR:-}/target/${TARGET_CODENAME:-}/device.cfg"
if [ -f "$_OVERRIDE_FILE" ]; then
    while IFS='=' read -r key val; do
        # Skip comments and blank lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        _DEVICE_OVERRIDES["$key"]="$val"
    done < "$_OVERRIDE_FILE"
fi
unset _OVERRIDE_FILE

# ─── Device identity ──────────────────────────────────────────────────────────
TARGET_NAME="$(_cfg TARGET_NAME             "Galaxy S10e (Exynos)")"
TARGET_CODENAME="$(_cfg TARGET_CODENAME     "beyond0lte")"
TARGET_PLATFORM="$(_cfg TARGET_PLATFORM     "exynos9820")"

# Space-separated list of all supported model numbers for this device.
# Add more models here to support regional variants without a new config file.
TARGET_ASSERT_MODEL="$(_cfg TARGET_ASSERT_MODEL "SM-G970F SM-G970N")"

# ─── Firmware ─────────────────────────────────────────────────────────────────
TARGET_FIRMWARE="$(_cfg TARGET_FIRMWARE             "SM-G970F/AUT/351585114819407")"
TARGET_EXTRA_FIRMWARES="$(_cfg TARGET_EXTRA_FIRMWARES "")"

# ─── API / VNDK versioning ────────────────────────────────────────────────────
TARGET_API_LEVEL="$(_cfg TARGET_API_LEVEL                       "31")"
TARGET_PRODUCT_FIRST_API_LEVEL="$(_cfg TARGET_PRODUCT_FIRST_API_LEVEL "28")"
# Defaults to API level unless explicitly different
TARGET_VNDK_VERSION="$(_cfg TARGET_VNDK_VERSION                 "$TARGET_API_LEVEL")"

# ─── Partition / image layout ─────────────────────────────────────────────────
# SSI types: essi | ssi | none
TARGET_SINGLE_SYSTEM_IMAGE="$(_cfg TARGET_SINGLE_SYSTEM_IMAGE   "essi")"
# Supported: ext4 | f2fs | erofs
TARGET_OS_FILE_SYSTEM="$(_cfg TARGET_OS_FILE_SYSTEM             "ext4")"
# Set to 0 if device does not use dynamic partitions (A-only devices)
TARGET_SUPER_PARTITION_SIZE="$(_cfg TARGET_SUPER_PARTITION_SIZE "0")"
TARGET_SUPER_GROUP_NAME="$(_cfg TARGET_SUPER_GROUP_NAME         "none")"
TARGET_SUPER_GROUP_SIZE="$(_cfg TARGET_SUPER_GROUP_SIZE         "0")"
# true if system_ext is a dedicated partition, false if it is inside system
TARGET_HAS_SYSTEM_EXT="$(_cfg TARGET_HAS_SYSTEM_EXT             "false")"

# ─── Display ──────────────────────────────────────────────────────────────────
# 1=sensor | 2=statistical | 3=hybrid | 4=advanced
TARGET_AUTO_BRIGHTNESS_TYPE="$(_cfg TARGET_AUTO_BRIGHTNESS_TYPE "4")"
TARGET_HAS_QHD_DISPLAY="$(_cfg TARGET_HAS_QHD_DISPLAY           "false")"
# none | left | right | center | double
TARGET_DISPLAY_CUTOUT_TYPE="$(_cfg TARGET_DISPLAY_CUTOUT_TYPE   "right")"

# mDNIE hardware display engine
TARGET_HAS_HW_MDNIE="$(_cfg TARGET_HAS_HW_MDNIE                         "true")"
TARGET_MDNIE_SUPPORTED_MODES="$(_cfg TARGET_MDNIE_SUPPORTED_MODES        "65303")"
# 0=off 1=weak 2=medium 3=strong
TARGET_MDNIE_WEAKNESS_SOLUTION_FUNCTION="$(_cfg TARGET_MDNIE_WEAKNESS_SOLUTION_FUNCTION "3")"

# ─── High-frame-rate (HFR) ────────────────────────────────────────────────────
# 0=disabled 1=enabled
TARGET_HFR_MODE="$(_cfg TARGET_HFR_MODE                                 "0")"
TARGET_HFR_SUPPORTED_REFRESH_RATE="$(_cfg TARGET_HFR_SUPPORTED_REFRESH_RATE "60")"
TARGET_HFR_DEFAULT_REFRESH_RATE="$(_cfg TARGET_HFR_DEFAULT_REFRESH_RATE "60")"
# "none" if seamless switching is not supported on this panel
TARGET_HFR_SEAMLESS_BRT="$(_cfg TARGET_HFR_SEAMLESS_BRT                 "none")"
TARGET_HFR_SEAMLESS_LUX="$(_cfg TARGET_HFR_SEAMLESS_LUX                 "none")"

# ─── Connectivity ─────────────────────────────────────────────────────────────
TARGET_SUPPORT_WIFI_7="$(_cfg TARGET_SUPPORT_WIFI_7                         "false")"
TARGET_SUPPORT_HOTSPOT_DUALAP="$(_cfg TARGET_SUPPORT_HOTSPOT_DUALAP         "false")"
TARGET_SUPPORT_HOTSPOT_WPA3="$(_cfg TARGET_SUPPORT_HOTSPOT_WPA3             "false")"
TARGET_SUPPORT_HOTSPOT_6GHZ="$(_cfg TARGET_SUPPORT_HOTSPOT_6GHZ             "false")"
TARGET_SUPPORT_HOTSPOT_WIFI_6="$(_cfg TARGET_SUPPORT_HOTSPOT_WIFI_6         "true")"
TARGET_SUPPORT_HOTSPOT_ENHANCED_OPEN="$(_cfg TARGET_SUPPORT_HOTSPOT_ENHANCED_OPEN "false")"

# ─── NFC ──────────────────────────────────────────────────────────────────────
# Supported vendors: SLSI | NXP | ST
TARGET_NFC_CHIP_VENDOR="$(_cfg TARGET_NFC_CHIP_VENDOR   "SLSI")"
TARGET_IS_ESIM_SUPPORTED="$(_cfg TARGET_IS_ESIM_SUPPORTED "false")"

# ─── Biometrics ───────────────────────────────────────────────────────────────
# Format: <type>,settings=<N>,navi=<N>
# Types: google_touch_side | google_touch_udfps | goodix_touch_udfps | none
TARGET_FP_SENSOR_CONFIG="$(_cfg TARGET_FP_SENSOR_CONFIG "google_touch_side,settings=3,navi=1")"

# ─── Camera ───────────────────────────────────────────────────────────────────
TARGET_HAS_MASS_CAMERA_APP="$(_cfg TARGET_HAS_MASS_CAMERA_APP "false")"

# ─── DVFS (CPU/GPU frequency scaling) ────────────────────────────────────────
TARGET_DVFS_CONFIG_NAME="$(_cfg TARGET_DVFS_CONFIG_NAME "dvfs_policy_makalu_xx")"

# ─── Audio ────────────────────────────────────────────────────────────────────
TARGET_AUDIO_SUPPORT_ACH_RINGTONE="$(_cfg TARGET_AUDIO_SUPPORT_ACH_RINGTONE   "false")"
TARGET_AUDIO_SUPPORT_VIRTUAL_VIBRATION="$(_cfg TARGET_AUDIO_SUPPORT_VIRTUAL_VIBRATION "false")"

# ─── Runtime validation ───────────────────────────────────────────────────────
_validate_config()
{
    local ERRORS=0

    # Required non-empty fields
    local REQUIRED=(
        TARGET_NAME TARGET_CODENAME TARGET_PLATFORM
        TARGET_FIRMWARE TARGET_API_LEVEL
        TARGET_PRODUCT_FIRST_API_LEVEL TARGET_VNDK_VERSION
        TARGET_OS_FILE_SYSTEM
    )
    local v
    for v in "${REQUIRED[@]}"; do
        if [ -z "${!v:-}" ]; then
            echo "CONFIG ERROR: $v must not be empty" >&2
            ERRORS=$(( ERRORS + 1 ))
        fi
    done

    # API level must be a positive integer
    case "$TARGET_API_LEVEL" in
        ''|*[!0-9]*)
            echo "CONFIG ERROR: TARGET_API_LEVEL must be a positive integer" >&2
            ERRORS=$(( ERRORS + 1 )) ;;
    esac

    # File system must be a known type
    case "$TARGET_OS_FILE_SYSTEM" in
        ext4|f2fs|erofs) ;;
        *) echo "CONFIG ERROR: TARGET_OS_FILE_SYSTEM \"$TARGET_OS_FILE_SYSTEM\" \
not supported (ext4/f2fs/erofs)" >&2
           ERRORS=$(( ERRORS + 1 )) ;;
    esac

    # NFC vendor must be known
    case "$TARGET_NFC_CHIP_VENDOR" in
        SLSI|NXP|ST) ;;
        *) echo "CONFIG WARN: Unknown NFC vendor \"$TARGET_NFC_CHIP_VENDOR\"" >&2 ;;
    esac

    # Super partition consistency
    if [ "${TARGET_SUPER_PARTITION_SIZE:-0}" -gt 0 ] 2>/dev/null; then
        if [ "$TARGET_SUPER_GROUP_NAME" = "none" ]; then
            echo "CONFIG ERROR: SUPER_PARTITION_SIZE > 0 but SUPER_GROUP_NAME is \"none\"" >&2
            ERRORS=$(( ERRORS + 1 ))
        fi
    fi

    # VNDK must be <= API level
    if [ "$TARGET_VNDK_VERSION" -gt "$TARGET_API_LEVEL" ] 2>/dev/null; then
        echo "CONFIG ERROR: TARGET_VNDK_VERSION ($TARGET_VNDK_VERSION) \
cannot exceed TARGET_API_LEVEL ($TARGET_API_LEVEL)" >&2
        ERRORS=$(( ERRORS + 1 ))
    fi

    # First API level must be <= current API level
    if [ "$TARGET_PRODUCT_FIRST_API_LEVEL" -gt "$TARGET_API_LEVEL" ] 2>/dev/null; then
        echo "CONFIG ERROR: TARGET_PRODUCT_FIRST_API_LEVEL \
($TARGET_PRODUCT_FIRST_API_LEVEL) cannot exceed TARGET_API_LEVEL ($TARGET_API_LEVEL)" >&2
        ERRORS=$(( ERRORS + 1 ))
    fi

    [ "$ERRORS" -eq 0 ] || return 1
}

_validate_config || return 1
unset -f _validate_config _cfg
unset _DEVICE_OVERRIDES
