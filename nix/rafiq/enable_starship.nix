{ lib, ... }:
{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.starship = {
        enable = true;
        settings = {
          add_newline = false;
          format = lib.strings.concatStrings [
            # First Line Left
            "$hostname$directory$git_branch$git_status$git_state"
            # Fill First Line Space
            "$fill"
            # First Line Right
            "$nix_shell"
            "$time"
            # Line Break
            "\n"
            # Second Line Left
            "$battery$character"
          ];
          # Second Line Right
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
  };
}
