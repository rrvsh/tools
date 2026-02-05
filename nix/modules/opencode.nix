{
  config.flake = {
    modules.homeManager.rafiq = {
      programs = {
        opencode = {
          enable = true;
          enableMcpIntegration = true;
          settings = {
            permission.external_directory = {
              "/tmp/**" = "allow";
              "/private/var/folders/**" = "allow";
            };
          };
        };
      };
      home.shellAliases.oc = "opencode";
    };
  };
}
