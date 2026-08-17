cask "hermes-menubar" do
  version "1.1.0"
  sha256 "ca9a5e046ff574c2748dfcbc0fc1b8e738066fca07a2361107691d16a6d6abbe"

  url "https://github.com/caesar915-hub/hermes-menubar/releases/download/v#{version}/HermesMenuBar-#{version}.dmg"
  name "Hermes Menu Bar"
  desc "Native macOS menu bar utility for Hermes Agent & Telegram gateways"
  homepage "https://github.com/caesar915-hub/hermes-menubar"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "HermesMenuBar.app"

  zap trash: [
    "~/Library/Application Support/HermesMenuBar",
    "~/Library/Preferences/ai.hermes.menubar.plist"
  ]
end
