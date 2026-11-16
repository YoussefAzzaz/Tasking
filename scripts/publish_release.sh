#!/usr/bin/env bash
# ==============================================================================
# AXIS Automated Release & Distribution Engine
# ==============================================================================
# Builds mobile and desktop releases, generates checksums, and publishes
# them to GitHub Releases so that all active clients receive over-the-air
# update notifications and automatic in-app downloads.
#
# Usage:
#   ./scripts/publish_release.sh [version] [optional_changelog]
#
# Examples:
#   ./scripts/publish_release.sh 1.2.1 "Mobile calendar and OTA auto-updates"
#   ./scripts/publish_release.sh --dry-run 1.2.1
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MOBILE_DIR="${ROOT_DIR}/mobile"
RELEASES_DIR="${ROOT_DIR}/build/releases"

DRY_RUN=false
TARGET_VERSION=""
CHANGELOG=""

# Parse flags and arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      if [[ -z "$TARGET_VERSION" ]]; then
        TARGET_VERSION="$1"
      elif [[ -z "$CHANGELOG" ]]; then
        CHANGELOG="$1"
      else
        CHANGELOG="$CHANGELOG $1"
      fi
      shift
      ;;
  esac
done

echo "=================================================================="
echo "  AXIS OTA RELEASE PIPELINE"
echo "=================================================================="

# Check requirements
if ! command -v flutter >/dev/null 2>&1; then
  echo "[-] Error: flutter CLI not found in PATH."
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "[-] Error: gh (GitHub CLI) not found in PATH."
  exit 1
fi

# Detect or extract version from pubspec.yaml if not provided
CURRENT_PUBSPEC_VER=$(grep '^version:' "${MOBILE_DIR}/pubspec.yaml" | sed 's/version:[[:space:]]*//')
CURRENT_VER=$(echo "$CURRENT_PUBSPEC_VER" | cut -d'+' -f1)
CURRENT_BUILD=$(echo "$CURRENT_PUBSPEC_VER" | cut -d'+' -f2)

if [[ -z "$TARGET_VERSION" ]]; then
  echo "[i] Current version in pubspec.yaml: $CURRENT_PUBSPEC_VER"
  read -r -p "Enter new version number (e.g. 1.2.1): " TARGET_VERSION
  if [[ -z "$TARGET_VERSION" ]]; then
    echo "[-] No version specified. Aborting."
    exit 1
  fi
fi

# Strip leading 'v' if present
TARGET_VERSION="${TARGET_VERSION#v}"
NEXT_BUILD=$(( CURRENT_BUILD + 1 ))
NEW_PUBSPEC_VER="${TARGET_VERSION}+${NEXT_BUILD}"
TAG="v${TARGET_VERSION}"

if [[ -z "$CHANGELOG" ]]; then
  CHANGELOG="Release ${TAG} - Automated System Update"
fi

echo "[+] Target Version:     ${TARGET_VERSION}"
echo "[+] Build Number:       ${NEXT_BUILD}"
echo "[+] Release Tag:        ${TAG}"
echo "[+] Changelog:          ${CHANGELOG}"
echo "[+] Dry Run:            ${DRY_RUN}"
echo "------------------------------------------------------------------"

# 1. Update pubspec.yaml version
echo "[1/6] Updating mobile/pubspec.yaml version to ${NEW_PUBSPEC_VER}..."
sed -i "s/^version: .*/version: ${NEW_PUBSPEC_VER}/" "${MOBILE_DIR}/pubspec.yaml"

# 2. Run analysis and tests
echo "[2/6] Running static analysis and regression verification..."
(cd "${MOBILE_DIR}" && flutter analyze --no-fatal-infos)
(cd "${MOBILE_DIR}" && flutter test test/update_checker_test.dart test/update_ui_test.dart test/auth_remember_me_test.dart test/adhan_alarm_service_test.dart test/adhan_full_screen_alarm_test.dart)

# 3. Create releases directory
mkdir -p "${RELEASES_DIR}"

# 4. Build Android Release APK
echo "[3/6] Building Android Release APK..."
(cd "${MOBILE_DIR}" && flutter build apk --release)

APK_SOURCE="${MOBILE_DIR}/build/app/outputs/flutter-apk/app-release.apk"
APK_TARGET="${RELEASES_DIR}/axis-v${TARGET_VERSION}-android.apk"

if [[ -f "$APK_SOURCE" ]]; then
  cp "$APK_SOURCE" "$APK_TARGET"
  echo "  --> Built: ${APK_TARGET} ($(du -h "$APK_TARGET" | cut -f1))"
else
  echo "[-] Error: APK build output not found at ${APK_SOURCE}"
  exit 1
fi

# 5. Build Linux Desktop Release Bundle
echo "[4/6] Building Linux Desktop Release Bundle..."
(cd "${MOBILE_DIR}" && flutter build linux --release)

LINUX_BUNDLE="${MOBILE_DIR}/build/linux/x64/release/bundle"
LINUX_TARGET="${RELEASES_DIR}/axis-v${TARGET_VERSION}-linux-x64.tar.gz"

if [[ -d "$LINUX_BUNDLE" ]]; then
  tar -czf "$LINUX_TARGET" -C "$LINUX_BUNDLE" .
  echo "  --> Packaged: ${LINUX_TARGET} ($(du -h "$LINUX_TARGET" | cut -f1))"
else
  echo "[-] Warning: Linux bundle directory not found at ${LINUX_BUNDLE}. Skipping Linux package."
fi

# 6. Compute SHA256 Checksums
echo "[5/6] Generating SHA256 verification checksums..."
(cd "${RELEASES_DIR}" && sha256sum axis-v${TARGET_VERSION}* > SHA256SUMS.txt)

echo "------------------------------------------------------------------"
echo "Artifacts prepared in ${RELEASES_DIR}:"
ls -lh "${RELEASES_DIR}"
echo "------------------------------------------------------------------"

# 7. Publish to GitHub Releases
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[!] Dry run complete. Artifacts built without publishing."
  exit 0
fi

echo "[6/6] Committing version bump and pushing to git..."
if git diff --quiet "${MOBILE_DIR}/pubspec.yaml"; then
  echo "  --> pubspec.yaml already committed."
else
  git add "${MOBILE_DIR}/pubspec.yaml"
  git commit -m "chore(release): bump version to ${NEW_PUBSPEC_VER}"
fi

CURRENT_BRANCH=$(git branch --show-current)
git push origin "$CURRENT_BRANCH"

# If on a release branch, also fast-forward main so the default git branch is up-to-date
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "  --> Syncing main branch to ${CURRENT_BRANCH}..."
  git checkout main
  git merge --ff-only "$CURRENT_BRANCH"
  git push origin main
  git checkout "$CURRENT_BRANCH"
fi

COMMIT_HASH=$(git rev-parse HEAD)
git tag -f "$TAG" "$COMMIT_HASH"
git push -f origin "$TAG"

echo "Publishing release ${TAG} to GitHub Releases..."

RELEASE_FILES=(
  "${APK_TARGET}"
)

if [[ -f "${LINUX_TARGET:-}" ]]; then
  RELEASE_FILES+=("${LINUX_TARGET}")
fi

if [[ -f "${RELEASES_DIR}/SHA256SUMS.txt" ]]; then
  RELEASE_FILES+=("${RELEASES_DIR}/SHA256SUMS.txt")
fi

# If release exists on GitHub, upload or recreate
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "  --> Release $TAG already exists on GitHub. Uploading updated assets..."
  gh release upload "$TAG" "${RELEASE_FILES[@]}" --clobber
else
  gh release create "$TAG" "${RELEASE_FILES[@]}" \
    --target "$COMMIT_HASH" \
    --title "Axis ${TAG}" \
    --notes "${CHANGELOG}"
fi

echo "=================================================================="
echo "  RELEASE ${TAG} IS NOW LIVE!"
echo "=================================================================="
echo "All desktop and mobile users will now automatically receive an"
echo "in-app update notice and can download & install the update with 1 tap."
echo "=================================================================="
