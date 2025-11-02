{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (cfg.users) admin;
  inherit (cfg.paths) secrets;
  inherit (lib.modules) mkMerge mkIf;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) raw str;
in
{
  options.flake.externals.nginx.ssl = {
    enable = mkEnableOption "";
    dnsProvider = mkOption { type = str; };
    certs = mkOption { type = raw; };
  };
  config.flake.modules.nixos.default =
    { hostName, config, ... }:
    mkIf (hostName == cfg.externals.nginx.node) (mkMerge [
      (mkIf cfg.externals.nginx.ssl.enable {
        users.users.nginx.extraGroups = [ "acme" ];
        security.acme = {
          acceptTerms = true;
          defaults = {
            inherit (admin) email;
            inherit (cfg.externals.nginx.ssl) dnsProvider;
          };
          inherit (cfg.externals.nginx.ssl) certs;
        };
      })
      (mkIf (cfg.externals.nginx.ssl.dnsProvider == "cloudflare" && cfg.secrets.sops.enable) {
        sops.secrets."keys/cloudflare".sopsFile = secrets + /keys.yaml;
        security.acme.defaults.credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" =
          config.sops.secrets."keys/cloudflare".path;
      })
    ]);
}
