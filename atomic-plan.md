# Atomic module plan

## `home-manager-config` ✅

### File

- `nix/modules/home-manager-config.nix`

### Exports

- `config.flake.modules.nixos.home-manager-config`
- `config.flake.modules.darwin.home-manager-config`

### Scope

- Home Manager module import
- `home-manager.backupFileExtension`
- `home-manager.overwriteBackup`
- `home-manager.useUserPackages`
- `home-manager.useGlobalPkgs`

## `nix-index-comma` ✅

### File

- `nix/modules/nix-index-comma.nix`

### Exports

- `config.flake.modules.homeManager.nix-index-comma`

### Scope

- Home Manager import:
  - `inputs.nix-index-database.homeModules.nix-index`
- `programs.nix-index.enable`
- `programs.nix-index-database.comma.enable`
- `home.file.".pi/agent/skills/comma/SKILL.md".text`

## `yazi` ✅

### File

- `nix/modules/yazi.nix`

### Exports

- `config.flake.modules.homeManager.yazi`
- `config.flake.modules.darwin.yazi`

### Scope

- Darwin system-level Yazi binary cache:
  - `https://yazi.cachix.org`
  - `yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k=`
- `programs.yazi.enable`
- `programs.yazi.shellWrapperName`
- Yazi package from `inputs.yazi`
- `exiftool` runtime dependency override
- `path-from-root` plugin from `inputs.path-from-root-yazi`
- Yazi keymap for `path-from-root`

## `neovim` ✅

### File

- `nix/modules/neovim.nix`

### Exports

- `config.flake.modules.homeManager.neovim`

### Scope

- `xdg.configFile."nvim/lua".source`
- `programs.neovim.enable`
- `programs.neovim.defaultEditor`
- `programs.neovim.viAlias`
- `programs.neovim.vimAlias`
- `programs.neovim.initLua`
- Neovim plugins
- Neovim extra packages / language tooling

## `ghostty` ✅

### File

- `nix/modules/ghostty.nix`

### Exports

- `config.flake.modules.homeManager.ghostty`

### Scope

- `programs.ghostty.enable`
- Linux package override:
  - `programs.ghostty.package = pkgs.ghostty`
- Darwin package override:
  - `programs.ghostty.package = null`

## `firefox` ✅

### File

- `nix/modules/firefox.nix`

### Exports

- `config.flake.modules.homeManager.firefox`
- `config.flake.modules.darwin.firefox`

### Scope

- Darwin Firefox package support:
  - `nixpkgs.config.allowUnfreePredicate` for `firefox-bin`
  - `nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ]`
  - Darwin `home.packages` entry for `firefox-bin`
- `programs.firefox.enable`
- Linux package:
  - `programs.firefox.package = pkgs.firefox`
- Darwin package:
  - `programs.firefox.package = null`
- Platform-specific `programs.firefox.configPath`

## `pi-agent` ✅

### File

- `nix/modules/pi-agent.nix`

### Exports

- `config.flake.modules.homeManager.pi-agent`

### Scope

- `home.packages` entry:
  - `pi-coding-agent`
- `home.file.".pi/agent/AGENTS.md".text`

## `steam` ✅

### File

- `nix/modules/steam.nix`

### Exports

- `config.flake.modules.nixos.steam`

### Scope

- `programs.steam.enable`
- `programs.steam.remotePlay.openFirewall`
- `programs.steam.dedicatedServer.openFirewall`
- `programs.steam.localNetworkGameTransfers.openFirewall`
- `programs.gamemode.enable`
- `programs.gamescope.enable`

## `prismlauncher` ✅

### File

- `nix/modules/prismlauncher.nix`

### Exports

- `config.flake.modules.homeManager.prismlauncher`

### Scope

- Home Manager package:
  - `prismlauncher.override { jdks = [ jdk25 ]; }`

## `nvidia-graphics` ✅

### File

- `nix/modules/nvidia-graphics.nix`

### Exports

- `config.flake.modules.nixos.nvidia-graphics`

### Scope

- NVIDIA/Steam unfree allowlist:
  - `nvidia-kernel-modules`
  - `nvidia-persistenced`
  - `nvidia-settings`
  - `nvidia-x11`
  - `steam`
  - `steam-original`
  - `steam-run`
  - `steam-unwrapped`
- `services.xserver.videoDrivers = [ "nvidia" ]`
- `hardware.graphics.enable`
- `hardware.graphics.enable32Bit`
- `hardware.nvidia.modesetting.enable`
- `hardware.nvidia.nvidiaSettings`
- `hardware.nvidia.package`
- `hardware.nvidia.open`
- NVIDIA/Wayland session vars:
  - `GBM_BACKEND`
  - `__GLX_VENDOR_LIBRARY_NAME`
  - `LIBVA_DRIVER_NAME`

## `rosetta-builder` ✅

### File

- `nix/modules/rosetta-builder.nix`

### Exports

- `config.flake.modules.darwin.rosetta-builder`

### Scope

- `inputs.nix-rosetta-builder.darwinModules.default` import
- `nix-rosetta-builder.onDemand`
- Rosetta install activation script:
  - `softwareupdate --install-rosetta --agree-to-license`

## `darwin-system-defaults`

### File

- `nix/modules/darwin-system-defaults.nix`

### Exports

- `config.flake.modules.darwin.darwin-system-defaults`

### Scope

- Disable system sleep:
  - `system.activationScripts.extraActivation.text`
  - `pmset -a disablesleep 1`
  - `pmset -a displaysleep 0`
- macOS defaults:
  - `system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false`
- Keyboard settings:
  - `system.keyboard.enableKeyMapping`
  - `system.keyboard.remapCapsLockToEscape`

## `waybar`

### File

- `nix/modules/waybar.nix`

### Exports

- `config.flake.modules.nixos.waybar`
- `config.flake.modules.homeManager.waybar`

### Scope

- NixOS font packages needed by Waybar styling:
  - `nerd-fonts.jetbrains-mono`
  - `monocraft`
- Linux Home Manager config:
  - `xdg.configFile."hypr/scripts/waybar_peek.py"`
  - `xdg.configFile."waybar/power_menu.xml"`
  - `programs.waybar.enable`
  - `programs.waybar.systemd.enable`
  - Waybar style
  - Waybar settings
  - `systemd.user.services.waybar`
  - `systemd.user.services.waybar-peek`

## `hyprland`

### File

- `nix/modules/hyprland.nix`

### Exports

- `config.flake.modules.nixos.hyprland`
- `config.flake.modules.homeManager.hyprland`

### Scope

- Hyprland NixOS module import
- Hyprland binary cache:
  - `https://hyprland.cachix.org`
  - `hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=`
- `programs.hyprland.enable`
- `programs.hyprland.xwayland.enable`
- `programs.hyprland.package`
- `programs.hyprland.portalPackage`
- `xdg.portal.enable`
- `xdg.portal.extraPortals`
- Hyprland-related session var:
  - `NIXOS_OZONE_WL`
- Home Manager Hyprland config:
  - `wayland.windowManager.hyprland.enable`
  - `wayland.windowManager.hyprland.configType`
  - `wayland.windowManager.hyprland.package`
  - `wayland.windowManager.hyprland.portalPackage`
  - `wayland.windowManager.hyprland.extraConfig`
  - Hyprland monitor/input/general/bind settings
- Home Manager Hypridle config:
  - `services.hypridle.enable`
  - `services.hypridle.settings`
- Hyprland/portal/PipeWire assertions

## `sops-config`

### File

- `nix/modules/sops-config.nix`

### Exports

- `config.flake.modules.nixos.sops-config`
- `config.flake.modules.darwin.sops-config`

### Scope

- SOPS module imports:
  - `inputs.sops-nix.nixosModules.sops`
  - `inputs.sops-nix.darwinModules.sops`
- `sops.age.sshKeyPaths`
