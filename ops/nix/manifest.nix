{
  flake = {
    users.users.rafiq = {
      primary = true;
      email = "rafiq@rrv.sh";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq";
    };
    secrets.sops.enable = true;
    nodes.nixos = { };
    externals.nginx = {
      node = "veil";
      ssl = {
        enable = true;
        dnsProvider = "cloudflare";
        certs."rrv.sh".extraDomainNames = [ "*.rrv.sh" ];
      };
      proxies = [
        {
          node = "veil";
          domain = "rrv.sh";
          port = 2309;
          apps = [ "rrv-sh" ];
        }
      ];
    };
    templates.pkg-shell = {
      path = ./_templates/pkg-shell;
      description = "premade package and shell for all systems with flake parts";
    };
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
