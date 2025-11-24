{ lib, ... }:
{
  flake = {
    users.users.rafiq = {
      primary = true;
      fullName = "Mohammad Rafiq";
      email = "rafiq@rrv.sh";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n";
      defaultBranchName = "prime";
      apps = {
        editor = "neovim";
        shell = "fish";
        browser = "firefox";
        terminal = "ghostty";
        file-browser = "yazi";
      };
    };
    hosts.darwin.alpha = {
      platform = "aarch64-darwin";
    };
    hosts.nixos.pi = {
      platform = "aarch64-linux";
      extraConfig = {
        services.openssh.enable = true;
        fileSystems."/" = lib.mkDefault {
          device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
          fsType = "ext4";
        };
        boot.loader.grub.enable = lib.mkDefault false;
        boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;
      };
    };
  };
}
