{
  config.flake.modules.homeManager.rafiq = {
    home.shellAliases.cd = "echo \"Please use z\"";
    programs.zoxide.enable = true;
  };
}
