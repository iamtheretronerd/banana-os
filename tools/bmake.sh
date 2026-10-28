#!/usr/bin/env bash
# Build helper for BananaOS (luna). Usage: bmake.sh <targets...>   e.g. bmake.sh BananaLauncher | bmake.sh bacon
export PATH="$HOME/.local/bin:$PATH"
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR=/home/hemang/.cache/ccache
cd /mnt/pixelos || exit 1
swapon --show | grep -q swapfile_aosp || echo "WARNING: /swapfile_aosp is not active (Soong may OOM)"
source build/envsetup.sh >/dev/null
lunch aosp_luna-bp1a-userdebug >/dev/null || exit 1
mka "$@" -j"$(nproc)"
