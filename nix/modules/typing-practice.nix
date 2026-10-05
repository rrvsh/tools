{ config, ... }:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.typing-practice ];
  };
in
{
  config.flake.modules = {
    darwin.typing-practice = osModule;
    nixos.typing-practice = osModule;
    homeManager.typing-practice =
      { lib, pkgs, ... }:
      let
        system = pkgs.stdenv.hostPlatform.system;
        keybrTui = cfg.packages.${system}.keybr-tui;
        typingPracticeGate = pkgs.writeShellApplication {
          name = "typing-practice-gate";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            state_dir="$HOME/Agents/state/typing-practice/completed"
            day="$(date +%F)"
            marker="$state_dir/$day"

            mkdir -p "$state_dir"

            if [[ -e "$marker" ]]; then
              exit 0
            fi

            data_dir="$("${keybrTui}/bin/keybr-tui" --data-dir)"
            if [[ -z "$data_dir" ]]; then
              printf '%s\n' \
                "Typing practice skipped: keybr-tui did not report its data directory." >&2
              exit 0
            fi

            mkdir -p "$data_dir"
            lock_dir="$data_dir/.daily-shell-gate.lock"

            # Ctrl+C while waiting for another shell skips only this shell.
            trap 'exit 0' INT

            while ! mkdir "$lock_dir" 2>/dev/null; do
              if [[ -e "$marker" ]]; then
                exit 0
              fi

              lock_pid=""
              if [[ -r "$lock_dir/pid" ]]; then
                read -r lock_pid < "$lock_dir/pid" || true
              fi

              if [[ "$lock_pid" =~ ^[0-9]+$ ]] && kill -0 "$lock_pid" 2>/dev/null; then
                printf '\r%s' \
                  "Typing practice is open in another shell; waiting. Ctrl-C skips this shell."
                sleep 1
                continue
              fi

              rm -rf -- "$lock_dir"
            done

            printf '%s\n' "$$" > "$lock_dir/pid"

            cleanup() {
              current_pid=""
              if [[ -r "$lock_dir/pid" ]]; then
                read -r current_pid < "$lock_dir/pid" || true
              fi
              if [[ "$current_pid" == "$$" ]]; then
                rm -rf -- "$lock_dir"
              fi
            }

            trap cleanup EXIT

            printf '\n%s\n\n' \
              "Daily typing practice: complete one lesson, or press Ctrl-C to skip this shell."

            set +e
            "${keybrTui}/bin/keybr-tui" --once
            status=$?
            set -e

            case "$status" in
              0)
                temporary_marker="$(mktemp "$state_dir/.$day.XXXXXX")"
                chmod 0644 "$temporary_marker"
                mv -f -- "$temporary_marker" "$marker"
                printf '\n%s\n' "Daily typing practice complete."
                ;;
              130)
                printf '\n%s\n' "Typing practice skipped for this shell."
                ;;
              *)
                printf '\n%s\n' \
                  "Typing practice failed with status $status; allowing this shell." >&2
                ;;
            esac
          '';
        };
      in
      {
        home.packages = [
          keybrTui
          typingPracticeGate
        ];
        programs.fish.interactiveShellInit = lib.mkAfter ''
          ${typingPracticeGate}/bin/typing-practice-gate
        '';
      };
  };
}
