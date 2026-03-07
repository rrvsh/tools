# GHA CI Setup for NixOS/Darwin Deployments via Tailscale

**Date:** 2026-03-07  
**Task:** Set up GitHub Actions CI to test and deploy NixOS (nemesis) and Darwin (alpha) configurations via Tailscale SSH

## Summary

Created two GitHub Actions workflows to automate testing and deployment of NixOS and Darwin configurations:

1. **`test-deploy.yaml`** - Runs on every push to `main`, tests rebuilds without switching
2. **`deploy.yaml`** - Manual dispatch workflow that actually switches configurations on hosts

## Architecture

### Hosts
- **nemesis**: NixOS host (x86_64-linux)
- **alpha**: Darwin/macOS host (aarch64-darwin)

Both hosts have:
- Tailscale enabled (`services.tailscale.enable = true`)
- SSH enabled with key-based authentication
- OpenSSH configured to disallow password auth

### Workflow Flow

```
Push to main
    │
    ▼
test-deploy.yaml (automatic)
    ├── Connect to Tailscale
    ├── SSH to nemesis
    │   └── nixos-rebuild dry-build --flake .#nemesis
    └── SSH to alpha
        └── darwin-rebuild check --flake .#alpha

Manual trigger (workflow_dispatch)
    │
    ▼
deploy.yaml
    ├── (optional) Run test-deploy.yaml first
    ├── Connect to Tailscale
    ├── SSH to nemesis
    │   └── nixos-rebuild switch --flake .#nemesis
    └── SSH to alpha
        └── darwin-rebuild switch --flake .#alpha
```

## Required Secrets

The following secrets need to be configured in GitHub:

| Secret | Description |
|--------|-------------|
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client ID |
| `TS_OAUTH_SECRET` | Tailscale OAuth client secret |
| `NEMESIS_SSH_PRIVATE_KEY` | SSH private key for rafiq@nemesis |
| `ALPHA_SH_PRIVATE_KEY` | SSH private key for rafiq@alpha |

### Tailscale OAuth Setup

1. Go to Tailscale admin console → Settings → OAuth clients
2. Create OAuth client with scope: `auth_keys` (write)
3. Tag the OAuth client with at least one tag (e.g., `tag:ci`)
4. Ensure ACLs allow the `tag:ci` nodes to access `tag:nixos` and `tag:darwin` hosts via SSH

### SSH Key Setup

```bash
# Generate SSH key pair (if not already exists)
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy

# Add public key to nemesis authorized_keys
cat ~/.ssh/github_actions_deploy.pub | ssh rafiq@nemesis 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'

# Add public key to alpha authorized_keys
cat ~/.ssh/github_actions_deploy.pub | ssh rafiq@alpha 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'

# Add private key to GitHub secrets as NEMESIS_SSH_PRIVATE_KEY and ALPHA_SSH_PRIVATE_KEY
cat ~/.ssh/github_actions_deploy
```

## Key Design Decisions

### Why `dry-build` and `check` for testing?

- **NixOS (`nixos-rebuild dry-build`)**: Builds the configuration but doesn't apply it. This validates the configuration compiles and all dependencies are available without affecting the running system.

- **Darwin (`darwin-rebuild check`)**: Validates the configuration without applying changes. This is safer than `switch` for CI testing.

### Why copy the flake to the host?

Instead of running `nixos-rebuild` from the GitHub runner (which would require Nix and building for foreign architectures), we:
1. Copy the repository to `/tmp/deploy-flake` on the target host
2. Run the rebuild command locally on the host

This approach:
- Avoids cross-compilation issues
- Uses the host's Nix store and binary cache
- Is faster since the host already has most dependencies

### Security Considerations

1. **Tailscale Ephemeral Nodes**: The GitHub Action creates ephemeral nodes that are automatically removed after the workflow completes
2. **SSH Key Security**: Private keys are stored as GitHub secrets and only exist in memory during workflow execution
3. **StrictHostKeyChecking**: Uses `accept-new` to prevent MITM attacks while allowing first-time connections
4. **OAuth Scoped**: OAuth client only has `auth_keys` scope, limiting blast radius

### Concurrency Controls

- `test-deploy.yaml`: Cancels in-progress runs on new pushes (`cancel-in-progress: true`)
- `deploy.yaml`: Does NOT cancel in-progress deployments (`cancel-in-progress: false`) to prevent partial deployment states

## Testing

### Local Testing

To test the workflows locally before pushing:

```bash
# Validate workflow syntax
act -j test-nemesis --dryrun

# Run with zizmor for security audit
nix develop -c zizmor .github/workflows/test-deploy.yaml
nix develop -c zizmor .github/workflows/deploy.yaml
```

### Security Audit Notes

zizmor reports informational template injection warnings for `needs.*.result` expressions. These are safe because:
1. Job results are controlled by GitHub Actions, not user input
2. The values are limited to: `success`, `failure`, `cancelled`, `skipped`
3. No user-controllable data flows into these expressions

## Future Improvements

Potential enhancements to consider:

1. **Rollback capability**: Add a rollback job that can revert to previous generation on failure
2. **Health checks**: Add post-deployment health checks to verify services are running
3. **Notifications**: Add Slack/Discord notifications for deployment status
4. **Build caching**: Use Cachix or similar to speed up builds
5. **Remote builders**: Configure remote builders for faster NixOS builds
6. **Matrix strategy**: Use matrix builds if adding more hosts

## Files Created

- `.github/workflows/test-deploy.yaml` - Automated testing on push to main
- `.github/workflows/deploy.yaml` - Manual deployment workflow
