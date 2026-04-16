# Template Cask for ClaudeNotch.
# Place in a separate repo `alexvallejo/homebrew-tap` under `Casks/claudenotch.rb`.
# After first signed+notarized release, update `version`, `sha256`, and `url`.
#
# Install (once the tap is public):
#   brew tap alexvallejo/tap
#   brew install --cask claudenotch
#
# Or in one line:
#   brew install --cask alexvallejo/tap/claudenotch

cask "claudenotch" do
  version "0.1.0"
  sha256 "<fill me with: shasum -a 256 ClaudeNotch-<version>.dmg>"

  url "https://github.com/alexvallejo/claudenotch/releases/download/v#{version}/ClaudeNotch-#{version}.dmg"
  name "ClaudeNotch"
  desc "Turns the Mac notch into a live Claude Code dashboard"
  homepage "https://github.com/alexvallejo/claudenotch"

  depends_on macos: ">= :sonoma"

  app "ClaudeNotch.app"

  zap trash: [
    "~/Library/Preferences/com.alejandrovallejo.ClaudeNotch.plist",
    "~/Library/Application Support/ClaudeNotch",
  ]
end
