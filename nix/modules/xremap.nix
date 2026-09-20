{
  config.flake.modules.nixos.xremap =
    { pkgs, primaryUser, ... }:
    {
      environment.systemPackages = [ pkgs.xremap.hyprland ];
      hardware.uinput.enable = true;
      users.users.${primaryUser.name}.extraGroups = [ "input" ];
      environment.etc."xremap/firefox.yml".text = ''
        keymap:
          - name: Firefox macOS shortcuts
            application:
              only: [firefox]
            exact_match: true
            remap:
              Super-c: Ctrl-c
              Super-v: Ctrl-v
              Super-t: Ctrl-t
              Super-w: Ctrl-w
              Super-Left: Home
              Super-Right: End
              Super-Shift-Left: Shift-Home
              Super-Shift-Right: Shift-End
      '';
    };
}
