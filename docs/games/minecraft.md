# Prism Launcher GTNH display crash

Symptom:

```text
java.lang.IllegalStateException: Failed to create Display window
OpenGL: no valid GL context
OpenGL renderer: llvmpipe
```

Likely cause on NVIDIA: driver/library mismatch after rebuild or update without reboot.

Check:

```sh
nvidia-smi
cat /proc/driver/nvidia/version
modinfo nvidia | rg '^version:'
```

Bad output:

```text
Failed to initialize NVML: Driver/library version mismatch
NVML library version: <newer-version>
NVRM version: NVIDIA UNIX x86_64 Kernel Module <older-version>
```

Fix:

```sh
sudo reboot
```

After reboot, `nvidia-smi` should print GPU and driver info without NVML mismatch.
