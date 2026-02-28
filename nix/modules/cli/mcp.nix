{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.mcp = {
        enable = true;
        servers = {
          nixos = {
            command = "nix";
            args = [
              "run"
              "github:utensils/mcp-nixos"
              "--"
            ];
          };
        };
      };
    };
  };
}
