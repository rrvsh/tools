## Task

Enable Docker on the `nemesis` NixOS host.

## Breakdown of Work

1. Explored host configuration and existing module structure for `nemesis`.
2. Reviewed `nix/modules/docker.nix` and found Docker was configured only for Darwin via Homebrew.
3. Added a NixOS Docker module under `config.flake.modules.nixos.docker`.
4. Imported the new Docker module into the `nemesis` host module list.

## Reasoning and Decisions

- Implemented Docker as a reusable NixOS module (`modules.nixos.docker`) to match the repository's module conventions.
- Enabled Docker daemon with `virtualisation.docker.enable = true`.
- Added `rafiq` to the `docker` group so Docker can be used without `sudo`.
- Kept Darwin Docker setup untouched to avoid changing existing macOS behavior.

## Learning Points

- `nemesis` is composed from host-local modules plus selected reusable modules under `cfg.modules.nixos.*`.
- `docker.nix` existed but previously covered only Darwin package installation.

## Bugs Encountered and Solutions

- No implementation bugs encountered during configuration edits.

## Apply and Verify

- Ran `sudo nixos-rebuild switch --flake .#nemesis` successfully.
- Confirmed Docker units were started during activation (`docker.service`, `docker.socket`).
- `docker --version` reports `Docker version 29.2.0`.
- A direct `docker run --rm hello-world` failed with Docker socket permission denied in the current shell session.
- Verified daemon functionality by running under the docker group context:
  - `sg docker -c 'docker run --rm hello-world'`
  - Received the expected "Hello from Docker!" output.

## Follow-up Notes

- Because group membership changed, current login shells may need a new session (`logout/login`) for plain `docker` commands without `sg`.
