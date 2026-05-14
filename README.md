# tools
caa 10032026

these are the tools i currently use :3

## notes

- `__curPos.file` will give the full evaluated path of the nix file it is called in. See [this issue](https://github.com/NixOS/nix/issues/5897#issuecomment-1012165198) for more information.
- to get home-manager logs on darwin, use `darwin-rebuild` instead of `nh`

## nemesis midnight shutdown

- hypridle writes `idle`/`active` state to `/run/user/<uid>/hypridle-state` on nemesis.
- idle timeout is `60` seconds.
- `daily-midnight-poweroff` runs at `00:00` local time daily.
- at `00:00`, if state is not `idle`, service exits immediately.
- if state is `idle`, service sends a desktop notification that shutdown will happen in 1 minute.
- service waits 60 seconds, checks state again, and powers off immediately if still `idle`.
- service logs each step to journald (view with `journalctl -u daily-midnight-poweroff.service`).

### to kill Hyprland from an SSH session

pkill .Hyprland-wrapp

## acknowledgements

- [ornicar](https://github.com/ornicar/dotfiles), for being my inspiration to start using Nix, open source, and being a full fledged software engineer
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) for teaching me how to use NixOS, flakes, and home-manager: the best damn tutorial on the internet I've seen yet
- [NotAShelf](https://github.com/notashelf/nyx) for introducing me to the idea of monorepos and custom logic (read: over-engineering) for Nix flakes
- [drupol/infra](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/) for introducing the dendritic pattern to me, and [mightyiam](https://discourse.nixos.org/t/pattern-every-file-is-a-flake-parts-module/61271) for pioneering it.
- [Cross-compiling to ARM64 in GitHub Actions](https://thewagner.net/blog/2023/11/20/building-nix-packages-for-the-raspberry-pi-with-github-actions)

## production deployment automation (rrv.sh)

this repository deploys `rs/site` to production at `rrv.sh` by shipping a fully baked artifact
(binary + static assets + site-content) to `45.32.116.84`.

### 1) create github environment

1. open repository `rrvsh/tools` -> Settings -> Environments.
2. create environment named `production`.
3. add these environment secrets exactly:
   - `VPS_HOST` = `45.32.116.84`
   - `VPS_PORT` = `22`
   - `VPS_USER` = deploy user on VPS (example: `deploy`)
   - `VPS_SSH_KEY` = private key content for deploy key (full multiline key)
   - `VPS_KNOWN_HOSTS` = output of `ssh-keyscan -H 45.32.116.84`
4. optional: add required reviewers to gate production deploy runs.

### 2) provision deploy user and paths on vps

run these commands on the VPS as root:

```bash
useradd --create-home --shell /bin/bash deploy || true
install -d -m 755 -o deploy -g deploy /opt/site
install -d -m 755 -o deploy -g deploy /opt/site/releases
```

### 3) install deploy ssh key

1. generate keypair locally:

```bash
ssh-keygen -t ed25519 -C github-actions-deploy -f ./deploy_rrv_site
```

2. add the public key to `/home/deploy/.ssh/authorized_keys` on VPS:

```bash
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
cat ./deploy_rrv_site.pub >> /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys
```

3. put the private key (`./deploy_rrv_site`) into `production` secret `VPS_SSH_KEY`.

### 4) configure systemd service to use current symlink

create `/etc/systemd/system/site.service`:

```ini
[Unit]
Description=rrv.sh site
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=deploy
Group=deploy
Environment=HOST=0.0.0.0
Environment=PORT=8080
Environment=SITE_CONTENT_DIR=/opt/site/current/content
Environment=STATIC_DIR=/opt/site/current/static
ExecStart=/opt/site/current/bin/site
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

enable it:

```bash
systemctl daemon-reload
systemctl enable --now site
```

### 5) allow minimal sudo for service restart

create `/etc/sudoers.d/site-deploy`:

```sudoers
deploy ALL=(root) NOPASSWD: /bin/systemctl restart site, /bin/systemctl is-active site
```

validate:

```bash
visudo -cf /etc/sudoers.d/site-deploy
```

### 6) remove old cron-based deployment

1. disable and remove cronjob that pulls `rrvsh/site-content` and static/app updates.
2. ensure no remaining scripts overwrite `/opt/site/current`.
3. keep old scripts for one rollback window only, then delete.

### 7) add cross-repo dispatch from rrvsh/site-content

in `rrvsh/site-content`, add a workflow that dispatches to `rrvsh/tools` on push to default branch.
store a PAT in `rrvsh/site-content` secrets:
- `TOOLS_REPO_DISPATCH_TOKEN` with permission to call repository dispatch on `rrvsh/tools`.

workflow file for `rrvsh/site-content` should be:

```yaml
name: trigger tools deploy

on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  dispatch:
    runs-on: ubuntu-latest
    steps:
      - name: trigger repository dispatch in rrvsh/tools
        env:
          GH_TOKEN: ${{ secrets.TOOLS_REPO_DISPATCH_TOKEN }}
        run: |
          curl -L \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${GH_TOKEN}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            https://api.github.com/repos/rrvsh/tools/dispatches \
            -d '{"event_type":"site-content-updated"}'
```

### 8) first deploy and verification

1. trigger deploy workflow manually (`workflow_dispatch`) in `rrvsh/tools`.
2. verify on VPS:

```bash
systemctl status site --no-pager
readlink -f /opt/site/current
ls -la /opt/site/current
```

3. verify externally:
   - `curl -I https://rrv.sh`
   - open `https://rrv.sh` and confirm fresh content + static assets.

### 9) rollback procedure

to rollback to a previous release SHA:

```bash
ln -sfn /opt/site/releases/<previous_sha> /opt/site/current
systemctl restart site
systemctl is-active site
```
