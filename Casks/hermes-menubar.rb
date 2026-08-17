cask "hermes-menubar" do
  version "1.1.1"
  sha256 "afb589eae46c7815d0882fea7b26b4a298c1c48bfdf0abaaaaf4a813435b26e8"

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
