{
  perSystem =
    { pkgs, ... }:
    {
      devShells = {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
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
        };

        ci-gha = pkgs.mkShell {
          buildInputs = with pkgs; [
            gh
            zizmor
          ];
        };

        ci-lua = pkgs.mkShell {
          buildInputs = with pkgs; [
            stylua
          ];
        };

        ci-nix = pkgs.mkShell {
          buildInputs = with pkgs; [
            deadnix
            nixfmt-tree
            statix
          ];
        };

        ci-rs = pkgs.mkShell {
          buildInputs = with pkgs; [
            cargo
            clippy
            rustc
            rustfmt
          ];
        };
      };
    };
}
