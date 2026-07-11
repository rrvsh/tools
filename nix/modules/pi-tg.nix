{ config, inputs, ... }:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.pi-tg ];
  };
in
{
  config.flake.modules = {
    nixos.pi-tg = osModule;
    homeManager.pi-tg =
      { pkgs, ... }:
      let
        system = pkgs.stdenv.hostPlatform.system;
        piTg = inputs.self.packages.${system}.pi-tg;
      in
      {
        home.packages = [ piTg ];
        xdg.configFile."pi-tg/env.example".text = ''
          # Copy to ~/.config/pi-tg/env, fill in values, then chmod 600 ~/.config/pi-tg/env.
          PI_TELEGRAM_BOT_TOKEN=
          PI_TELEGRAM_ALLOWED_USERS=
        '';
        systemd.user.services.pi-tg = {
          Unit = {
            Description = "Persistent Telegram interface for Pi";
            ConditionPathExists = "%h/.config/pi-tg/env";
          };
          Service = {
            WorkingDirectory = "%h";
            EnvironmentFile = "%h/.config/pi-tg/env";
            ExecStart = "${piTg}/bin/pi-tg";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
  };
}
