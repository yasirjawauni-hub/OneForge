#!/bin/bash
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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# shellcheck disable=SC1007,SC2164,SC2291

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# BUILD <name> <dir> <cmd>...
# Run each command inside <dir>, aborting with a coloured error on failure.
BUILD()
{
    local PDR
    PDR="$(pwd)"

    local NAME="$1"; shift
    local DIR="$1";  shift
    local CMDS=("$@")

    LOG "- Building $NAME..."

    cd "$DIR"
    for CMD in "${CMDS[@]}"; do
        local OUT
        if ! OUT="$(eval "$CMD" 2>&1)"; then
            echo -e    '\033[1;31mBUILD FAILED!\033[0m\n'   >&2
            echo -e    '\033[0;31m'"$CMD"'\033[0m\n'        >&2
            echo -n -e '\033[0;33m'                         >&2
            echo -n    "$OUT"                               >&2
            echo -e    '\033[0m'                            >&2
            exit 1
        fi
    done

    cd "$PDR"
}

# CHECK_TOOLS <exec>...
# Returns 0 (true) if every executable already exists in $TOOLS_DIR/bin.
CHECK_TOOLS()
{
    local EXECUTABLES=("$@")
    for i in "${EXECUTABLES[@]}"; do
        [ ! -f "$TOOLS_DIR/bin/$i" ] && return 1
    done
    return 0
}

# GET_CMAKE_FLAGS
# Emit common CMake flags, enabling ccache when available.
GET_CMAKE_FLAGS()
{
    local FLAGS
    FLAGS="-DCMAKE_SYSTEM_NAME=\"$(uname -s)\" "
    FLAGS+="-DCMAKE_SYSTEM_PROCESSOR=\"$(uname -m)\" "
    FLAGS+="-DCMAKE_BUILD_TYPE=\"Release\" "
    if type ccache &>/dev/null; then
        FLAGS+="-DCMAKE_C_COMPILER_LAUNCHER=\"ccache\" "
        FLAGS+="-DCMAKE_CXX_COMPILER_LAUNCHER=\"ccache\" "
    fi
    FLAGS+="-DCMAKE_C_COMPILER=\"clang\" "
    FLAGS+="-DCMAKE_CXX_COMPILER=\"clang++\""
    echo "$FLAGS"
}

# https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/envsetup.sh#18
GET_SRC_DIR()
{
    local TOPFILE="unica/configs/version.sh"
    if [ -n "${SRC_DIR:-}" ] && [ -f "$SRC_DIR/$TOPFILE" ]; then
        (cd "$SRC_DIR"; PWD= /bin/pwd)
        return
    fi
    if [ -f "$TOPFILE" ]; then
        PWD= /bin/pwd
        return
    fi
    local HERE="$PWD" T=
    while [ ! -f "$TOPFILE" ] && [ "$PWD" != "/" ]; do
        \cd ..
        T="$(PWD= /bin/pwd -P)"
    done
    \cd "$HERE"
    [ -f "$T/$TOPFILE" ] && echo "$T"
}

# https://github.com/canonical/snapd/blob/ec7ea857712028b7e3be7a5f4448df575216dbfd/release/release.go#L169-L190
IS_WSL()
{
    if [ -e "/proc/sys/fs/binfmt_misc/WSLInterop" ] || [ -e "/run/WSL" ]; then
        echo "ON"
    else
        echo "OFF"
    fi
}

# ---------------------------------------------------------------------------
# Bootstrap — locate source tree
# ---------------------------------------------------------------------------

SRC_DIR="$(GET_SRC_DIR)"
if [ -z "$SRC_DIR" ]; then
    echo "Couldn't locate the top of the tree. Try setting SRC_DIR." >&2
    exit 1
fi
source "$SRC_DIR/scripts/utils/log_utils.sh" || exit 1

OUT_DIR="$SRC_DIR/out"
TOOLS_DIR="$OUT_DIR/tools"
mkdir -p "$TOOLS_DIR/bin"

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------

usage()
{
    echo "Usage: $(basename "$0" | sed 's/build_dependencies.sh/build_dependencies/')" >&2
    echo "Options:" >&2
    echo "  --check-tools   Exit 0 if all tools are already built, 1 otherwise." >&2
    echo "  --only <tool>   Build only the named tool (repeatable)." >&2
    echo "  --skip <tool>   Skip the named tool (repeatable)." >&2
    echo "  --list          Print all known tools and exit." >&2
    exit 1
}

CHECK_ONLY=false
ONLY_TOOLS=()
SKIP_TOOLS=()

while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --check-tools) CHECK_ONLY=true; shift ;;
        --only)        ONLY_TOOLS+=("$2"); shift 2 ;;
        --skip)        SKIP_TOOLS+=("$2"); shift 2 ;;
        --list)
            echo "Known tools: android-tools apktool erofs-utils img2sdat samloader signapk smali omcdecoder"
            exit 0
            ;;
        *) usage ;;
    esac
done
[ "${1:-}" ] && usage

# ---------------------------------------------------------------------------
# Tool definitions
# Each entry: NAME  CHECK_EXEC_ARRAY  CMD_ARRAY
# The parallel arrays below are indexed by position.
# ---------------------------------------------------------------------------

declare -A TOOL_NEEDED   # TOOL_NEEDED[name]=true/false

# ---- android-tools --------------------------------------------------------
ANDROID_TOOLS_EXEC=(
    "adb" "append2simg" "avbtool" "e2fsdroid"
    "ext2simg" "fastboot" "fec" "gki/generate_gki_certificate.py"
    "img2simg" "lpadd" "lpdump" "lpflash" "lpmake"
    "lpunpack" "make_f2fs" "mkbootfs" "mkbootimg" "mkdtboimg" "mke2fs"
    "mke2fs.android" "mke2fs.conf" "mkf2fsuserimg" "mkuserimg_mke2fs"
    "repack_bootimg" "simg2img" "sload_f2fs" "unpack_bootimg" "zipalign"
)
ANDROID_TOOLS_CMDS=(
    "git submodule foreach --recursive 'git am --abort || true'"
    "cmake -B 'build' $(GET_CMAKE_FLAGS) -DANDROID_TOOLS_USE_BUNDLED_FMT=ON -DANDROID_TOOLS_USE_BUNDLED_LIBUSB=ON"
    "make -C 'build' -j\"$(nproc)\""
    "find 'build/vendor' -maxdepth 1 -type f -exec test -x {} \\; -exec cp -a {} \"$TOOLS_DIR/bin\" \\;"
    "cp -a 'vendor/avb/avbtool.py' \"$TOOLS_DIR/bin/avbtool\""
    "cp -a 'vendor/mkbootimg/mkbootimg.py' \"$TOOLS_DIR/bin/mkbootimg\""
    "cp -a 'vendor/mkbootimg/repack_bootimg.py' \"$TOOLS_DIR/bin/repack_bootimg\""
    "cp -a 'vendor/mkbootimg/unpack_bootimg.py' \"$TOOLS_DIR/bin/unpack_bootimg\""
    "cp -a 'vendor/libufdt/utils/src/mkdtboimg.py' \"$TOOLS_DIR/bin/mkdtboimg\""
    "mkdir -p \"$TOOLS_DIR/bin/gki\""
    "cp -a 'vendor/mkbootimg/gki/generate_gki_certificate.py' \"$TOOLS_DIR/bin/gki/generate_gki_certificate.py\""
    "ln -sf \"$TOOLS_DIR/bin/mke2fs.android\" \"$TOOLS_DIR/bin/mke2fs\""
    "cp -a '../ext4_utils/mkuserimg_mke2fs.py' \"$TOOLS_DIR/bin/mkuserimg_mke2fs.py\""
    "ln -sf \"$TOOLS_DIR/bin/mkuserimg_mke2fs.py\" \"$TOOLS_DIR/bin/mkuserimg_mke2fs\""
    "cp -a '../ext4_utils/mke2fs.conf' \"$TOOLS_DIR/bin/mke2fs.conf\""
    "cp -a '../f2fs_utils/mkf2fsuserimg.sh' \"$TOOLS_DIR/bin/mkf2fsuserimg\""
)

# ---- apktool --------------------------------------------------------------
APKTOOL_EXEC=("apktool" "apktool.jar")
APKTOOL_CMDS=(
    "git reset --hard"
    "./gradlew build shadowJar"
    "cp -a 'scripts/linux/apktool' \"$TOOLS_DIR/bin\""
    "cp -a 'brut.apktool/apktool-cli/build/libs/apktool-cli.jar' \"$TOOLS_DIR/bin/apktool.jar\""
)

# ---- erofs-utils ----------------------------------------------------------
EROFS_UTILS_EXEC=("dump.erofs" "extract.erofs" "fsck.erofs" "fuse.erofs" "mkfs.erofs")
EROFS_UTILS_CMDS=(
    "git reset --hard"
    "cmake -S 'build/cmake' -B 'out' $(GET_CMAKE_FLAGS) -DRUN_ON_WSL=\"$(IS_WSL)\" -DENABLE_FULL_LTO=ON -DMAX_BLOCK_SIZE=4096"
    "make -C 'out' -j\"$(nproc)\""
    "find 'out/erofs-tools' -maxdepth 1 -type f -exec test -x {} \\; -exec cp -a {} \"$TOOLS_DIR/bin\" \\;"
)

# ---- img2sdat -------------------------------------------------------------
IMG2SDAT_EXEC=("blockimgdiff.py" "common.py" "images.py" "img2sdat" "rangelib.py" "sparse_img.py")
IMG2SDAT_CMDS=(
    "find '.' -maxdepth 1 -type f -exec test -x {} \\; -exec cp -a {} \"$TOOLS_DIR/bin\" \\;"
)

# ---- samloader ------------------------------------------------------------
SAMLOADER_EXEC=("../venv/bin/samloader")
SAMLOADER_CMDS=(
    "python3 -m venv \"$TOOLS_DIR/venv\""
    "source \"$TOOLS_DIR/venv/bin/activate\" && pip3 install --quiet ."
)

# ---- signapk --------------------------------------------------------------
SIGNAPK_EXEC=("signapk" "signapk.jar")
SIGNAPK_CMDS=(
    "./gradlew build"
    "cp -a 'scripts/linux/signapk' \"$TOOLS_DIR/bin\""
    "cp -a 'signapk/build/libs/signapk-all.jar' \"$TOOLS_DIR/bin/signapk.jar\""
)

# ---- smali ----------------------------------------------------------------
SMALI_EXEC=("android-smali.jar" "baksmali" "smali" "smali-baksmali.jar")
SMALI_CMDS=(
    "./gradlew assemble baksmali:fatJar smali:fatJar"
    "cp -a 'scripts/baksmali' \"$TOOLS_DIR/bin\""
    "cp -a 'scripts/smali' \"$TOOLS_DIR/bin\""
    "cp -a baksmali/build/libs/*-dev-fat.jar \"$TOOLS_DIR/bin/smali-baksmali.jar\""
    "cp -a smali/build/libs/*-dev-fat.jar \"$TOOLS_DIR/bin/android-smali.jar\""
)

# ---- omcdecoder -----------------------------------------------------------
OMCDECODER_EXEC=("cscdecoder")
OMCDECODER_CMDS=(
    "clang++ -lz -I./include decoder.cpp -o cscdecoder"
    "mv -f 'cscdecoder' \"$TOOLS_DIR/bin/cscdecoder\""
)

# ---------------------------------------------------------------------------
# Determine which tools need building
# Indexed as parallel arrays so new tools need only one block above + one
# entry in each of the three arrays below.
# ---------------------------------------------------------------------------

ALL_TOOLS=(android-tools apktool erofs-utils img2sdat samloader signapk smali omcdecoder)

declare -A TOOL_EXEC_VAR=(
    [android-tools]="ANDROID_TOOLS_EXEC"
    [apktool]="APKTOOL_EXEC"
    [erofs-utils]="EROFS_UTILS_EXEC"
    [img2sdat]="IMG2SDAT_EXEC"
    [samloader]="SAMLOADER_EXEC"
    [signapk]="SIGNAPK_EXEC"
    [smali]="SMALI_EXEC"
    [omcdecoder]="OMCDECODER_EXEC"
)

declare -A TOOL_CMD_VAR=(
    [android-tools]="ANDROID_TOOLS_CMDS"
    [apktool]="APKTOOL_CMDS"
    [erofs-utils]="EROFS_UTILS_CMDS"
    [img2sdat]="IMG2SDAT_CMDS"
    [samloader]="SAMLOADER_CMDS"
    [signapk]="SIGNAPK_CMDS"
    [smali]="SMALI_CMDS"
    [omcdecoder]="OMCDECODER_CMDS"
)

declare -A TOOL_DIR=(
    [android-tools]="$SRC_DIR/external/android-tools"
    [apktool]="$SRC_DIR/external/apktool"
    [erofs-utils]="$SRC_DIR/external/erofs-utils"
    [img2sdat]="$SRC_DIR/external/img2sdat"
    [samloader]="$SRC_DIR/external/samloader"
    [signapk]="$SRC_DIR/external/signapk"
    [smali]="$SRC_DIR/external/smali"
    [omcdecoder]="$SRC_DIR/external/omcdecoder"
)

for tool in "${ALL_TOOLS[@]}"; do
    # Apply --only / --skip filters
    if [ ${#ONLY_TOOLS[@]} -gt 0 ]; then
        TOOL_NEEDED[$tool]=false
        for t in "${ONLY_TOOLS[@]}"; do [ "$t" = "$tool" ] && TOOL_NEEDED[$tool]=true; done
    elif [ ${#SKIP_TOOLS[@]} -gt 0 ]; then
        TOOL_NEEDED[$tool]=true
        for t in "${SKIP_TOOLS[@]}"; do [ "$t" = "$tool" ] && TOOL_NEEDED[$tool]=false; done
    else
        TOOL_NEEDED[$tool]=true
    fi

    # Downgrade to false if already built
    if ${TOOL_NEEDED[$tool]}; then
        exec_var="${TOOL_EXEC_VAR[$tool]}[@]"
        CHECK_TOOLS "${!exec_var}" && TOOL_NEEDED[$tool]=false
    fi
done

# ---------------------------------------------------------------------------
# --check-tools mode: exit 0 only if everything is already present
# ---------------------------------------------------------------------------

if $CHECK_ONLY; then
    for tool in "${ALL_TOOLS[@]}"; do
        ${TOOL_NEEDED[$tool]} && exit 1
    done
    exit 0
fi

# ---------------------------------------------------------------------------
# Build loop — adding a new tool requires only the definition block above
# and entries in ALL_TOOLS / TOOL_*_VAR / TOOL_DIR.
# ---------------------------------------------------------------------------

for tool in "${ALL_TOOLS[@]}"; do
    ${TOOL_NEEDED[$tool]} || continue

    cmd_var="${TOOL_CMD_VAR[$tool]}[@]"
    BUILD "$tool" "${TOOL_DIR[$tool]}" "${!cmd_var}"
done

exit 0
