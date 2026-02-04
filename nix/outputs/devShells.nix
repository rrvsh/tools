{
  perSystem =
    { pkgs, ... }:
    let
      ciInputs = {
        gha = with pkgs; [
          gh
          zizmor
        ];
        lua = with pkgs; [
          stylua
        ];
        nix = with pkgs; [
          deadnix
          nixfmt-tree
          statix
        ];
        rs = with pkgs; [
          cargo
          clippy
          rustc
          rustfmt
        ];
      };
      defaultInputs = with pkgs; [
        # general
        just

        # nix
        deadnix
        nh
        nixfmt-tree
        statix

        # lua
        luajitPackages.luacheck
        stylua

        # gha yaml
        gh
        zizmor

        # rs
        cargo
        clippy
        rustc
        rustfmt
        bacon

        # docker
        docker
        colima

        # aws
        awscli2

        # terraform
        opentofu
      ];
    in
    {
      devShells = {
        default = pkgs.mkShell {
          buildInputs = defaultInputs;
        };

        ci-gha = pkgs.mkShell {
          buildInputs = ciInputs.gha;
        };

        ci-lua = pkgs.mkShell {
          buildInputs = ciInputs.lua;
        };

        ci-nix = pkgs.mkShell {
          buildInputs = ciInputs.nix;
        };

        ci-rs = pkgs.mkShell {
          buildInputs = ciInputs.rs;
        };
      };
    };
}
