{
  config.flake.modules.nixos.windows-vm =
    {
      config,
      lib,
      pkgs,
      primaryUser,
      ...
    }:
    let
      # The boot entry name is shared by systemd-boot and the reboot helper so
      # the top bar cannot drift to a different firmware target.
      windowsBootName = "11-pro";
      windowsBootEntry = "windows_${windowsBootName}.conf";
      # The serial-based path remains stable when NVMe discovery order changes.
      windowsDisk = "/dev/disk/by-id/nvme-CT2000P3SSD8_2325E6E6888E";
      # Make the Windows driver bundle and standalone guest-agent installer
      # available without a mutable download. Keep the CD small by omitting the
      # package's duplicate per-version driver tree.
      virtioWinIso = pkgs.runCommand "virtio-win.iso" { nativeBuildInputs = [ pkgs.xorriso ]; } ''
        xorriso -as mkisofs -quiet -R -J -graft-points -o "$out" \
          virtio-win-guest-tools.exe=${pkgs.virtio-win}/virtio-win-guest-tools.exe \
          qemu-ga-x86_64.msi=${pkgs.virtio-win}/guest-agent/qemu-ga-x86_64.msi
      '';
      # RDP is the normal desktop path. VNC remains a firmware/recovery console.
      # Credentials stay interactive and never enter the Nix store.
      zagreusRdp = pkgs.writeShellApplication {
        name = "zagreus-rdp";
        runtimeInputs = [ pkgs.freerdp ];
        text = ''
          exec xfreerdp \
            /v:10.10.0.96 \
            /u:rafiq \
            /d:zagreus \
            /cert:ignore \
            /f \
            /scale:180 \
            /audio-mode:redirect \
            /sound:sys:pulse \
            "$@"
        '';
      };
      windowsDomain = pkgs.writeText "zagreus.xml" ''
        <domain type="kvm">
          <name>zagreus</name>
          <uuid>799a733f-d0ea-4f6f-aec4-76889cf6210c</uuid>
          <memory unit="GiB">8</memory>
          <currentMemory unit="GiB">8</currentMemory>
          <vcpu placement="static">4</vcpu>
          <os firmware="efi">
            <type arch="x86_64" machine="pc-q35-11.1">hvm</type>
            <bootmenu enable="yes" timeout="5000"/>
          </os>
          <features>
            <acpi/>
            <apic/>
            <hyperv mode="custom">
              <relaxed state="on"/>
              <vapic state="on"/>
              <spinlocks state="on" retries="8191"/>
            </hyperv>
          </features>
          <cpu mode="host-passthrough" check="none">
            <topology sockets="1" dies="1" cores="4" threads="1"/>
          </cpu>
          <clock offset="localtime">
            <timer name="rtc" tickpolicy="catchup"/>
            <timer name="pit" tickpolicy="delay"/>
            <timer name="hpet" present="no"/>
          </clock>
          <pm>
            <suspend-to-mem enabled="no"/>
            <suspend-to-disk enabled="no"/>
          </pm>
          <on_poweroff>destroy</on_poweroff>
          <on_reboot>restart</on_reboot>
          <on_crash>destroy</on_crash>
          <devices>
            <emulator>/run/libvirt/nix-emulators/qemu-system-x86_64</emulator>
            <!-- Windows owns the complete physical disk. Linux never mounts its NTFS filesystem. -->
            <disk type="block" device="disk">
              <driver name="qemu" type="raw" cache="none"/>
              <source dev="${windowsDisk}"/>
              <target dev="sda" bus="sata"/>
              <boot order="1"/>
            </disk>
            <disk type="file" device="cdrom">
              <driver name="qemu" type="raw"/>
              <source file="${virtioWinIso}"/>
              <target dev="sdb" bus="sata"/>
              <readonly/>
            </disk>
            <controller type="sata" index="0"/>
            <controller type="virtio-serial" index="0"/>
            <!-- e1000e boots with an in-box Windows driver; VirtIO networking can follow later. -->
            <interface type="bridge">
              <mac address="52:54:00:18:f6:30"/>
              <source bridge="br0"/>
              <model type="e1000e"/>
            </interface>
            <!-- VNC covers firmware, recovery and automation; RDP is the normal desktop. -->
            <graphics type="vnc" port="5900" autoport="no" listen="0.0.0.0">
              <listen type="address" address="0.0.0.0"/>
            </graphics>
            <video>
              <model type="vga" primary="yes"/>
            </video>
            <input type="tablet" bus="usb"/>
            <input type="keyboard" bus="ps2"/>
            <!-- The guest agent gives libvirt a UI-independent shutdown path. -->
            <channel type="unix">
              <target type="virtio" name="org.qemu.guest_agent.0"/>
            </channel>
            <!-- Pass only Bluetooth, not its shared PCIe USB controller. Linux regains it after shutdown. -->
            <hostdev mode="subsystem" type="usb" managed="yes">
              <source startupPolicy="optional">
                <vendor id="0x8087"/>
                <product id="0x0032"/>
              </source>
            </hostdev>
            <memballoon model="none"/>
          </devices>
        </domain>
      '';
      # Both VM startup and native reboot use the same block ownership checks.
      diskSafetyCheck = ''
        windows_device=$(${lib.getExe' pkgs.coreutils "readlink"} -f ${windowsDisk})
        if [[ -z "$windows_device" || ! -b "$windows_device" ]]; then
          echo "Windows disk is unavailable" >&2
          exit 1
        fi

        if ${lib.getExe' pkgs.util-linux "findmnt"} --noheadings --source "$windows_device" >/dev/null; then
          echo "Windows disk is mounted" >&2
          exit 1
        fi
        for partition in "$windows_device"p*; do
          if [[ -e "$partition" ]] && ${lib.getExe' pkgs.util-linux "findmnt"} --noheadings --source "$partition" >/dev/null; then
            echo "Windows partition $partition is mounted" >&2
            exit 1
          fi
        done

        if ${pkgs.findutils}/bin/find "/sys/class/block/$(${lib.getExe' pkgs.coreutils "basename"} "$windows_device")/holders" -mindepth 1 -maxdepth 1 | ${lib.getExe pkgs.gnugrep} -q .; then
          echo "Windows disk still has kernel holders" >&2
          exit 1
        fi
      '';
      ownershipHook = pkgs.writeShellScript "zagreus-disk-ownership" ''
        if [[ "$1" != "zagreus" || "$2" != "prepare" || "$3" != "begin" ]]; then
          exit 0
        fi
        ${diskSafetyCheck}
      '';
      # Only this immutable helper receives passwordless sudo. It refuses to
      # arm native boot until libvirt and the block layer both report safety.
      rebootToWindowsRoot = pkgs.writeShellApplication {
        name = "reboot-to-windows-root";
        runtimeInputs = [
          config.virtualisation.libvirtd.package
          pkgs.coreutils
          pkgs.findutils
          pkgs.glibc.bin
          pkgs.gnugrep
          pkgs.jq
          pkgs.procps
          pkgs.psmisc
          pkgs.systemd
          pkgs.util-linux
        ];
        text = ''
          mode="''${1:---reboot}"
          if [[ "$mode" != "--reboot" && "$mode" != "--check" && "$mode" != "--prepare-only" ]]; then
            echo "usage: reboot-to-windows-root [--reboot|--check|--prepare-only]" >&2
            exit 2
          fi

          exec 9>/run/reboot-to-windows.lock
          if ! flock --nonblock 9; then
            echo "Another Windows reboot request is already running" >&2
            exit 1
          fi

          state=$(virsh -c qemu:///system domstate zagreus 2>/dev/null || true)
          if [[ "$state" != "shut off" ]]; then
            echo "Shut down the zagreus VM first; current state: ''${state:-unknown}" >&2
            exit 1
          fi
          if pgrep --full -- 'qemu-system-x86_64 .*guest=zagreus' >/dev/null; then
            echo "The zagreus QEMU process is still running" >&2
            exit 1
          fi

          ${diskSafetyCheck}
          devices=("$windows_device")
          for partition in "$windows_device"p*; do
            [[ -e "$partition" ]] && devices+=("$partition")
          done
          if fuser --silent "''${devices[@]}"; then
            echo "A process still has the Windows disk open" >&2
            exit 1
          fi

          if ! bootctl --variables=yes list --json=short | jq --exit-status --arg entry ${lib.escapeShellArg windowsBootEntry} 'any(.[]; .id == $entry)' >/dev/null; then
            echo "Windows boot entry ${windowsBootEntry} is unavailable" >&2
            exit 1
          fi

          if [[ "$mode" == "--check" ]]; then
            echo "Ready to reboot into Windows 11 Pro"
            exit 0
          fi

          read_oneshot() {
            for variable in /sys/firmware/efi/efivars/LoaderEntryOneShot-*; do
              [[ -e "$variable" ]] || continue
              dd if="$variable" bs=1 skip=4 status=none | iconv -f UTF-16LE -t UTF-8 | tr -d '\0'
              return
            done
          }
          clear_oneshot() {
            bootctl --variables=yes set-oneshot ""
          }

          bootctl --variables=yes set-oneshot ${lib.escapeShellArg windowsBootEntry}
          actual=$(read_oneshot)
          if [[ "$actual" != ${lib.escapeShellArg windowsBootEntry} ]]; then
            clear_oneshot
            echo "Could not verify the Windows one-shot boot entry" >&2
            exit 1
          fi

          if [[ "$mode" == "--prepare-only" ]]; then
            clear_oneshot
            if [[ -n "$(read_oneshot)" ]]; then
              echo "Could not clear the Windows one-shot boot entry" >&2
              exit 1
            fi
            echo "Set, verified and cleared the Windows one-shot boot entry"
            exit 0
          fi

          sync
          if ! systemctl reboot; then
            clear_oneshot
            echo "Reboot failed; cleared the Windows one-shot boot entry" >&2
            exit 1
          fi
        '';
      };
      # The user-facing wrapper turns safety failures into a desktop
      # notification while keeping EFI and reboot operations inside sudo.
      rebootToWindows = pkgs.writeShellApplication {
        name = "reboot-to-windows";
        runtimeInputs = [ pkgs.libnotify ];
        text = ''
          mode="''${1:---reboot}"
          if ! output=$(/run/wrappers/bin/sudo ${lib.getExe rebootToWindowsRoot} "$mode" 2>&1); then
            notify-send --urgency=critical "Cannot reboot to Windows" "$output"
            printf '%s\n' "$output" >&2
            exit 1
          fi
          [[ -n "$output" ]] && printf '%s\n' "$output"
        '';
      };
    in
    {
      boot.loader.systemd-boot.windows.${windowsBootName} = {
        title = "Windows 11 Pro";
        efiDeviceHandle = "HD0d";
      };
      environment = {
        sessionVariables.LIBVIRT_DEFAULT_URI = "qemu:///system";
        systemPackages = [
          pkgs.cifs-utils
          rebootToWindows
          zagreusRdp
        ];
      };
      networking = {
        firewall.allowedTCPPorts = [ 5900 ];
        networkmanager = {
          settings.main.no-auto-default = "enp12s0";
          # The host keeps its existing MAC and DHCP identity on the bridge;
          # enp12s0 becomes a Layer 2 port shared with the VM tap device.
          ensureProfiles.profiles = {
            lan-bridge = {
              connection = {
                id = "lan-bridge";
                uuid = "90f94c60-a8ea-49c4-8867-12b7ec620f77";
                type = "bridge";
                interface-name = "br0";
                autoconnect = true;
                autoconnect-priority = 100;
              };
              bridge = {
                stp = false;
                mac-address = "74:56:3C:35:AB:E5";
              };
              ipv4.method = "auto";
              ipv6 = {
                method = "auto";
                addr-gen-mode = "stable-privacy";
              };
            };
            lan-bridge-port = {
              connection = {
                id = "lan-bridge-port";
                uuid = "19af3f2e-63f4-47ff-a4a7-91eb30648b22";
                type = "ethernet";
                interface-name = "enp12s0";
                autoconnect = true;
                controller = "br0";
                port-type = "bridge";
              };
              ethernet.mac-address = "74:56:3C:35:AB:E5";
            };
          };
        };
      };
      # QEMU is deliberately unprivileged. Grant only its service group access
      # to the dedicated Windows disk instead of running the whole VM as root.
      services.udev.extraRules = ''
        ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL_SHORT}=="2325E6E6888E", GROUP="qemu-libvirtd", MODE="0660"
      '';
      security.sudo.extraRules = [
        {
          users = [ primaryUser.name ];
          commands = [
            {
              command = lib.getExe rebootToWindowsRoot;
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
      users.users.${primaryUser.name}.extraGroups = [ "libvirtd" ];

      virtualisation.libvirtd = {
        enable = true;
        onBoot = "ignore";
        onShutdown = "shutdown";
        qemu.runAsRoot = false;
        # The hook runs for every libvirt start path and rejects concurrent
        # Linux ownership before QEMU is allowed to open the physical disk.
        hooks.qemu.zagreus-disk-ownership = ownershipHook;
      };

      systemd.services = {
        # Keep the XML declarative while leaving VM start/stop under explicit
        # user control. Redefining an active domain only changes its next boot.
        windows-vm-define = {
          description = "Define the zagreus Windows VM";
          wantedBy = [ "multi-user.target" ];
          requires = [
            "libvirtd-config.service"
            "libvirtd.service"
          ];
          after = [
            "libvirtd-config.service"
            "libvirtd.service"
          ];
          path = [
            config.virtualisation.libvirtd.package
            pkgs.coreutils
            pkgs.gawk
            pkgs.gnugrep
          ];
          script = ''
            virt-xml-validate ${windowsDomain}
            virsh -c qemu:///system define ${windowsDomain}
          '';
          serviceConfig.Type = "oneshot";
        };
      };
    };
}
