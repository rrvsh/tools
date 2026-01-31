{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.opencode.enable = true;
      programs.opencode.enableMcpIntegration = true;
      home.shellAliases.oc = "opencode";
    };
  };
}
