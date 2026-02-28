{
  config.flake.modules.homeManager.rafiq =
    { config, ... }:
    {
      home.shellAliases.t = config.programs.yazi.shellWrapperName;
    };
}
