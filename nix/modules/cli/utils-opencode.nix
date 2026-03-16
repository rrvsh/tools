{
  config.flake.modules.homeManager.rafiq = {
    programs = {
      opencode = {
        enable = true;
        enableMcpIntegration = true;
        settings = {
          permission.external_directory = {
            "/tmp/**" = "allow";
            "/private/var/folders/**" = "allow";
            "/nix/store/**" = "allow";
            "~/0_library/**" = "allow";
            "~/1_repos/**" = "allow";
            "~/.0_lumen/**" = "allow";
          };
          default_agent = "wolf";
          agent = {
            wolf = {
              mode = "all";
              color = "#FFFFFF";
              description = "Rafiq's personal assistant.";
              prompt = "You are Wolf, Rafiq's personal assistant.";
            };
          };
        };
      };
    };
    home.shellAliases.oc = "opencode";
  };
}
