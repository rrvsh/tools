{
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      (inputs.import-tree ./ops/nix)
      // {
        systems = import inputs.systems;
        flake.paths = {
          root = ./.;
          device = ./ops/definitions/devices;
          secrets = ./ops/definitions/secrets;
        };
      }
    );
  inputs = {
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    systems.url = "github:nix-systems/default";
  };
}
