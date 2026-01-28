{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.opencode.enable = true;
      home.shellAliases.oc = "opencode";
    };
  };
}
