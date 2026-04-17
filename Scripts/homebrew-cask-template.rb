# Template Cask for DevNotch.
# Place in a separate repo `alexvallejo/homebrew-tap` under `Casks/devnotch.rb`.
# After first signed+notarized release, update `version`, `sha256`, and `url`.
#
# Install (once the tap is public):
#   brew tap alexvallejo/tap
#   brew install --cask devnotch
#
# Or in one line:
#   brew install --cask alexvallejo/tap/devnotch

cask "devnotch" do
  version "0.1.0"
  sha256 "<fill me with: shasum -a 256 DevNotch-<version>.dmg>"

  url "https://github.com/alexvallejo/devnotch/releases/download/v#{version}/DevNotch-#{version}.dmg"
  name "DevNotch"
  desc "Turns the Mac notch into a live Claude Code dashboard"
  homepage "https://github.com/alexvallejo/devnotch"

  depends_on macos: ">= :sonoma"

  app "DevNotch.app"

  zap trash: [
    "~/Library/Preferences/com.alejandrovallejo.DevNotch.plist",
    "~/Library/Application Support/DevNotch",
  ]
end
