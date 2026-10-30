{
  inputs,
  config,
  toolsLib,
  ...
}:
let
  cfg = config.flake;
in
{
  options.flake.hosts.nixos = toolsLib.hosts.hostOptions;
  config.flake.nixosConfigurations = builtins.mapAttrs (toolsLib.hosts.mkSystem {
    systemBuilder = inputs.nixpkgs.lib.nixosSystem;
    platformModules = cfg.modules.nixos;
    includeExtraConfig = true;
  }) cfg.hosts.nixos;
}
