# considerations: probably want the following structure for keybinds
# super -> within a window, new tab, copy, paste, etc
# leader keys -> within an app, e.g <leader>s to save
# alt ->
# ctrl ->
# super alt -> move a window?
# super ctrl -> workspaces?
# shift should be a modifier of other modifiers aka super shift t in firefox
{ inputs, lib, ... }:
let
  inherit (lib.meta) getExe;
in
{
  flake = {
    allowedUnfreePackages = [ "slack" ];
    modules.darwin.rafiq = {
      homebrew.brews = [ "docker" ];
    };
    modules.homeManager.rafiq =
      { pkgs, config, ... }:
      let
        git = getExe pkgs.git;
        fish = getExe pkgs.fish;
        sk = getExe pkgs.skim;
        rg = getExe pkgs.ripgrep;
        gdb = "${git} rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-";
      in
      {
        imports = [ inputs.nix-index-database.homeModules.nix-index ];
        home = {
          packages = with pkgs; [
            gh
            monitorcontrol
            slack
          ];
          shellAliases = {
            inherit gdb;
            cd = "z";
            v = "$EDITOR";
            e = "${fish} -c 'set -e var; set var (${sk}); test -n \"$var\"; and $EDITOR $var'";
            t = config.programs.yazi.shellWrapperName;
            gaa = "${git} add";
            gap = "${git} add -p .";
            gc = "${git} commit";
            gcam = "${git} commit -am";
            gcamend = "${git} commit -a --amend --no-edit";
            gcend = "${git} commit --amend --no-edit";
            gcm = "${git} commit -m";
            gd = "${git} diff";
            gdh = "${git} diff HEAD";
            gdm = "${git} diff $(${gdb})";
            gds = "${git} diff --staged";
            grc = "${git} rebase --continue";
            gs = "${git} status";
            gu = "${git} push";
            gundo = "${git} add . && ${git} stash && ${git} reset HEAD~1 && ${git} stash pop";
            gupdate = "${git} add . && ${git} stash && ${git} checkout $(${gdb}) && ${git} pull && ${git} checkout - && ${git} rebase $(${gdb}) && ${git} stash pop";
            gupdate-main = "${git} add . && ${git} stash && ${git} checkout $(${gdb}) && ${git} pull && ${git} checkout - && ${git} stash pop";
          };
        };
        programs = {
          zoxide.enable = true;
          nix-index.enable = true;
          nix-index-database.comma.enable = true;
          mise.enable = true;
          skim.enable = true;
          skim.defaultCommand = "${rg} --files --hidden --glob '!.git'";
          ripgrep-all.enable = true;
          direnv.enable = true;
          direnv.nix-direnv.enable = true;
          nvf.settings.vim = {
            lsp.enable = true;
            languages.python = {
              enable = true;
              format.enable = true;
              format.type = "ruff";
              lsp.enable = true;
              lsp.server = "pyright";
              treesitter.enable = true;
            };
          };
        };
      };
  };
}
