pi-agent
=======

pi-coding-agent is used as the CLI agent of choice.

Notes
-----

We currently use the nixpkgs-master input for the pi-coding-agent package because [this fix](https://github.com/NixOS/nixpkgs/commit/726fd9f7993e5a6fc427f0441baa2dd63e84b615) has not landed, and the nixos-unstable branch is broken on darwin.
