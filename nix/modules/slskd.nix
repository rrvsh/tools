{ config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  sopsFile = root + "/sops/slskd.yaml";
in
{
  config.flake.modules = {
    darwin.slskd =
      {
        config,
        pkgs,
        primaryUser,
        ...
      }:
      let
        version = "0.26.0";
        stateDir = "${config.users.users.${primaryUser.name}.home}/Library/Application Support/slskd";
        directories = {
          downloads = "${stateDir}/downloads";
          incomplete = "${stateDir}/incomplete";
        };
        package = pkgs.stdenvNoCC.mkDerivation {
          pname = "slskd";
          inherit version;
          src = pkgs.fetchzip {
            url = "https://github.com/slskd/slskd/releases/download/${version}/slskd-${version}-osx-arm64.zip";
            hash = "sha256-vdoJy2ZpElYJA43mNZfExNK4Mpnw8ApVxVDzPq1s97I=";
            stripRoot = false;
          };
          installPhase = ''
            runHook preInstall
            mkdir -p "$out/libexec/slskd"
            cp -R . "$out/libexec/slskd/"
            chmod +x "$out/libexec/slskd/slskd"
            runHook postInstall
          '';
          meta = {
            description = "Modern client-server application for the Soulseek file-sharing network";
            homepage = "https://github.com/slskd/slskd";
            license = pkgs.lib.licenses.agpl3Only;
            platforms = [ "aarch64-darwin" ];
          };
        };
        settings = (pkgs.formats.yaml { }).generate "slskd.yml" {
          inherit directories;
          flags.no_version_check = true;
          shares.directories = [ directories.downloads ];
        };
      in
      {
        launchd.user.agents.slskd = {
          serviceConfig = {
            ProgramArguments = [
              "${pkgs.writeShellScript "slskd" ''
                set -euo pipefail
                umask 0077
                mkdir -p ${pkgs.lib.escapeShellArg directories.incomplete} ${pkgs.lib.escapeShellArg directories.downloads}
                export SLSKD_SLSK_USERNAME="$(<${
                  config.sops.secrets."slskd/soulseek-username".path
                })-${config.networking.hostName}"
                export SLSKD_SLSK_PASSWORD="$(<${config.sops.secrets."slskd/soulseek-password".path})"
                export SLSKD_USERNAME="$(<${config.sops.secrets."slskd/web-username".path})"
                export SLSKD_PASSWORD="$(<${config.sops.secrets."slskd/web-password".path})"
                cd ${package}/libexec/slskd
                exec ${package}/libexec/slskd/slskd \
                  --app-dir ${pkgs.lib.escapeShellArg stateDir} \
                  --config ${settings}
              ''}"
            ];
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            # Change the plist when credentials change so launchd restarts slskd with the new values.
            EnvironmentVariables.SLSKD_SECRETS_HASH =
              config.sops.secrets."slskd/soulseek-username".sopsFileHash;
          };
        };

        sops.secrets =
          let
            mkSecret = _: {
              inherit sopsFile;
              owner = primaryUser.name;
            };
          in
          pkgs.lib.genAttrs [
            "slskd/soulseek-username"
            "slskd/soulseek-password"
            "slskd/web-username"
            "slskd/web-password"
          ] mkSecret;
      };

    nixos.slskd =
      { config, lib, ... }:
      let
        directories = {
          downloads = "/var/lib/slskd/downloads";
          incomplete = "/var/lib/slskd/incomplete";
        };
      in
      {
        services.slskd = {
          enable = true;
          # The default group is slskd. Use users so the primary user and MusicGrabber can access completed files.
          group = "users";
          environmentFile = config.sops.templates."slskd.env".path;
          openFirewall = true;
          settings = {
            inherit directories;
            shares.directories = [ directories.downloads ];
          };
        };

        sops = {
          secrets = {
            "slskd/soulseek-username".sopsFile = sopsFile;
            "slskd/soulseek-password".sopsFile = sopsFile;
            "slskd/web-username".sopsFile = sopsFile;
            "slskd/web-password".sopsFile = sopsFile;
          };
          templates."slskd.env" = {
            owner = "slskd";
            # Restart slskd after credential changes so it reloads the rendered environment file.
            restartUnits = [ "slskd.service" ];
            content = ''
              SLSKD_SLSK_USERNAME=${
                config.sops.placeholder."slskd/soulseek-username"
              }-${config.networking.hostName}
              SLSKD_SLSK_PASSWORD=${config.sops.placeholder."slskd/soulseek-password"}
              SLSKD_USERNAME=${config.sops.placeholder."slskd/web-username"}
              SLSKD_PASSWORD=${config.sops.placeholder."slskd/web-password"}
            '';
          };
        };

        systemd = {
          services.slskd.serviceConfig = {
            # Nixpkgs makes every shared directory read-only, but this directory also receives completed downloads.
            ReadOnlyPaths = lib.mkForce [ ];
            StateDirectoryMode = "0750";
            UMask = "0007";
            WorkingDirectory = "${config.services.slskd.package}/lib/slskd";
          };
          tmpfiles.rules = [
            "d ${directories.incomplete} 0770 slskd users -"
            "d ${directories.downloads} 0770 slskd users -"
          ];
        };
      };
  };
}
