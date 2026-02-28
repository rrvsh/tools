{ lib, ... }:
let
  inherit (lib.options) mkOption;
  inherit (lib.types) int str;
in
{
  options.flake.accounts.rafiq = {
    username = mkOption {
      type = str;
      default = "rafiq";
      description = "Primary account username for rafiq.";
    };
    fullName = mkOption {
      type = str;
      default = "Mohammad Rafiq";
      description = "Full display name for rafiq account metadata.";
    };
    email = mkOption {
      type = str;
      default = "rafiq@rrv.sh";
      description = "Primary email address for rafiq account metadata.";
    };
    nixosUid = mkOption {
      type = int;
      default = 1000;
      description = "Numeric UID for rafiq on NixOS.";
    };
    darwinUid = mkOption {
      type = int;
      default = 501;
      description = "Numeric UID for rafiq on Darwin.";
    };
    sshPublicKey = mkOption {
      type = str;
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n";
      description = "Primary SSH public key for rafiq account access.";
    };
  };
}
