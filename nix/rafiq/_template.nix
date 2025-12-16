{
  inputs,
  lib,
  config,
  ...
}:
{
  config.flake.modules = {
    darwin.rafiq = { };
    homeManager.rafiq = { };
  };
}
