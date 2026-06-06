#!/system/bin/sh

# ─── Config ───────────────────────────────────────────────────────────────────
SLEEP_DELAY="${CLEAN_DELAY:-0.5}"
LOG_TAG="cleaner"
DATA_DIR="${DATA_DIR:-/data}"
SDCARD_DIR="${SDCARD_DIR:-/sdcard}"
MAX_DEPTH="${CLEAN_MAX_DEPTH:-4}"

# ─── Logging ──────────────────────────────────────────────────────────────────
_log()  { log -t "$LOG_TAG" "$1" 2>/dev/null || echo "[$LOG_TAG] $1"; }
_logw() { _log "WARN: $1"; }
_loge() { _log "ERR:  $1"; }

# ─── Safe recursive delete ────────────────────────────────────────────────────
# _rm <path> [path ...]
# Skips missing paths silently; logs actual errors.
_rm() {
    local t rc=0
    for t in "$@"; do
        [ -e "$t" ] || continue
        rm -rf "$t" 2>/dev/null || { _loge "Failed to remove: $t"; rc=1; }
    done
    return $rc
}

# ─── Find-and-delete by name pattern ─────────────────────────────────────────
# _rm_dirs <root> <maxdepth> <name-pattern> [name-pattern ...]
_rm_dirs() {
    local root="$1" depth="$2"; shift 2
    [ -d "$root" ] || return 0

    local args=()
    local first=true
    for pat in "$@"; do
        $first && first=false || args+=(-o)
        args+=(-name "$pat")
    done

    find "$root" -maxdepth "$depth" -type d \( "${args[@]}" \) \
        -exec rm -rf {} + 2>/dev/null
}

# ─── Main cleanup ─────────────────────────────────────────────────────────────
main() {
    sleep "$SLEEP_DELAY"

    _log "Starting cleanup..."

    # Dalvik / ART
    _log "  [1/6] Dalvik/ART cache"
    _rm  "$DATA_DIR/dalvik-cache"/*
    _rm_dirs "$DATA_DIR/app" 3 "oat"
    _rm  "$DATA_DIR/system/package_cache"/*

    # Internal app caches
    _log "  [2/6] Internal app caches"
    _rm_dirs "$DATA_DIR/data" "$MAX_DEPTH" \
        "cache" "cache*" "*cache" "*cache*" \
        "code_cache" "code_cache*" "*code_cache" "*code_cache*" \
        "app_ads_cache" "app_webview" "app_textures" \
        "app_tmp" "app_swap" "app_dex"

    # External / SD card caches
    _log "  [3/6] External app caches"
    _rm_dirs "$SDCARD_DIR/Android/data" "$MAX_DEPTH" \
        "cache" "cache*" "*cache" "*cache*" ".cache" ".tmp"

    # Also check secondary external storage if present
    for ext in /mnt/media_rw/* /storage/*; do
        [ -d "$ext/Android/data" ] || continue
        _log "  [3b] External storage: $ext"
        _rm_dirs "$ext/Android/data" "$MAX_DEPTH" \
            "cache" "cache*" "*cache" "*cache*"
    done

    # Logs & diagnostics
    _log "  [4/6] Logs and diagnostics"
    _rm "$DATA_DIR/tombstones"/*
    _rm "$DATA_DIR/system/dropbox"/*
    _rm "$DATA_DIR/log"/*
    _rm "$DATA_DIR/system/usagestats"/*
    _rm "$DATA_DIR/system/netstats"/*
    _rm "$DATA_DIR/anr"/*

    # System cache partition
    _log "  [5/6] System cache partition"
    if mountpoint -q /cache 2>/dev/null; then
        _rm /cache/*
    else
        _logw "/cache not mounted, skipping"
    fi

    # Temp / script artifacts
    _log "  [6/6] Temp files"
    _rm /tmp/scripts
    _rm_dirs /tmp "$MAX_DEPTH" "cache" "cache*" "*cache*"

    _log "Cleanup complete."
}

main "$@"
