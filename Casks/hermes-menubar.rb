cask "hermes-menubar" do
  version "1.0.0"
  sha256 "b746b8349d005eda2cad84e19d4c8ac1e60b03e048385b31460d776aa60c0809"

  url "https://github.com/caesar915-hub/hermes-menubar/releases/download/v#{version}/HermesMenuBar-#{version}.dmg"
  name "Hermes Menu Bar"
  desc "Native macOS menu bar utility for Hermes Agent & Telegram gateways"
  homepage "https://github.com/caesar915-hub/hermes-menubar"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "HermesMenuBar.app"

  zap trash: [
    "~/Library/Application Support/HermesMenuBar",
    "~/Library/Preferences/ai.hermes.menubar.plist"
  ]
end
