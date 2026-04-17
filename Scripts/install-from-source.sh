#!/usr/bin/env bash
# Build and install DevNotch into /Applications from a local checkout.
# Intended for the "one-command install" in the README:
#
#   curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/Scripts/install-from-source.sh | bash
#
# Requires: Xcode command line tools + Homebrew.

set -euo pipefail

REPO="${DEVNOTCH_REPO:-AlejandroVallejo1/devnotch}"
BRANCH="${DEVNOTCH_BRANCH:-main}"
WORKDIR="${TMPDIR:-/tmp}/devnotch-install-$$"

echo "==> DevNotch installer"

if ! command -v xcodebuild >/dev/null; then
  echo "Error: Xcode command-line tools are required. Run: xcode-select --install"
  exit 1
fi

if ! command -v brew >/dev/null; then
  echo "Error: Homebrew is required. Install from https://brew.sh"
  exit 1
fi

if ! command -v xcodegen >/dev/null; then
  echo "==> Installing xcodegen"
  brew install xcodegen
fi

echo "==> Cloning $REPO ($BRANCH)"
git clone --depth 1 --branch "$BRANCH" "https://github.com/$REPO.git" "$WORKDIR"
cd "$WORKDIR"

echo "==> Generating Xcode project"
xcodegen

echo "==> Building Release (unsigned)"
xcodebuild \
  -project DevNotch.xcodeproj \
  -scheme DevNotch \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -name "DevNotch.app" -path "*Release*" | head -n 1)
if [[ -z "$APP_PATH" ]]; then
  echo "Error: could not locate built DevNotch.app"
  exit 1
fi

echo "==> Installing to /Applications"
rm -rf "/Applications/DevNotch.app"
cp -R "$APP_PATH" "/Applications/DevNotch.app"

# Strip quarantine so Gatekeeper doesn't block unsigned builds.
xattr -dr com.apple.quarantine "/Applications/DevNotch.app" 2>/dev/null || true

echo "==> Launching"
open "/Applications/DevNotch.app"

echo "==> Installed. Menu bar icon appears as a small chart bar."
