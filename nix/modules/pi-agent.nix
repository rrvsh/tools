{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.flake;
  osModule = {
    home-manager.sharedModules = [ cfg.modules.homeManager.pi-agent ];
  };
in
{
  config.flake.modules = {
    darwin.pi-agent = osModule;
    nixos.pi-agent = osModule;
    homeManager.pi-agent =
      { pkgs, config, ... }:
      {
        programs.pi-coding-agent = {
          enable = true;
          package = inputs.nixpkgs-master.legacyPackages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent;
          extraPackages = [ pkgs.nodejs_22 ];
          settings.lastChangelogVersion = lib.getVersion config.programs.pi-coding-agent.package;
          settings.packages = [ "npm:pi-mcp-adapter" ];
          context = ''
            # Global pi instructions

            - If a command is missing, use comma: `, <command> [args...]`
            - For Python, run via comma: `, python3 ...`
            - Load and follow the global skill: `comma` (`~/.pi/agent/skills/comma/SKILL.md`)
            - For quick web search, prefer `ddgr` first (example: `ddgr -n 5 -x --np <query>`).
            - If `ddgr` is missing, use comma: `, ddgr -n 5 -x --np <query>`.
            - For scripted/API search, use Python via comma and prefer stdlib first (`urllib`, `json`, `re`, `xml.etree`).
            - Avoid assuming third-party Python deps (e.g., `requests`, `bs4`) are installed.
            - DuckDuckGo HTML may return bot challenges; if blocked, fall back to Bing RSS or site APIs.
            - Useful fallbacks:
              - Bing RSS: `https://www.bing.com/search?format=rss&q=...`
              - GitHub repo search API: `https://api.github.com/search/repositories?q=...`
            - To inspect flake inputs locally:
              - `nix flake metadata --json | jq '.locks.nodes | keys'`
              - `nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.<name>.outPath'`
          '';
        };
      };
  };
}
