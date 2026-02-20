{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (config.flake.paths) root;
in
{
  config.flake = {
    modules.homeManager.rafiq =
      {
        pkgs,
        config,
        ...
      }:
      let
        epub-nvim = pkgs.vimUtils.buildVimPlugin {
          pname = "epub.nvim";
          version = "main";
          src = inputs.epub-nvim;
        };
        nvim-server-address = "$XDG_RUNTIME_DIR/nvim/server.pipe";
        nvim-client = pkgs.writeShellScriptBin "nvim-client" ''
          #!/usr/bin/env bash
          set -euo pipefail

          server="''${NVIM_SERVER:-${nvim-server-address}}"
          nvim_bin="${lib.getExe config.programs.neovim.finalPackage}"

          if [[ ! -S "$server" ]]; then
            if command -v systemctl >/dev/null 2>&1; then
              systemctl --user start nvim-server.service >/dev/null 2>&1 || true
            fi

            for _ in {1..40}; do
              [[ -S "$server" ]] && break
              sleep 0.05
            done
          fi

          if [[ -S "$server" ]]; then
            exec "$nvim_bin" --server "$server" --remote-ui "$@"
          fi

          exec "$nvim_bin" "$@"
        '';
      in
      {
        xdg.configFile."nvim/lua".source = root + /nvim;
        programs.neovim = {
          enable = true;
          package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
          defaultEditor = false;
          viAlias = true;
          vimAlias = true;
          initLua = "require(\"rafiq\")";
          plugins = with pkgs.vimPlugins; [
            inputs.fff-nvim.packages.${pkgs.stdenv.hostPlatform.system}.fff-nvim
            fidget-nvim
            mini-nvim
            nvim-lspconfig
            plenary-nvim
            which-key-nvim
            yazi-nvim
            epub-nvim
          ];
          extraPackages = with pkgs; [
            cargo
            clippy
            lua-language-server
            nil
            pyright
            ruff
            rust-analyzer
            rustc
            rustfmt
            stylua
            unzip
          ];
        };

        home.packages = [ nvim-client ];

        home.sessionVariables = {
          EDITOR = "nvim-client";
          VISUAL = "nvim-client";
        };

        systemd.user.services.nvim-server = lib.mkIf pkgs.stdenv.isLinux {
          Unit = {
            Description = "Neovim headless server";
            After = [ "graphical-session-pre.target" ];
          };
          Service = {
            Type = "simple";
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p $XDG_RUNTIME_DIR/nvim";
            ExecStart = "${lib.getExe config.programs.neovim.finalPackage} --headless --listen ${nvim-server-address}";
            Restart = "always";
            RestartSec = "1s";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };
  };
}
