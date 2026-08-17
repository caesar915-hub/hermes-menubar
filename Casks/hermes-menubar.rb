cask "hermes-menubar" do
  version "1.0.0"
  sha256 "f129404fc03f913fa5f52469846b5aafc2de697832012f954ddbd28e5570477f"

  url "https://github.com/caesar915-hub/hermes-menubar/releases/download/v#{version}/HermesMenuBar-#{version}.dmg"
  name "Hermes Menu Bar"
  desc "Native macOS menu bar utility for Hermes Agent & Telegram gateways"
  homepage "https://github.com/caesar915-hub/hermes-menubar"

  depends_on macos: :ventura

  app "HermesMenuBar.app"

  zap trash: [
    "~/Library/Preferences/ai.hermes.menubar.plist",
    "~/Library/Application Support/HermesMenuBar"
  ]
end
