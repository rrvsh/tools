{ inputs, ... }:
{
  config.flake.modules.nixos.greetd-tuigreet =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      cfg = config.services.tuigreet;
      format = pkgs.formats.toml { };
      tuigreetPackage = inputs.tuigreet.packages.${system}.tuigreet.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./greetd-tuigreet-intro.patch ];
      });
    in
    {
      options.services.tuigreet = {
        enable = lib.mkEnableOption "greetd login manager with the tuigreet greeter";
        package = lib.mkOption {
          type = lib.types.package;
          default = tuigreetPackage;
          description = "Which tuigreet package to run as the greeter.";
        };
        intro = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "typewriter"
              "scanline"
              "split"
              "cursor-wake"
              "flicker"
            ]
          );
          default = null;
          description = "Optional one-shot animation used to reveal the login prompt.";
        };
        settings = lib.mkOption {
          inherit (format) type;
          default = { };
          description = "tuigreet config, rendered to /etc/tuigreet/config.toml.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.greetd = {
          enable = true;
          useTextGreeter = true;
          settings.default_session = {
            user = "greeter";
            command =
              if cfg.intro == null then
                lib.getExe cfg.package
              else
                "${pkgs.writeShellScript "tuigreet-session" ''
                  exec ${lib.getExe' pkgs.coreutils "env"} \
                    TUIGREET_INTRO=${lib.escapeShellArg cfg.intro} \
                    ${lib.getExe cfg.package}
                ''}";
          };
        };
        environment.etc."tuigreet/config.toml".source = format.generate "tuigreet-config.toml" cfg.settings;
      };
    };
}
