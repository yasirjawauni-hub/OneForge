# Copyright (C) 2023 Salvo Giangreco
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

# Universal debloat list (all Samsung devices)
# - Add entries inside the specific partition containing that file (<PARTITION>_DEBLOAT+="")
# - DO NOT add the partition name at the start of any entry (eg. "/dpolicy_system")
# - DO NOT add a slash at the start of any entry (eg. "/dpolicy_system")
# - Platform-specific entries are guarded by PLATFORM checks (see below)
#
# Usage:
#   Source this file in your build script. Optionally set PLATFORM before
#   sourcing to enable platform-specific removals:
#     PLATFORM=exynos9820  (Exynos 9820)
#     PLATFORM=exynos990   (Exynos 990)
#     PLATFORM=exynos2100  (Exynos 2100)
#     PLATFORM=sm8250      (Snapdragon 865)
#     PLATFORM=sm8350      (Snapdragon 888)
#   Leave unset to apply only universal entries.

# ---------------------------------------------------------------------------
# Camera SDK  [universal]
# ---------------------------------------------------------------------------
SYSTEM_DEBLOAT+="
system/etc/default-permissions/default-permissions-com.samsung.android.globalpostprocmgr.xml
system/etc/default-permissions/default-permissions-com.samsung.petservice.xml
system/etc/default-permissions/default-permissions-com.samsung.videoscan.xml
system/etc/permissions/cameraservice.xml
system/etc/permissions/privapp-permissions-com.samsung.android.globalpostprocmgr.xml
system/etc/permissions/privapp-permissions-com.samsung.petservice.xml
system/etc/permissions/privapp-permissions-com.samsung.videoscan.xml
system/etc/permissions/sec_camerax_impl.xml
system/etc/permissions/sec_camerax_service.xml
system/framework/sec_camerax_impl.jar
system/framework/scamera_sep.jar
system/priv-app/GlobalPostProcMgr
system/priv-app/PetService
system/priv-app/SCameraSDKService
system/priv-app/sec_camerax_service
system/priv-app/VideoScan
"

# ---------------------------------------------------------------------------
# Wi-Fi Hotspot Overlays  [universal]
# ---------------------------------------------------------------------------
PRODUCT_DEBLOAT+="
overlay/SoftapOverlay6GHz
overlay/SoftapOverlayDualAp
overlay/SoftapOverlayOWE
"

# ---------------------------------------------------------------------------
# StorageShare (kSMBd)  [universal]
# ---------------------------------------------------------------------------
SYSTEM_DEBLOAT+="
system/bin/ksmbd.addshare
system/bin/ksmbd.adduser
system/bin/ksmbd.control
system/bin/ksmbd.mountd
system/bin/ksmbd.tools
system/etc/default-permissions/default-permissions-com.samsung.android.hwresourceshare.storage.xml
system/etc/init/ksmbd.rc
system/etc/permissions/privapp-permissions-com.samsung.android.hwresourceshare.storage.xml
system/etc/sysconfig/preinstalled-packages-com.samsung.android.hwresourceshare.storage.xml
system/etc/ksmbd.conf
system/priv-app/StorageShare
"

# ---------------------------------------------------------------------------
# Platform-specific entries
# Guard with: if [ "${PLATFORM}" = "<platform_id>" ]; then ... fi
# ---------------------------------------------------------------------------

# --- Exynos 9820 (S10 / Note10 series) ------------------------------------
if [ "${PLATFORM}" = "exynos9820" ]; then
    VENDOR_DEBLOAT+="
vendor/lib/libsec_isp_fd_engine.so
vendor/lib64/libsec_isp_fd_engine.so
"
fi

# --- Exynos 990 (S20 / Note20 series) -------------------------------------
if [ "${PLATFORM}" = "exynos990" ]; then
    VENDOR_DEBLOAT+="
vendor/lib/libsec_isp_fd_engine.so
vendor/lib64/libsec_isp_fd_engine.so
"
fi

# --- Exynos 2100 (S21 series) ---------------------------------------------
if [ "${PLATFORM}" = "exynos2100" ]; then
    VENDOR_DEBLOAT+="
vendor/lib/libsec_isp_fd_engine.so
vendor/lib64/libsec_isp_fd_engine.so
"
fi

# --- Snapdragon 865 / sm8250 (S20 / Note20 series) ------------------------
if [ "${PLATFORM}" = "sm8250" ]; then
    VENDOR_DEBLOAT+="
vendor/lib/libHtcFaceBeauty.so
vendor/lib64/libHtcFaceBeauty.so
"
fi

# --- Snapdragon 888 / sm8350 (S21 series) ---------------------------------
if [ "${PLATFORM}" = "sm8350" ]; then
    VENDOR_DEBLOAT+="
vendor/lib/libHtcFaceBeauty.so
vendor/lib64/libHtcFaceBeauty.so
"
fi
