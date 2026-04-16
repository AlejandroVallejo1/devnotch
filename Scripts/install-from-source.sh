#!/usr/bin/env bash
# Build and install ClaudeNotch into /Applications from a local checkout.
# Intended for the "one-command install" in the README:
#
#   curl -fsSL https://raw.githubusercontent.com/<OWNER>/<REPO>/main/Scripts/install-from-source.sh | bash
#
# Requires: Xcode command line tools + Homebrew.

set -euo pipefail

REPO="${CLAUDENOTCH_REPO:-alexvallejo/claudenotch}"
BRANCH="${CLAUDENOTCH_BRANCH:-main}"
WORKDIR="${TMPDIR:-/tmp}/claudenotch-install-$$"

echo "==> ClaudeNotch installer"

if ! command -v xcodebuild >/dev/null; then
  echo "❌ Xcode command-line tools are required. Run: xcode-select --install"
  exit 1
fi

if ! command -v brew >/dev/null; then
  echo "❌ Homebrew is required. Install from https://brew.sh"
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
  -project ClaudeNotch.xcodeproj \
  -scheme ClaudeNotch \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -name "ClaudeNotch.app" -path "*Release*" | head -n 1)
if [[ -z "$APP_PATH" ]]; then
  echo "❌ Could not locate built ClaudeNotch.app"
  exit 1
fi

echo "==> Installing to /Applications"
rm -rf "/Applications/ClaudeNotch.app"
cp -R "$APP_PATH" "/Applications/ClaudeNotch.app"

# Strip quarantine so Gatekeeper doesn't block unsigned builds.
xattr -dr com.apple.quarantine "/Applications/ClaudeNotch.app" 2>/dev/null || true

echo "==> Launching"
open "/Applications/ClaudeNotch.app"

echo "✅ Installed. Menu bar icon appears as a small chart bar."
