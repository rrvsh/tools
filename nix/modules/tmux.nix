{
  config.flake.modules.homeManager.rafiq = {
    programs.tmux = {
      enable = true;
      extraConfig = ''
        set -g extended-keys on

        bind-key -n C-w kill-pane
        bind-key -n C-d split-window -h -c "#{pane_current_path}"
        bind-key -n C-S-d split-window -v -c "#{pane_current_path}"

        bind-key -n C-h select-pane -L
        bind-key -n C-j select-pane -D
        bind-key -n C-k select-pane -U
        bind-key -n C-l select-pane -R

        bind-key -n C-S-h resize-pane -L 5
        bind-key -n C-S-j resize-pane -D 5
        bind-key -n C-S-k resize-pane -U 5
        bind-key -n C-S-l resize-pane -R 5

        bind-key -n C-Tab next-window
        bind-key -n C-S-Tab previous-window
      '';
    };
  };
}
