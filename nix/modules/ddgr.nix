{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.ddgr ];
      home.shellAliases.search = "ddgr -n 5 -C -x --np";
    };
}
