{
  flake = {
    users.users.rafiq = {
      primary = true;
      email = "rafiq@rrv.sh";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n rafiq";
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
