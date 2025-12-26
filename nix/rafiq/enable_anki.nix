{
  config.flake = {
    modules.darwin.rafiq = {
      homebrew.casks = [
        "anki" # 25.09 via Homebrew because nixpkgs anki/withAddons 25.09.2 is marked broken on darwin
      ];
      system.defaults.CustomUserPreferences = {
        "net.ankiweb.dtop".NSAppSleepDisabled = true;
        "net.ichi2.anki".NSAppSleepDisabled = true;
        "org.qt-project.Qt.QtWebEngineCore".NSAppSleepDisabled = true;
      };
    };
  };
}
