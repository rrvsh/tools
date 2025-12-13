{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    str
    attrsOf
    submodule
    bool
    ;
in
{
  options.flake.users.users = mkOption {
    type = attrsOf (submodule {
      options = {
        primary = mkOption {
          type = bool;
          default = false;
          description = "Denote this user as able to modify the systems controlled by this flake.";
        };
        email = mkOption {
          # NOTE: this is not used for anything now but will be for cloudflare etc
          type = str;
          description = "The email of the user.";
        };
        pubkey = mkOption {
          type = str;
          description = "The SSH public key of the user. Used to add the user as authorised on every machine.";
        };
      };
    });
  };
  config.flake.modules.darwin.default =
    { config, ... }:
    (import ./_darwin.nix {
      inherit
        cfg
        config
        inputs
        lib
        ;
    });
}
