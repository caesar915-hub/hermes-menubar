cask "hermes-menubar" do
  version "1.1.2"
  sha256 "4cdd73d4474f85343a4e04180eb37877782137ba8fc0c2c6f6804362f4876618"

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
  binary "#{appdir}/HermesMenuBar.app/Contents/MacOS/HermesMenuBar", target: "hermes-menubar"

  zap trash: [
    "~/Library/Application Support/HermesMenuBar",
    "~/Library/Preferences/ai.hermes.menubar.plist"
  ]
end
