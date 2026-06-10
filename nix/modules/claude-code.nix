{
  config.flake.allowedUnfreePackages = [ "claude-code" ];
  config.flake.modules.darwin.claude-code =
    { pkgs, ... }:
    {
      home-manager.sharedModules = [
        {
          home.packages = [ pkgs.claude-code ];
          programs.pi-coding-agent.settings.packages = [ "npm:@vanillagreen/pi-claude-bridge" ];
        }
      ];
    };
}
