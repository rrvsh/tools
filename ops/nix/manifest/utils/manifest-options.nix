{ lib, ... }:
let
  inherit (lib.options) mkOption;
  inherit (lib.types)
    raw
    attrsOf
    submodule
    listOf
    deferredModule
    str
    bool
    port
    enum
    ;
  reverseProxyOptions = {
    options = {
      domain = mkOption { type = str; };
      port = mkOption { type = port; };
      type = mkOption { type = enum [ "proxy" ]; };
    };
  };
  nixosOptions = {
    options = {
      arch = mkOption {
        type = str;
        default = "";
        description = "The system architecture for this host.";
      };
      createImage = mkOption {
        type = bool;
        default = false;
        description = ''
          Whether to build an SD image for this host.
          If true, it will appear in `config.flake.images`.
        '';
      };
      modules = mkOption {
        type = listOf deferredModule;
        default = [ ];
        description = "Modules to import for this host.";
      };
      needs.nginx = mkOption {
        type = listOf (submodule reverseProxyOptions);
        default = [ ];
      };
    };
  };
in
{
  options.flake = {
    self = mkOption { type = raw; };
    manifest = {
      nodes.nixos = mkOption {
        default = { };
        type = attrsOf (submodule nixosOptions);
      };
    };
  };
}
