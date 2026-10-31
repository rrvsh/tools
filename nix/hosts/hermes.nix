{ config, primaryUsers, ... }:
let
  cfg = config.flake;
in
{
  config.flake.hosts.nixos.hermes = {
    hostPlatform = "x86_64-linux";
    primaryUser = primaryUsers.rafiq;
    modules = [
      cfg.modules.nixos.user-config
      cfg.modules.nixos.vultr-vps
    ];
    extraConfig =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        boot = {
          kernelParams = [
            "console=ttyS1,115200n8"
            "console=tty0"
          ];
          loader = {
            efi.canTouchEfiVariables = false;
            grub = {
              enable = true;
              useOSProber = false;
            };
          };
        };
        fileSystems = {
          "/" = {
            device = "/dev/disk/by-uuid/cb9f37af-53d2-4510-b513-a8f8c2486445";
            fsType = "ext4";
          };
          "/boot/efi" = {
            device = "/dev/disk/by-uuid/D7A0-0D7E";
            fsType = "vfat";
          };
        };
        swapDevices = [ { device = "/swapfile"; } ];
        networking.firewall.allowedTCPPorts = [
          22
          80
          443
        ];
        security.acme = {
          acceptTerms = true;
          defaults.email = "rafiq@rrv.sh";
        };
        services.nginx = {
          enable = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedProxySettings = true;
          recommendedTlsSettings = true;
          virtualHosts."rrv.sh" = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://127.0.0.1:8080";
          };
        };
        users = {
          groups.site = { };
          users.site = {
            isSystemUser = true;
            group = "site";
            home = "/var/lib/site";
          };
        };
        systemd = {
          services = {
            site = {
              description = "rrv.sh site";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                User = "site";
                Group = "site";
                ExecStart = "${cfg.packages.${pkgs.stdenv.hostPlatform.system}.site-deploy}/bin/site";
                Restart = "always";
                RestartSec = "5s";
                StateDirectory = "site";
                WorkingDirectory = "/var/lib/site";
              };
            };
            site-content-refresh = {
              description = "Refresh rrv.sh site content";
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${
                  cfg.packages.${pkgs.stdenv.hostPlatform.system}.site-content-refresh
                }/bin/site-content-refresh";
              };
            };
          };
          timers.site-content-refresh = {
            description = "Refresh rrv.sh site content periodically";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = "10min";
              RandomizedDelaySec = "1min";
            };
          };
        };
      };
  };
}
