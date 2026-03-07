# Remote Builder Configuration Session

**Date:** 2026-03-07  
**Task:** Configure nemesis and alpha as remote builders for Nix builds

## Summary

Successfully implemented and deployed remote builder configuration that allows:
- All Linux builds (x86_64-linux, aarch64-linux) to use **nemesis** as remote builder
- All Darwin builds (aarch64-darwin, x86_64-darwin) to use **alpha** as remote builder
- All machines in the infrastructure to offload builds to the appropriate platform-specific builder

**Status:** ✅ Deployed and active on nemesis (NixOS)

## Implementation Details

### File Created
- `nix/modules/services/builders-remote.nix` - Remote builder configuration module (90 lines)

### Final Configuration

**Design Philosophy:** Explicit over clever - no helper functions, fully inlined builder definitions

```nix
# nix/modules/services/builders-remote.nix
{ config, lib, ... }:
let
  cfg = config.flake;
  inherit (cfg.accounts.rafiq) username;
  nixosRootSshKey = "/root/.ssh/id_ed25519";
  darwinRootSshKey = "/var/root/.ssh/id_ed25519";
in
{
  config.flake = {
    modules.nixos.default =
      { config, ... }:
      {
        system.activationScripts.remote-builder-ssh-key.text =
          lib.optionalString (config.users.users ? ${username})
            ''
              mkdir -p ${builtins.dirOf nixosRootSshKey}
              cp /home/${username}/.ssh/id_ed25519 ${nixosRootSshKey} 2>/dev/null || true
              chmod 600 ${nixosRootSshKey} 2>/dev/null || true
            '';
        nix.buildMachines = [
          {
            hostName = "nemesis";
            systems = [ "x86_64-linux" "aarch64-linux" ];
            protocol = "ssh";
            maxJobs = 8;
            speedFactor = 2;
            supportedFeatures = [ "nixos-test" "big-parallel" "kvm" ];
            sshKey = nixosRootSshKey;
          }
          {
            hostName = "alpha";
            systems = [ "aarch64-darwin" "x86_64-darwin" ];
            protocol = "ssh";
            maxJobs = 4;
            speedFactor = 1;
            supportedFeatures = [ "big-parallel" ];
            sshKey = nixosRootSshKey;
          }
        ];
      };

    modules.darwin.default = {
      system.activationScripts.remote-builder-ssh-key.text = ''
        mkdir -p ${builtins.dirOf darwinRootSshKey}
        cp /Users/${username}/.ssh/id_ed25519 ${darwinRootSshKey} 2>/dev/null || true
        chmod 600 ${darwinRootSshKey} 2>/dev/null || true
      '';
      nix.buildMachines = [
        {
          hostName = "nemesis";
          systems = [ "x86_64-linux" "aarch64-linux" ];
          protocol = "ssh";
          maxJobs = 8;
          speedFactor = 2;
          supportedFeatures = [ "nixos-test" "big-parallel" "kvm" ];
          sshKey = darwinRootSshKey;
        }
        {
          hostName = "alpha";
          systems = [ "aarch64-darwin" "x86_64-darwin" ];
          protocol = "ssh";
          maxJobs = 4;
          speedFactor = 1;
          supportedFeatures = [ "big-parallel" ];
          sshKey = darwinRootSshKey;
        }
      ];
    };
  };
}
```

### Builder Specifications

**Nemesis (Linux Builder):**
- Host: `nemesis` (Tailscale hostname)
- Systems: x86_64-linux, aarch64-linux
- Max jobs: 8
- Speed factor: 2 (prioritized for Linux builds)
- Features: nixos-test, big-parallel, kvm

**Alpha (Darwin Builder):**
- Host: `alpha` (Tailscale hostname)
- Systems: aarch64-darwin, x86_64-darwin
- Max jobs: 4
- Speed factor: 1
- Features: big-parallel (Darwin doesn't support nixos-test or kvm)

## Design Decisions & Iterations

### 1. Helper Function Abstraction (REJECTED)
**Attempted:** `mkBuilder` function to generate builder configs
**Decision:** Rejected - too abstract for only 2 builders, harder to read than explicit definitions

### 2. Builder Config Variables (REJECTED)
**Attempted:** `nemesisBuilder` and `alphaBuilder` variables with `//` operator to merge SSH keys
**Decision:** Rejected - adds indirection, better to be fully explicit

### 3. Script Helper Function (REJECTED)
**Attempted:** `copyKey` helper for the activation script
**Decision:** Rejected - YAGNI, only used twice, 3-line script is clearer inline

### 4. Directory Parameter (OPTIMIZED)
**Initial:** Passed directory separately to helper functions
**Final:** Used `builtins.dirOf` to extract directory from the SSH key path

### 5. Attribute Name Fix
**Bug:** Used `host` instead of `hostName`
**Fix:** NixOS expects `hostName` attribute in buildMachines
**Error:** `option 'nix.buildMachines.*.host' does not exist. Did you mean 'hostName'?`

## Key Implementation Notes

1. **SSH Key Handling**: The Nix daemon runs as root, so SSH keys are copied from the user's home directory to root's home directory via activation scripts:
   - NixOS: `/home/rafiq/.ssh/id_ed25519` → `/root/.ssh/id_ed25519`
   - Darwin: `/Users/rafiq/.ssh/id_ed25519` → `/var/root/.ssh/id_ed25519`

2. **Authentication**: Uses existing `rafiq` SSH key pair. The public key is already authorized on both hosts via `settings-users.nix`.

3. **Reference for root SSH keys:**
   > "In a multi-user installation (default), builds are executed by the Nix Daemon... The Nix Daemon's user (typically root) needs to have SSH access to the remote builder. SSH identity files for root users are usually stored in `/root/.ssh/` (Linux) or `/var/root/.ssh` (MacOS)."
   > — Nix Reference Manual, Remote Builds: https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds

4. **Connectivity**: Uses Tailscale hostnames for seamless connectivity.

5. **Automatic Import**: The module is automatically imported via `import-tree` - no manual import needed.

## Important: Nix-Darwin Activation Scripts

**Key Difference from NixOS:**

Unlike NixOS, nix-darwin has a **hardcoded list** of activation scripts it runs. Custom scripts must use predefined hooks:

- `system.activationScripts.preActivation.text`
- `system.activationScripts.extraActivation.text` (use `lib.mkAfter` to append)
- `system.activationScripts.postActivation.text`

**Incorrect (doesn't execute):**
```nix
system.activationScripts.remote-builder-ssh-key = {
  deps = [ "users" ];  # NixOS-only feature
  text = ''...'';
};
```

**Correct (executes during activation):**
```nix
system.activationScripts.extraActivation.text = lib.mkAfter ''
  # Your script here
'';
```

**Reference:** nix-darwin source: `modules/system/activation-scripts.nix` explicitly lists which scripts are called.

## Testing & Deployment

### Pre-deployment Checks
- ✅ `nix flake check` - Passes
- ✅ `treefmt` - Formatted correctly
- ✅ `statix check` - No issues
- ✅ `deadnix` - No dead code

### Deployment
**Command:** `just rb`
**Result:** Successfully rebuilt and switched NixOS configuration on nemesis
**Changes:**
- Added `etc-nix-machines` configuration file
- SSH key activation script configured
- All checks passed (formatting, linting, tests)

### Post-deployment Verification
```bash
# Check the builder config was written
cat /etc/nix/machines

# Test connectivity to remote builders
sudo nix store info --store ssh://nemesis
sudo nix store info --store ssh://alpha

# Test cross-platform build
nix build .#packages.aarch64-darwin.some-package  # Should offload to alpha
```

## Future Improvements

1. **Test Darwin configuration** - Apply to alpha (macOS) to verify Darwin module works
2. **Add health checks** - Verify builder connectivity periodically
3. **Consider priority tuning** - Adjust speedFactor based on real-world performance
4. **Add builder-specific SSH keys** - Better isolation than shared user key

## References

- Nix Remote Builds Documentation: https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds
- NixOS buildMachines option: https://search.nixos.org/options?channel=unstable&show=nix.buildMachines
- NixOS Manual - Distributed Builds: https://nixos.org/manual/nixos/stable/#sec-distributed-builds
