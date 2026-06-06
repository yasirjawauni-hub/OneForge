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

# ─── Shell compatibility guard ────────────────────────────────────────────────
# Detect shell — works on bash 3/4/5, zsh, ksh, dash
_SHELL_NAME="${BASH_VERSION:+bash}"
_SHELL_NAME="${_SHELL_NAME:-${ZSH_VERSION:+zsh}}"
_SHELL_NAME="${_SHELL_NAME:-sh}"

case "$_SHELL_NAME" in
    bash)
        if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
            echo "WARNING: bash < 4.0 detected; some features may be limited." >&2
        fi
        ;;
    zsh)
        # zsh array indexing starts at 1; emulate ksh for compatibility
        setopt KSH_ARRAYS SH_WORD_SPLIT 2>/dev/null || true
        ;;
    *)
        echo "WARNING: Unsupported shell ($SHELL). bash >= 4 recommended." >&2
        ;;
esac
unset _SHELL_NAME

# shellcheck disable=SC1007,SC2164

# ─── Platform detection ───────────────────────────────────────────────────────
_DETECT_OS()
{
    case "$(uname -s 2>/dev/null)" in
        Linux*)   echo "linux"  ;;
        Darwin*)  echo "darwin" ;;
        CYGWIN*|MINGW*|MSYS*)  echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

_DETECT_ARCH()
{
    case "$(uname -m 2>/dev/null)" in
        x86_64|amd64)          echo "x86_64"  ;;
        aarch64|arm64)         echo "aarch64" ;;
        armv7l|armv8l|arm*)    echo "arm"     ;;
        i?86)                  echo "x86"     ;;
        *)                     echo "unknown" ;;
    esac
}

HOST_OS="$(_DETECT_OS)"
HOST_ARCH="$(_DETECT_ARCH)"
export HOST_OS HOST_ARCH

# ─── Portable pwd ─────────────────────────────────────────────────────────────
# /bin/pwd -P resolves symlinks; fallback for macOS/BSD where -P may differ
_PWD()
{
    PWD= /bin/pwd -P 2>/dev/null || pwd -P 2>/dev/null || echo "$PWD"
}

# ─── Source tree detection ────────────────────────────────────────────────────
_GET_SRC_DIR()
{
    local TOPFILE="unica/configs/version.sh"

    # Fast path: SRC_DIR already set and valid.
    if [ -n "${SRC_DIR:-}" ] && [ -f "$SRC_DIR/$TOPFILE" ]; then
        (cd "$SRC_DIR" && _PWD)
        return
    fi

    # Check CWD.
    if [ -f "$TOPFILE" ]; then
        _PWD
        return
    fi

    # Walk up the directory tree — POSIX-safe (no bashisms).
    local HERE
    HERE="$(_PWD)"
    local T=""
    local PREV=""
    while true; do
        \cd .. 2>/dev/null || break
        T="$(_PWD)"
        # Stop if we hit the filesystem root or stopped moving.
        [ "$T" = "$PREV" ] && break
        [ "$T" = "/" ]     && break
        PREV="$T"
        if [ -f "$T/$TOPFILE" ]; then
            \cd "$HERE"
            echo "$T"
            return
        fi
    done
    \cd "$HERE" 2>/dev/null || true
}

# ─── Usage ────────────────────────────────────────────────────────────────────
_PRINT_USAGE()
{
    echo "Usage: source buildenv.sh [--debug] [--help] <target>" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --debug    Enable debug output" >&2
    echo "  --help|-h  Show this help" >&2
    echo "" >&2
    echo "Host: $HOST_OS/$HOST_ARCH" >&2
    echo "" >&2
    echo "Available devices:" >&2
    printf '  %s\n' "${TARGETS[@]}" >&2
}

# ─── Navigation ───────────────────────────────────────────────────────────────
croot()
{
    if [ ! -d "${SRC_DIR:-}" ]; then
        echo "Couldn't locate the top of the tree. Try setting SRC_DIR." >&2
        return 1
    fi
    if [ -n "${1:-}" ]; then
        cd "$SRC_DIR/$1"
    else
        cd "$SRC_DIR"
    fi
}

# ─── Command runner ───────────────────────────────────────────────────────────
run_cmd()
{
    local CMD="${1:-}"
    local SCRIPT="$SRC_DIR/scripts/$CMD.sh"
    local LOG_DIR
    LOG_DIR="$(dirname "$WORK_DIR")"

    # Strip ANSI codes portably — use perl if sed -r unavailable (macOS)
    _strip_ansi()
    {
        if sed --version 2>&1 | grep -q GNU; then
            sed -r -e "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" -e "/#/d"
        else
            perl -pe 's/\e\[[\d;]*[mGK]//g; s/#.*\n?//'
        fi
    }

    if [ -x "$SCRIPT" ]; then
        shift
        mkdir -p "$LOG_DIR"
        local LOG_FILE="$LOG_DIR/$CMD-$(date +%Y%m%d_%H%M%S).log"
        (set -o pipefail
            "$SCRIPT" "$@" |& tee >("$(_strip_ansi)" > "$LOG_FILE"))
        return $?
    fi

    # Build sorted list of available commands.
    local CMDS=()
    while IFS= read -r f; do
        CMDS+=("$f")
    done < <(find "$SRC_DIR/scripts" -maxdepth 1 ! -type d -name "*.sh" \
             | sort | sed "s|.*/||; s/\.sh$//")

    case "${CMD:-}" in
        --help|-h)
            echo "Available cmds:" >&2
            local c
            for c in "${CMDS[@]}"; do
                printf '\n\033[1;37m%s:\033[0m\n' "$c" >&2
                "$SRC_DIR/scripts/$c.sh" --help
            done
            return 0
            ;;
        "")
            ;;
        *)
            printf '\033[0;31m"%s" is not a valid cmd.\033[0m\n' "$CMD" >&2
            ;;
    esac

    echo "Available cmds:" >&2
    printf '  %s\n' "${CMDS[@]}" >&2
    return 1
}

# ─── Aliases ──────────────────────────────────────────────────────────────────
alias unica='run_cmd'
alias extremerom='run_cmd'
alias erom='run_cmd'
alias m='./scripts/make_rom.sh'
alias quant='./scripts/make_rom.sh'

# ─── Resolve source root ──────────────────────────────────────────────────────
SRC_DIR="$(_GET_SRC_DIR)"
unset -f _GET_SRC_DIR _DETECT_OS _DETECT_ARCH _PWD

if [ -z "$SRC_DIR" ]; then
    echo "Couldn't locate the top of the tree. Always source buildenv.sh from the root of the tree." >&2
    return 1
fi

# ─── Export core dirs ─────────────────────────────────────────────────────────
export DEBUG=false
export SRC_DIR
export OUT_DIR="${OUT_DIR:-$SRC_DIR/out}"
export TMP_DIR="${TMP_DIR:-$OUT_DIR/tmp}"
export KERNEL_TMP_DIR="${KERNEL_TMP_DIR:-$OUT_DIR/kernel_tmp}"
export ODIN_DIR="${ODIN_DIR:-$OUT_DIR/odin}"
export FW_DIR="${FW_DIR:-$OUT_DIR/fw}"
export TOOLS_DIR="${TOOLS_DIR:-$OUT_DIR/tools}"

# Arch-aware tools bin: prefer host-specific subdir, fall back to generic.
_TOOLS_BIN="$TOOLS_DIR/bin/$HOST_OS/$HOST_ARCH"
[ -d "$_TOOLS_BIN" ] || _TOOLS_BIN="$TOOLS_DIR/bin"

# Prepend tools bin only once.
case ":$PATH:" in
    *":$_TOOLS_BIN:"*) ;;
    *) export PATH="$_TOOLS_BIN:$PATH" ;;
esac
unset _TOOLS_BIN

# ─── Discover targets ─────────────────────────────────────────────────────────
TARGETS=()
while IFS= read -r t; do
    TARGETS+=("$t")
done < <(find "$SRC_DIR/target" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" \
         2>/dev/null | sort)

# macOS/BSD fallback: -printf not supported
if [ ${#TARGETS[@]} -eq 0 ]; then
    while IFS= read -r t; do
        TARGETS+=("$(basename "$t")")
    done < <(find "$SRC_DIR/target" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "No targets found in $SRC_DIR/target — is the tree complete?" >&2
    return 1
fi

# ─── Parse flags ──────────────────────────────────────────────────────────────
while [ "${1:-}" != "${1#-}" ]; do
    case "$1" in
        --debug)    export DEBUG=true ;;
        --help|-h)  _PRINT_USAGE; return 0 ;;
        *)          echo "Unknown option: $1" >&2; _PRINT_USAGE; return 1 ;;
    esac
    shift
done

# ─── Select target ────────────────────────────────────────────────────────────
if [ "$#" -eq 0 ]; then
    echo "No target specified. Please choose from the available devices below:"
    select SELECTED_TARGET in "${TARGETS[@]}"; do
        [ -n "$SELECTED_TARGET" ] && break
        echo "Invalid selection. Please try again."
    done
elif [ "$#" -eq 1 ]; then
    SELECTED_TARGET="$1"
else
    echo "Too many arguments." >&2
    _PRINT_USAGE
    return 1
fi

if [ ! -d "$SRC_DIR/target/$SELECTED_TARGET" ]; then
    echo "\"$SELECTED_TARGET\" is not a valid device." >&2
    _PRINT_USAGE
    unset TARGETS SELECTED_TARGET
    return 1
fi

unset -f _PRINT_USAGE

# ─── Per-target dirs ──────────────────────────────────────────────────────────
export APKTOOL_DIR="$OUT_DIR/target/$SELECTED_TARGET/apktool"
export WORK_DIR="$OUT_DIR/target/$SELECTED_TARGET/work_dir"
mkdir -p "$OUT_DIR/target/$SELECTED_TARGET"

# ─── Load config ──────────────────────────────────────────────────────────────
if [ -f "$OUT_DIR/config.sh" ]; then
    # shellcheck disable=SC2046
    unset $(grep -v "Automatically" "$OUT_DIR/config.sh" \
            | grep "=" | cut -d "=" -f 1) 2>/dev/null || true
fi

"$SRC_DIR/scripts/internal/gen_config_file.sh" "$SELECTED_TARGET" || return 1
set -o allexport
source "$OUT_DIR/config.sh"
set +o allexport

# ─── Summary ──────────────────────────────────────────────────────────────────
echo "=============================="
echo "Host:   $HOST_OS / $HOST_ARCH"
echo "Target: $SELECTED_TARGET"
echo "SRC:    $SRC_DIR"
echo "OUT:    $OUT_DIR"
echo "------------------------------"
grep -v "Automatically" "$OUT_DIR/config.sh"
echo "=============================="

unset TARGETS SELECTED_TARGET
return 0
