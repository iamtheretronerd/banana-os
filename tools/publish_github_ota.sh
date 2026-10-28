#!/usr/bin/env bash
# =============================================================================
# BananaOS OTA publisher for https://github.com/iamtheretronerd/banana-os
# =============================================================================
# Phones check:  https://raw.githubusercontent.com/<repo>/main/ota/fifteen/luna.json
# ROM zip lives: https://github.com/<repo>/releases/download/<tag>/<zip>
#
# Usage:
#   ./publish_github_ota.sh [path-to-rom.zip] ["changelog line" ...]
#
# Env overrides:
#   BANANA_OTA_REPO   GitHub repo (default iamtheretronerd/banana-os)
#   BANANA_REPO_DIR   local clone of that repo (default ~/banana-os, cloned if missing)
#
# Order matters: the zip is uploaded to the release FIRST, and luna.json is pushed
# only after that, so phones never see an update whose download doesn't exist yet.
# =============================================================================
set -euo pipefail

REPO="${BANANA_OTA_REPO:-iamtheretronerd/banana-os}"
REPO_DIR="${BANANA_REPO_DIR:-$HOME/banana-os}"
OUT=/mnt/pixelos/out/target/product/luna
ZIP_PATH="${1:-$(ls -t "$OUT"/BananaOS_luna-*.zip 2>/dev/null | head -n1)}"
shift || true
NOTES=("$@")
[[ ${#NOTES[@]} -eq 0 ]] && NOTES=("BananaOS update for BlackBerry KEY2 LE (luna)")

VERSION="15.0"
BRANCH_DIR="fifteen"
DEVICE="luna"

if [[ -z "$ZIP_PATH" || ! -f "$ZIP_PATH" ]]; then
    echo "Error: no BananaOS zip found (looked in $OUT)." >&2
    exit 1
fi

FILENAME="$(basename "$ZIP_PATH")"
SIZE="$(stat -c%s "$ZIP_PATH")"
echo "Hashing $FILENAME ..."
SHA256="$(sha256sum "$ZIP_PATH" | awk '{print $1}')"

# The phone compares this with its own ro.build.date.utc, so take it from the zip itself.
DATETIME="$(unzip -p "$ZIP_PATH" META-INF/com/android/metadata 2>/dev/null | grep -m1 '^post-timestamp=' | cut -d= -f2 || true)"
if [[ -z "$DATETIME" ]]; then
    DATETIME="$(grep -m1 '^ro.build.date.utc=' "$OUT/system/build.prop" | cut -d= -f2)"
fi

# Tag from the zip name: BananaOS_luna-15.0-20261028-1347.zip -> v15.0-20261028-1347
STAMP="$(echo "$FILENAME" | sed -E 's/^BananaOS_luna-15\.0-([0-9]{8}-[0-9]{4})\.zip$/\1/')"
TAG="v${VERSION}-${STAMP}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${FILENAME}"

# ---------------------------------------------------------------- local clone
if [[ ! -d "$REPO_DIR/.git" ]]; then
    git clone "https://github.com/${REPO}.git" "$REPO_DIR"
fi
git -C "$REPO_DIR" checkout -q main 2>/dev/null || git -C "$REPO_DIR" checkout -q -b main
git -C "$REPO_DIR" pull -q --ff-only origin main 2>/dev/null || true

DEST="$REPO_DIR/ota/$BRANCH_DIR"
mkdir -p "$DEST"

cat > "$DEST/$DEVICE.json" <<EOF
{
  "response": [
    {
      "datetime": ${DATETIME},
      "filename": "${FILENAME}",
      "id": "${SHA256}",
      "size": ${SIZE},
      "url": "${DOWNLOAD_URL}",
      "version": "${VERSION}"
    }
  ]
}
EOF

{
    echo "# BananaOS ${VERSION} — ${STAMP}"
    echo
    echo "BlackBerry KEY2 LE (\`luna\`)"
    echo
    echo "## Changes"
    for n in "${NOTES[@]}"; do echo "- $n"; done
    echo
    echo "SHA-256: \`${SHA256}\`"
} > "$DEST/$DEVICE.md"

echo "============================================================"
echo "Release tag : $TAG"
echo "Zip URL     : $DOWNLOAD_URL"
echo "Phone polls : https://raw.githubusercontent.com/${REPO}/main/ota/${BRANCH_DIR}/${DEVICE}.json"
echo "============================================================"
cat "$DEST/$DEVICE.json"

# ---------------------------------------------------------------- publish
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    echo
    echo "Uploading $FILENAME to release $TAG on $REPO ..."
    gh release create "$TAG" "$ZIP_PATH" \
        --repo "$REPO" \
        --title "BananaOS ${VERSION} (${STAMP})" \
        --notes-file "$DEST/$DEVICE.md"

    echo "Publishing OTA metadata ..."
    git -C "$REPO_DIR" add "ota/$BRANCH_DIR/$DEVICE.json" "ota/$BRANCH_DIR/$DEVICE.md"
    git -C "$REPO_DIR" commit -q -m "ota: luna ${STAMP}"
    git -C "$REPO_DIR" push -q origin main
    echo "Done. Phones will see the update within a few minutes (GitHub caches raw files ~5 min)."
else
    cat <<EOF

GitHub CLI (gh) is not installed/authenticated, so nothing was uploaded.
Publish manually, in this order:
  1. https://github.com/${REPO}/releases/new  -> tag: ${TAG}
     attach: ${ZIP_PATH}
     (wait until the upload finishes)
  2. cd "$REPO_DIR" && git add ota && git commit -m "ota: luna ${STAMP}" && git push origin main
Or install gh (sudo apt install gh && gh auth login) and re-run this script.
EOF
fi
