{ inputs, ... }:
{
  flake = {
    manifest.hosts.nixos.veil = {
      arch = "aarch64";
      createImage = true;
    };
    modules.nixos.veil =
      { pkgs, config, ... }:
      {
        nixpkgs.hostPlatform.system = "aarch64-linux";
        system.stateVersion = "25.11";
        nix.settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          substituters = [ "https://nix-community.cachix.org" ];
          trusted-substituters = [ "https://nix-community.cachix.org" ];
          trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
        };
        services = {
          openssh.enable = true;
          nginx.enable = true;
          nginx.virtualHosts."rrv.sh" = {
            addSSL = true;
            useACMEHost = "rrv.sh";
            acmeRoot = null; # needed for DNS validation
            locations."/".root = ../www/rrv.sh;
          };
          tailscale = {
            enable = true;
            authKeyFile = config.sops.secrets."keys/tailscale".path;
          };
        };
        users = {
          mutableUsers = false;
          groups.users.gid = 100;
          users.rafiq = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            packages = with pkgs; [ git ];
            hashedPasswordFile = config.sops.secrets."rafiq/hashedPassword".path;
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq"
            ];
          };
          users.nginx.extraGroups = [ "acme" ];
        };
        security = {
          sudo.wheelNeedsPassword = false;
          acme = {
            acceptTerms = true;
            defaults = {
              email = "rafiq@rrv.sh";
              dnsProvider = "cloudflare";
              credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets."keys/cloudflare".path;
            };
            certs."rrv.sh".extraDomainNames = [ "*.rrv.sh" ];
          };
        };
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];
        sops.secrets = {
          "rafiq/hashedPassword".neededForUsers = true;
          "rafiq/hashedPassword".sopsFile = ./users.yaml;
          "keys/cloudflare".sopsFile = ./keys.yaml;
          "keys/tailscale".sopsFile = ./keys.yaml;
        };
      };
  };
}
