{
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      (inputs.import-tree ./ops/nix)
      // {
        systems = import inputs.systems;
        flake.paths = {
          root = ./.;
          facter = ./ops/facter;
          secrets = ./ops/sops;
        };
      }
    );
  inputs = {
    disko.url = "github:nix-community/disko";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    import-tree.url = "github:vic/import-tree";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rrv-sh.inputs.nixpkgs.follows = "nixpkgs";
    rrv-sh.url = "github:rrvsh/rrv.sh";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    systems.url = "github:nix-systems/default";
  };
}
