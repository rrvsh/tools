{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    darwin.nt.home-manager.sharedModules = [ cfg.modules.homeManager.nt ];
    nixos.nt.home-manager.sharedModules = [ cfg.modules.homeManager.nt ];
    homeManager.nt =
      { pkgs, ... }:
      let
        nt = cfg.packages.${pkgs.stdenv.hostPlatform.system}.nt;
      in
      {
        home = {
          packages = [ nt ];
          file.".pi/agent/skills/nt/SKILL.md".source = cfg.paths.root + "/agents/skills/nt/SKILL.md";
        };
        # Use Pi's native MCP support instead of `nt pi install`, which also installs
        # a second memory system. The mutable store stays at nt's local default;
        # never point it at a Syncthing or network filesystem.
        programs.mcp.servers.nt = {
          command = "${nt}/bin/nt";
          args = [ "mcp" ];
          description = "Read and manage the local nt personal task list";
          exposure = "hidden";
          toolExposure = {
            nt_status = "direct";
            nt_view = "direct";
            nt_add = "direct";
            nt_update = "direct";
            nt_search = "codemode";
          };
        };
      };
  };
}
