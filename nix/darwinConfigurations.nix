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
  options.flake.hosts.darwin = toolsLib.hosts.hostOptions;
  config.flake.darwinConfigurations = builtins.mapAttrs (toolsLib.hosts.mkSystem {
    systemBuilder = inputs.nix-darwin.lib.darwinSystem;
    platformModules = cfg.modules.darwin;
  }) cfg.hosts.darwin;
}
