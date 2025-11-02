{ config, ... }:
let
  cfg = config.flake;
in
{
  flake.manifest = {
    externals.nginx = {
      node = "veil";
      ssl = {
        enable = true;
        dnsProvider = "cloudflare";
        certs."rrv.sh".extraDomainNames = [ "*.rrv.sh" ];
      };
    };
    nodes.nixos = {
      nephalem = {
        arch = "x86_64";
      };
      veil = {
        arch = "aarch64";
        createImage = true;
        modules = with cfg.modules.nixos; [ rrv-sh ];
        proxies = [
          {
            domain = "rrv.sh";
            port = 2309;
          }
        ];
      };
    };
    users = {
      sops.enable = true;
      users.rafiq = {
        primary = true;
        email = "rafiq@rrv.sh";
        pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq";
      };
    };
  };
  flake.templates.pkg-shell = {
    path = ./_templates/pkg-shell;
    description = "premade package and shell for all systems with flake parts";
  };
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          deadnix
          gh
          git
          just
          nh
          nixfmt-tree
          sops
          statix
          zizmor
        ];
      };
    };
}
