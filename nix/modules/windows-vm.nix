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
      windowsOwnershipState = "/run/zagreus-windows-disk.state";
      windowsOwnershipLock = "/run/zagreus-windows-disk.lock";
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
            <!-- The ownership hook unmounts NTFS before QEMU opens the complete physical disk. -->
            <disk type="block" device="disk">
              <driver name="qemu" type="raw" cache="none"/>
              <source dev="${windowsDisk}"/>
              <target dev="sda" bus="sata"/>
              <boot order="1"/>
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
      windowsDiskControl = pkgs.writeShellApplication {
        name = "zagreus-disk-control";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.procps
          pkgs.psmisc
          pkgs.systemd
          pkgs.util-linux
        ];
        text = ''
          mode="''${1:-}"
          exec 9>${lib.escapeShellArg windowsOwnershipLock}
          flock 9

          restore_linux_ownership() {
            rm -f ${lib.escapeShellArg windowsOwnershipState}
            system_state=$(systemctl is-system-running 2>/dev/null || true)
            if [[ "$system_state" == "stopping" || "$system_state" == "offline" ]]; then
              return
            fi
            systemctl start mnt-windows.automount
            systemctl start samba-smbd.service
          }

          case "$mode" in
            claim)
              if [[ -e ${lib.escapeShellArg windowsOwnershipState} ]]; then
                echo "Windows disk is already reserved for zagreus" >&2
                exit 1
              fi
              printf 'reserved for zagreus\n' >${lib.escapeShellArg windowsOwnershipState}
              chmod 0600 ${lib.escapeShellArg windowsOwnershipState}
              rollback() {
                status=$?
                trap - EXIT
                restore_linux_ownership || true
                exit "$status"
              }
              trap rollback EXIT

              systemctl stop samba-smbd.service
              systemctl stop mnt-windows.automount
              systemctl stop mnt-windows.mount
              ${diskSafetyCheck}
              devices=("$windows_device")
              for partition in "$windows_device"p*; do
                [[ -e "$partition" ]] && devices+=("$partition")
              done
              if fuser --silent "''${devices[@]}"; then
                echo "A process still has the Windows disk open" >&2
                exit 1
              fi

              trap - EXIT
              ;;
            release)
              if pgrep --full -- 'qemu-system-x86_64 .*guest=zagreus' >/dev/null; then
                echo "The zagreus QEMU process is still running" >&2
                exit 1
              fi
              ${diskSafetyCheck}
              restore_linux_ownership
              ;;
            status)
              if [[ -e ${lib.escapeShellArg windowsOwnershipState} ]]; then
                echo "Windows disk is reserved for zagreus"
              else
                echo "Windows disk is available to Linux"
              fi
              ;;
            *)
              echo "usage: zagreus-disk-control {claim|release|status}" >&2
              exit 2
              ;;
          esac
        '';
      };
      ownershipHook = pkgs.writeShellScript "zagreus-disk-ownership" ''
        if [[ "$1" != "zagreus" ]]; then
          exit 0
        fi
        if [[ "$2" == "prepare" && "$3" == "begin" ]]; then
          exec ${lib.getExe windowsDiskControl} claim
        fi
        if [[ "$2" == "release" && "$3" == "end" ]]; then
          case "$4" in
            shutdown|failed)
              exec ${lib.getExe windowsDiskControl} release
              ;;
            *)
              echo "Keeping the Windows disk blocked after zagreus stopped: $4" >&2
              ;;
          esac
        fi
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
          if [[ "$mode" != "--reboot" && "$mode" != "--check" && "$mode" != "--prepare-only" && "$mode" != "--restore-linux" ]]; then
            echo "usage: reboot-to-windows-root [--reboot|--check|--prepare-only|--restore-linux]" >&2
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

          if [[ "$mode" == "--restore-linux" ]]; then
            ${lib.getExe windowsDiskControl} release
            echo "Restored the Windows mount and Samba share"
            exit 0
          fi

          if ! bootctl --variables=yes list --json=short | jq --exit-status --arg entry ${lib.escapeShellArg windowsBootEntry} 'any(.[]; .id == $entry)' >/dev/null; then
            echo "Windows boot entry ${windowsBootEntry} is unavailable" >&2
            exit 1
          fi

          if [[ "$mode" == "--check" ]]; then
            echo "Windows boot entry is available; disk access will be checked before reboot"
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
          rollback() {
            status=$?
            trap - EXIT
            clear_oneshot || true
            ${lib.getExe windowsDiskControl} release || true
            exit "$status"
          }

          ${lib.getExe windowsDiskControl} claim
          trap rollback EXIT
          bootctl --variables=yes set-oneshot ${lib.escapeShellArg windowsBootEntry}
          actual=$(read_oneshot)
          if [[ "$actual" != ${lib.escapeShellArg windowsBootEntry} ]]; then
            echo "Could not verify the Windows one-shot boot entry" >&2
            exit 1
          fi

          if [[ "$mode" == "--prepare-only" ]]; then
            clear_oneshot
            if [[ -n "$(read_oneshot)" ]]; then
              echo "Could not clear the Windows one-shot boot entry" >&2
              exit 1
            fi
            ${lib.getExe windowsDiskControl} release
            trap - EXIT
            echo "Set, verified and cleared the Windows one-shot boot entry"
            exit 0
          fi

          sync
          trap - EXIT
          if ! systemctl reboot; then
            clear_oneshot
            ${lib.getExe windowsDiskControl} release
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
          error_title="Cannot reboot to Windows"
          [[ "$mode" == "--restore-linux" ]] && error_title="Cannot restore the Windows disk to Linux"
          if ! output=$(/run/wrappers/bin/sudo ${lib.getExe rebootToWindowsRoot} "$mode" 2>&1); then
            notify-send --urgency=critical "$error_title" "$output"
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
        etc = {
          "systemd/system/mnt-windows.mount.d/zagreus-ownership.conf".text = ''
            [Unit]
            ConditionPathExists=!${windowsOwnershipState}
          '';
          "systemd/system/mnt-windows.automount.d/zagreus-ownership.conf".text = ''
            [Unit]
            ConditionPathExists=!${windowsOwnershipState}
          '';
          "systemd/system/samba-smbd.service.d/zagreus-ownership.conf".text = ''
            [Unit]
            ConditionPathExists=!${windowsOwnershipState}
          '';
        };
        sessionVariables.LIBVIRT_DEFAULT_URI = "qemu:///system";
        systemPackages = [
          rebootToWindows
          zagreusRdp
        ];
      };
      networking.firewall.allowedTCPPorts = [ 5900 ];
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
