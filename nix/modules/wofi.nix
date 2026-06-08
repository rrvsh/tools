{ config, ... }:
let
  cfg = config.flake;
  blackStroke = "-1px -1px 0 black, 1px -1px 0 black, -1px 1px 0 black, 1px 1px 0 black";
  whiteStroke = "-1px -1px 0 white, 1px -1px 0 white, -1px 1px 0 white, 1px 1px 0 white";
  arrowSvg =
    name: glyph: fill: stroke:
    builtins.toFile "wofi-expander-${name}-${fill}-${stroke}.svg" ''
      <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" text-rendering="geometricPrecision">
        <text x="32" y="47" text-anchor="middle" font-family="Monocraft" font-size="48" font-weight="500" fill="${fill}" stroke="${stroke}" stroke-width="4" paint-order="stroke fill">${glyph}</text>
      </svg>
    '';
  arrowRight = arrowSvg "right" "&gt;" "white" "black";
  arrowDown = arrowSvg "down" "v" "white" "black";
  arrowRightSelected = arrowSvg "right" "&gt;" "black" "white";
  arrowDownSelected = arrowSvg "down" "v" "black" "white";
in
{
  config.flake.modules = {
    nixos.wofi = {
      home-manager.sharedModules = [ cfg.modules.homeManager.wofi ];
    };
    homeManager.wofi = {
      programs.wofi = {
        enable = true;
        settings = {
          insensitive = true;
          prompt = "";
        };
        style = ''
          * {
            font-family: "Monocraft";
            font-size: 14px;
            font-weight: 500;
          }

          #window,
          #input,
          #inner-box,
          #scroll {
            background: transparent;
          }

          #window {
            color: white;
            text-shadow: ${blackStroke};
          }

          #input {
            background-image: none;
            border: none;
            border-radius: 9999px;
            box-shadow: none;
            color: white;
            margin: 0 0 6px 0;
            outline: none;
            padding: 4px 8px 4px 12px;
            text-shadow: ${blackStroke};
          }

          #entry {
            border-radius: 8px;
            margin: 2px 0;
            padding: 4px 8px;
          }

          #entry:selected {
            background: white;
          }

          #entry:selected,
          #entry:selected #text,
          #entry:selected label {
            color: black;
            text-shadow: ${whiteStroke};
          }

          expander arrow {
            -gtk-icon-source: url("${arrowRight}");
            min-height: 14px;
            min-width: 14px;
          }

          expander arrow:checked {
            -gtk-icon-source: url("${arrowDown}");
          }

          #entry:selected expander arrow {
            -gtk-icon-source: url("${arrowRightSelected}");
          }

          #entry:selected expander arrow:checked {
            -gtk-icon-source: url("${arrowDownSelected}");
          }

          #text {
            color: inherit;
            text-shadow: inherit;
          }
        '';
      };
    };
  };
}
