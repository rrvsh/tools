{
  config.flake = {
    modules.nixos.docker = {
      virtualisation.docker.enable = true;
      users.users.rafiq.extraGroups = [ "docker" ];
    };
    modules.darwin.default = {
      homebrew.brews = [ "docker" ];
    };
  };
}
