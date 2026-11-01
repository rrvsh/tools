{
  inputs,
  config,
  lib,
  toolsLib,
  ...
}:
let
  cfg = config.flake;
  machineSystems = builtins.mapAttrs (toolsLib.hosts.mkSystem {
    systemBuilder = inputs.nixpkgs.lib.nixosSystem;
    platformModules = cfg.modules.nixos;
    includeExtraConfig = true;
    includeMachineConfig = true;
  }) cfg.hosts.nixos;
  vmSystems = lib.mapAttrs' (
    name: value:
    lib.nameValuePair "${name}-vm" (
      (toolsLib.hosts.mkSystem {
        systemBuilder = inputs.nixpkgs.lib.nixosSystem;
        platformModules = cfg.modules.nixos;
        includeExtraConfig = true;
        systemKind = "vm";
      })
        "${name}-vm"
        (
          value
          // {
            profiles = value.vm.profiles;
            modules =
              value.modules
              ++ value.vm.modules
              ++ [
                (
                  { modulesPath, ... }:
                  {
                    imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
                    virtualisation = {
                      useBootLoader = true;
                      useEFIBoot = true;
                      useDefaultFilesystems = true;
                      inherit (value.vm) memorySize cores diskSize;
                      graphics = true;
                      resolution = {
                        x = 1600;
                        y = 900;
                      };
                      forwardPorts = [
                        {
                          from = "host";
                          host = {
                            address = "127.0.0.1";
                            port = 2222;
                          };
                          guest.port = 22;
                        }
                      ];
                      qemu.forceAccel = true;
                    };
                    networking.firewall.allowedTCPPorts = [ 22 ];
                    services.openssh.enable = true;
                  }
                )
              ];
            extraConfig.imports = [
              value.extraConfig
              value.vm.extraConfig
            ];
          }
        )
    )
  ) (lib.filterAttrs (_: value: value.vm.enable) cfg.hosts.nixos);
in
{
  options.flake.hosts.nixos = toolsLib.hosts.hostOptions;
  config.flake.nixosConfigurations = machineSystems // vmSystems;
}
