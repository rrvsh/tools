# VPS NixOS migration plan

## Current state

- Target host: `hermes` / `rrv.sh`.
- Current VPS OS: Ubuntu 22.04.5 on Vultr VC2.
- Downtime is acceptable.
- VPS state is disposable; source of truth is GitHub/repos plus DNS.
- One-time `nixos-infect` bootstrap may run on the VPS.
- Normal rebuilds/deploys will be built from this machine or future CI/cache, then activated remotely.

## Completed work

- Added `hermes` NixOS host in `nix/hosts.nix`:
  - `x86_64-linux`, primary user metadata `rafiq`
  - imports `user-config` so the common host builder's `home-manager.extraSpecialArgs` option exists without importing a full user profile
  - inlines rrv.sh service config under the host
  - nginx enabled with ACME, forced HTTPS, and `rrv.sh` reverse proxy to `127.0.0.1:8080`
  - ACME terms accepted with email `rafiq@rrv.sh`
  - `site.service` runs `tools#site-deploy` as the unprivileged `site` user with `HOST=127.0.0.1`, restarts always, and owns `/var/lib/rrv-sh` through `StateDirectory=rrv-sh`
  - firewall opens TCP `22`, `80`, and `443`
  - uses current Vultr root/EFI UUIDs, swapfile, GRUB removable EFI, serial console params, and default DHCP
- Local validation before VPS infection:
  - `nix develop -c just format-nix`
  - `nix flake check --no-build` passed; learnt that a host without `user-config` fails because the shared host builder always sets `home-manager.extraSpecialArgs`
  - `nix build .#nixosConfigurations.hermes.config.system.build.toplevel` built `/nix/store/j75w2vqwls3ss5fb7z0n5anxk2gz2kz5-nixos-system-hermes-26.05.20260523.2991645`
  - inspected generated nginx config, `site.service`, ACME settings, and firewall ports
- Ran `nixos-infect` remotely with `NIX_CHANNEL=nixos-unstable PROVIDER=vultr NO_REBOOT=1`.
  - It completed with exit code 0 and installed `/nix/store/qwzmvlbaad3dr0dv552a7x5qkpw5jl7s-nixos-system-hermes-26.11pre1008282.331800de5053` as `/nix/var/nix/profiles/system`.
  - Pre-reboot inspection confirmed Ubuntu was still reachable by SSH, `/nix/var/nix/profiles/system` existed, and GRUB files were written.
  - Learnt/risk observed: `nixos-infect` renamed `/boot/efi` to `/boot/efi.bak` and installed GRUB into `/boot/efi`; after reboot the VPS stopped responding to ping/SSH. This likely requires Vultr console/rescue/API intervention to inspect boot/network state.
- Post-infection local config hardening after the failed reboot:
  - changed Hermes from default DHCP/dhcpcd to explicit `systemd-networkd` matching MAC `56:00:06:13:a0:46`, DHCP IPv4, and IPv6 link-local
  - changed GRUB to `efiInstallAsRemovable = true` and `efi.canTouchEfiVariables = false` for safer Vultr EFI boot behavior
  - rebuilt successfully as `/nix/store/p2hjai7g19bndgkp27ck6rf725dwqcc3-nixos-system-hermes-26.05.20260523.2991645` after networkd/removable-boot hardening
- Moved post media into `site-content/assets`.
- Enabled Git LFS in `site-content` for PNG, ZIP, and PDF assets.
- Rewrote post media links from `/static/...` to `/assets/...`.
- Added Rust startup content sync:
  - content repo: `https://github.com/rrvsh/site-content.git`
  - content checkout: `/var/lib/rrv-sh/content`
  - startup runs Git pull and Git LFS pull
- Removed `site-content` from the `tools` flake inputs.
- Added app-only `tools#site-deploy` package.
- `tools#site-deploy` contains:
  - `bin/site`
  - `share/rrv-sh/static`
- `tools#site-deploy` wrapper is generated with `makeWrapper` and sets:
  - `STATIC_DIR=$out/share/rrv-sh/static`
  - `PATH` with Nix `git` and `git-lfs`
- Package wrapper environment is limited to `STATIC_DIR` plus `PATH` for Git tooling.
- Current VPS service sets bind policy with `Environment=HOST=127.0.0.1`.
- Current VPS serves content from `/var/lib/rrv-sh/content`.
- Current VPS app listens on `127.0.0.1:8080`.
- Current VPS nginx proxies HTTPS to `127.0.0.1:8080`.
- Migrated content-owned media was removed from VPS app static.
- Profile refactor committed: `5f03a9a refactor(profiles): minimize default nixos profile`.

## Current VPS facts

- Public IPv4: `45.32.116.84`.
- Interface: `enp1s0`.
- MAC: `56:00:06:13:a0:46`.
- Root filesystem after Vultr reinstall:
  - device: `/dev/vda2`
  - UUID: `cb9f37af-53d2-4510-b513-a8f8c2486445`
  - type: ext4
- EFI filesystem after Vultr reinstall:
  - device: `/dev/vda1`
  - UUID: `D7A0-0D7E`
  - type: vfat
  - mount: `/boot/efi`
- Swapfile: `/swapfile` created manually after the flake switch because the reinstall did not create one.
- Current app package: `/nix/store/w2f79vjyvwxr20nq5672b2bpj3vcsgy7-site-deploy`.
- Current content rev: `e353baa6ccfd353aa32b93929381d8c465845111`.
- Current flake-built system after final reboot: `/nix/store/8ar3mfwd73mq015ih863ajk2vxwr9rhk-nixos-system-hermes-26.05.20260523.2991645`.

## NixOS profile state

- NixOS `profile-default` imports:
  - `allowedUnfreePackages`
  - `nix-settings`
  - `ssh-config`
- NixOS `profile-development` imports:
  - `passwordless-sudo`
  - `sops-config`
  - `tailscale-config`
  - development tooling modules
- NixOS `profile-development` enables NetworkManager.
- NixOS `profile-graphical` enables:
  - polkit
  - dconf
- NixOS `ssh-config` sets:
  - `PermitRootLogin=prohibit-password`
  - `PasswordAuthentication=false`
  - `KbdInteractiveAuthentication=false`
  - root authorized keys from `primaryUser.sshAuthorizedKeys`

## Hermes NixOS config plan

1. Add `hermes` host with inlined rrv.sh config:
   - `hostPlatform = "x86_64-linux"`
   - primary user `rafiq`
   - enable nginx
   - configure `rrv.sh` virtual host
   - enable ACME
   - force HTTPS
   - proxy `/` to `http://127.0.0.1:8080`
   - set ACME email `rafiq@rrv.sh`
   - accept ACME terms
   - add unprivileged `site` user and `site.service`
   - set `HOST=127.0.0.1`
   - run `site-deploy`
   - restart always

2. Add Hermes boot/filesystem config:
   - `/`: UUID `cb9f37af-53d2-4510-b513-a8f8c2486445`, ext4
   - `/boot/efi`: UUID `D7A0-0D7E`, vfat
   - swapfile `/swapfile`
   - GRUB removable EFI
   - kernel params:
     - `console=ttyS1,115200n8`
     - `console=tty0`

3. Add Hermes networking/firewall:
   - default NixOS DHCP/dhcpcd
   - firewall TCP ports:
     - `80`
     - `443`
     - `22`

4. Build locally:

   ```sh
   nix flake check --no-build
   nix build .#nixosConfigurations.hermes.config.system.build.toplevel
   ```

5. Inspect generated system:
   - nginx vhost for `rrv.sh`
   - ACME enabled for `rrv.sh`
   - `site.service` has `HOST=127.0.0.1`
   - firewall opens `22`, `80`, and `443`
   - site package path resolves to `site-deploy`

6. Run one-time `nixos-infect`.

7. Reboot into NixOS.

8. Switch from this machine:

   ```sh
   nixos-rebuild switch --flake .#hermes --target-host root@rrv.sh --build-host localhost
   ```

9. Verify:
    - root SSH access
    - `systemctl is-active nginx`
    - `systemctl is-active site`
    - `journalctl -u site`
    - `/var/lib/rrv-sh/content/.git`
    - real LFS assets
    - local `127.0.0.1:8080` root/static/assets
    - HTTPS root/static/assets
    - public listeners are `22`, `80`, and `443` only

## Final migration run

- Vultr was reinstalled with cloud-init user data:

  ```sh
  #!/bin/sh
  curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-24.05 bash
  ```

- Reset local SSH known-host keys for `rrv.sh` and `45.32.116.84` after reinstall.
- Confirmed SSH came up on infected NixOS 24.05:
  - kernel `6.6.68`
  - system `/nix/store/w7wab49igqi719fr0yibzfay72062fpg-nixos-system-hermes-24.05.7376.b134951a4c9f`
- Rebooted the infected 24.05 system and confirmed it came back cleanly.
- First flake switch attempt exposed two lessons:
  - `nixos-rebuild --build-host localhost` tries SSH to local `localhost`; manual `nix build`, `nix copy --no-check-sigs --to ssh-ng://root@rrv.sh`, and remote `switch-to-configuration` worked.
  - remote Nix rejected unsigned local store paths unless copied with `--no-check-sigs`.
- Initial flake switch failed bootloader install because our config did not set `boot.loader.efi.efiSysMountPoint`; GRUB tried to install into `/boot` instead of `/boot/efi`.
- Updated Hermes config for the reinstalled disk UUIDs and explicit EFI mount point:
  - `/`: `cb9f37af-53d2-4510-b513-a8f8c2486445`
  - `/boot/efi`: `D7A0-0D7E`
  - `boot.loader.efi.efiSysMountPoint = "/boot/efi"`
- Switched successfully to flake-built NixOS 26.05.
- Created `/swapfile` manually because the fresh reinstall did not have one and the flake config expects it.
- Rebooted after flake switch; host came back on NixOS 26.05.
- Disabled systemd-resolved LLMNR after verification showed public TCP `5355`; later review simplified networking back to default DHCP/dhcpcd, removing systemd-resolved from the final host.
- Review cleanup inlined the rrv.sh config into `hermes`, removed the separate `rrv-sh` module, removed unnecessary websocket/header nginx config, added an unprivileged `site` user, and kept GRUB removable EFI with explanatory comments.
- Removed tmpfiles ownership fix after doing the one-time remote ownership migration manually with `chown -R site:site /var/lib/rrv-sh`.
- Rebuilt, switched, and rebooted again after the review cleanup; host came back on final flake-built system.

## Final verification

- `systemctl is-active nginx`: active.
- `systemctl is-active site`: active.
- `systemctl --failed --no-legend`: no failed units.
- `/var/lib/rrv-sh/content/.git` exists.
- Content rev: `e353baa6ccfd353aa32b93929381d8c465845111`.
- LFS asset check: `/var/lib/rrv-sh/content/assets/cv.pdf` is 85K and begins with PDF magic bytes `%PDF-1.4`.
- Local app checks:
  - `http://127.0.0.1:8080/`: HTTP 200, 6377 bytes.
  - `http://127.0.0.1:8080/static/styles.css`: HTTP 200, 1039 bytes.
  - `http://127.0.0.1:8080/assets/cv.pdf`: HTTP 200, 86560 bytes.
- Public checks:
  - `http://rrv.sh/`: HTTP 301 to `https://rrv.sh/`.
  - `https://rrv.sh/`: HTTP/2 200, 6377 bytes.
  - `https://rrv.sh/static/styles.css`: HTTP/2 200, 1039 bytes.
  - `https://rrv.sh/assets/cv.pdf`: HTTP/2 200, 86560 bytes.
- Final reboot after review cleanup came back on `/nix/store/pv6agn1xqsybhhazc8hcf74b0dnvickd-nixos-system-hermes-26.05.20260523.2991645`.
- `site.service` runs as `site:site`.
- `/var/lib/rrv-sh` is owned by `site:site` after one-time manual migration.
- Listener check after final reboot:
  - public TCP: `22`, `80`, `443`
  - local-only TCP: `127.0.0.1:8080`

## Network fallback

A systemd-networkd fallback was tested in the flake during recovery, but the final config intentionally uses default NixOS DHCP/dhcpcd because the current Vultr image boots and networks correctly with defaults. If provider DHCP behavior changes, reintroduce explicit networkd matching MAC `56:00:06:13:a0:46` with DHCP IPv4 and IPv6 link-local.
