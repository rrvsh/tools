{
  config.flake.modules.homeManager.rafiq = {
    services.syncthing = {
      enable = true;
      overrideDevices = false;
      overrideFolders = false;
      settings.folders = {
        publish.path = "~/publish";
        ref.path = "~/ref";
      };
    };
  };
}
