{ lib, ... }:
{
  config.flake.modules.homeManager.rafiq = {
    programs.starship = {
      enable = true;
      settings = {
        add_newline = false;
        format = lib.strings.concatStrings [
          "$hostname$directory$git_branch$git_status$git_state"
          "$fill"
          "$nix_shell"
          "$time"
          "\n"
          "$battery$character"
        ];
        right_format = "$git_metrics";
        directory.truncation_symbol = "../";
        git_status.format = "[$all_status$ahead_behind]($style)";
        git_metrics.format = "([-$deleted]($deleted_style) )([+$added]($added_style))";
        git_branch.format = "[$symbol$branch(:$remote_branch)]($style) ";
        git_metrics.disabled = false;
        time = {
          disabled = false;
          format = "[$time]($style)";
          time_format = "%R";
        };
        shlvl.disabled = false;
        username.disabled = true;
        fill.symbol = " ";
        python = {
          symbol = "";
          format = "[$symbol ]($style)";
          style = "yellow";
        };
      };
    };
  };
}
