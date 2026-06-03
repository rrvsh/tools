## Nix config organization

The Nix config in `nix/` is organized as atomic modules in `nix/modules/`.

Module constraints:

- One concern per module: one capability, policy, service, tool, or feature.
- Hosts explicitly import the modules they use.
- Host-specific values stay in host files: hostname, architecture, disks, bootloader, hardware, secrets wiring, and state versions.

When the same concern has different Darwin and NixOS implementations, keep them in one module file so the concern is centralized for reference and changes:

```nix
{
  config.flake.modules.darwin.foo = { ... };
  config.flake.modules.nixos.foo = { ... };
  config.flake.modules.homeManager.foo = { ... };
}
```

Single-platform concerns should only export that platform.

Good examples: `nix-settings`, `passwordless-sudo`, `ssh-config`
