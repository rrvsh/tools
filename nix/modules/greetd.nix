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
    in
    {
      options.services.tuigreet = {
        enable = lib.mkEnableOption "greetd login manager with the tuigreet greeter";
        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.tuigreet.packages.${system}.tuigreet;
          description = "Which tuigreet package to run as the greeter.";
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
            command = "${lib.getExe cfg.package}";
          };
        };
        environment.etc."tuigreet/config.toml".source = format.generate "tuigreet-config.toml" cfg.settings;
      };
    };
}
