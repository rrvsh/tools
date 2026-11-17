{ config, lib, ... }:
let
  cfg = config.flake;
  extensionId = "mfnicocicmmlkpjnaffgihfjhdgjkdjg";
in
{
  config.flake.modules = {
    darwin.browse = {
      home-manager.sharedModules = [ cfg.modules.homeManager.browse ];
      homebrew.casks = [ "google-chrome" ];
    };
    nixos.browse = {
      home-manager.sharedModules = [ cfg.modules.homeManager.browse ];
    };
    homeManager.browse =
      { pkgs, ... }:
      let
        browse = cfg.packages.${pkgs.stdenv.hostPlatform.system}.browse;
      in
      {
        home.packages = [ browse ];
        programs = {
          chromium = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
            enable = true;
            extensions = [ extensionId ];
          };
          google-chrome = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
            enable = true;
            package = null;
            extensions = [ extensionId ];
          };
          mcp.servers.browse = {
            command = lib.getExe browse;
            args = [ "mcp" ];
            description = "Control paired Chromium tabs, including human handoffs for login and 2FA";
            exposure = "direct";
            timeout = 900;
          };
        };
      };
  };
}
