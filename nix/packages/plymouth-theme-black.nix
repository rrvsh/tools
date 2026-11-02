{
  perSystem =
    { pkgs, ... }:
    {
      packages = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        plymouth-theme-black = pkgs.runCommand "plymouth-theme-black" { } ''
          theme="$out/share/plymouth/themes/black"
          mkdir -p "$theme"

          cat > "$theme/black.plymouth" <<EOF
          [Plymouth Theme]
          Name=Black
          Description=Pure black Plymouth splash
          ModuleName=script

          [script]
          ImageDir=$out/share/plymouth/themes/black
          ScriptFile=$out/share/plymouth/themes/black/black.script
          EOF

          cat > "$theme/black.script" <<'EOF'
          Window.SetBackgroundTopColor (0, 0, 0);
          Window.SetBackgroundBottomColor (0, 0, 0);
          EOF
        '';
      };
    };
}
