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
      windowsDisk = "/dev/disk/by-id/nvme-CT2000P3SSD8_2325E6E6888E";
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
            <disk type="block" device="disk">
              <driver name="qemu" type="raw" cache="none"/>
              <source dev="${windowsDisk}"/>
              <target dev="sda" bus="sata"/>
              <boot order="1"/>
            </disk>
            <controller type="sata" index="0"/>
            <interface type="bridge">
              <mac address="52:54:00:18:f6:30"/>
              <source bridge="br0"/>
              <model type="e1000e"/>
            </interface>
            <graphics type="vnc" port="5900" autoport="no" listen="0.0.0.0">
              <listen type="address" address="0.0.0.0"/>
            </graphics>
            <video>
              <model type="vga" primary="yes"/>
            </video>
            <input type="tablet" bus="usb"/>
            <input type="keyboard" bus="ps2"/>
            <memballoon model="none"/>
          </devices>
        </domain>
      '';
      ownershipHook = pkgs.writeShellScript "zagreus-disk-ownership" ''
        if [[ "$1" != "zagreus" || "$2" != "prepare" || "$3" != "begin" ]]; then
          exit 0
        fi

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
    in
    {
      environment.sessionVariables.LIBVIRT_DEFAULT_URI = "qemu:///system";
      networking = {
        firewall.allowedTCPPorts = [ 5900 ];
        networkmanager = {
          settings.main.no-auto-default = "enp12s0";
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
      services.udev.extraRules = ''
        ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL_SHORT}=="2325E6E6888E", GROUP="qemu-libvirtd", MODE="0660"
      '';
      users.users.${primaryUser.name}.extraGroups = [ "libvirtd" ];

      virtualisation.libvirtd = {
        enable = true;
        onBoot = "ignore";
        onShutdown = "shutdown";
        qemu.runAsRoot = false;
        hooks.qemu.zagreus-disk-ownership = ownershipHook;
      };

      systemd.services = {
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
