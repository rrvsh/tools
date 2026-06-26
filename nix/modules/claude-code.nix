{ inputs, ... }:
{
  config.flake.allowedUnfreePackages = [ "claude-code" ];
  config.flake.modules.darwin.claude-code =
    { pkgs, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      bridge = inputs.pi-claude-bridge.packages.${system}.pi-claude-bridge;
    in
    {
      home-manager.sharedModules = [
        {
          home.packages = [ pkgs.claude-code ];
          programs.pi-coding-agent.settings.packages = [ bridge.passthru.packagePath ];
        }
      ];
    };
}
