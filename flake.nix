{
  description = "personal infra and configs for rafiq";
  nixConfig = {
    extra-substituters = [
      "https://cuda-maintainers.cachix.org"
      "https://rrvsh.cachix.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://pi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "rrvsh.cachix.org-1:pkljA9d1Q88P7GB/bUHB5CBJacyCUp/m4zXu8IzI4a4="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk="
    ];
  };
  outputs =
    inputs@{ flake-parts, import-tree, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ((import-tree ./nix) // { flake.paths.root = ./.; });
  inputs = {
    aenyrathia = {
      url = "github:rrvsh/aenyrathia/prime";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agent-browser.url = "github:rrvsh/agent-browser-nix";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/4903993cdd9747a8a0e11d4022d88d1e20b33eb4";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    # Pin this hypr-dynamic-cursors to Hyprland input - it will break on mismatched revs.
    hypr-dynamic-cursors = {
      url = "github:VirtCode/hypr-dynamic-cursors";
      inputs.hyprland.follows = "hyprland";
    };
    import-tree.url = "github:vic/import-tree";
    tuigreet = {
      url = "github:tuigreet/tuigreet";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nixpkgs-firefox-darwin = {
      url = "github:bandithedoge/nixpkgs-firefox-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    mac-app-util.url = "github:hraban/mac-app-util";
    pi.url = "github:rrvsh/pi-coding-agent-nix";
    pi-claude-bridge = {
      url = "github:rrvsh/pi-claude-bridge-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pi-slopchop = {
      url = "github:rrvsh/pi-slopchop-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pi-session-drain = {
      url = "github:rrvsh/pi-session-drain/prime";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
