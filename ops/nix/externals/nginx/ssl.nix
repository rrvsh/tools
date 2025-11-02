{ lib, config, ... }:
let
  cfg = config.flake;
  modCfg = config.flake.manifest.externals.nginx;
  inherit (cfg.manifest.users) admin;
  inherit (cfg.paths) secrets;
  inherit (lib.modules) mkMerge mkIf;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) raw str;
in
{
  options.flake.manifest.externals.nginx.ssl = {
    enable = mkEnableOption "";
    dnsProvider = mkOption { type = str; };
    certs = mkOption { type = raw; };
  };
  config.flake.modules.nixos.default =
    { hostName, config, ... }:
    mkIf (hostName == modCfg.node) (mkMerge [
      (mkIf modCfg.ssl.enable {
        users.users.nginx.extraGroups = [ "acme" ];
        security.acme = {
          acceptTerms = true;
          defaults = {
            inherit (admin) email;
            inherit (modCfg.ssl) dnsProvider;
          };
          inherit (modCfg.ssl) certs;
        };
      })
      (mkIf (modCfg.ssl.dnsProvider == "cloudflare" && cfg.manifest.users.sops.enable) {
        sops.secrets."keys/cloudflare".sopsFile = secrets + /keys.yaml;
        security.acme.defaults.credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" =
          config.sops.secrets."keys/cloudflare".path;
      })
    ]);
}
