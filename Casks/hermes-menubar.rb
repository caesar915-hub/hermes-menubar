cask "hermes-menubar" do
  version "1.0.0"
  sha256 "c213fa820d3e63e484e3556329f6094d6351265ed280ff474659ffa68d1f1770"

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
