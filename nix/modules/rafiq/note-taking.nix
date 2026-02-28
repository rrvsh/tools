{
  config.flake.modules.homeManager.rafiq = {
    home.shellAliases = {
      lib = "fooc \"$HOME/0_library\"";
      process = "fooc \"$HOME/0_library/notes/process\"";
      day = "v ~/0_library/notes/daily/$(date +%F).md";
      month = "v ~/0_library/notes/monthly/$(date +%Y-%m).md";
    };
  };
}
