{ inputs, ... }:
{
  config.flake.packages.aarch64-linux.rosetta-builder-image =
    inputs.nix-rosetta-builder.packages.aarch64-linux.image;
}
