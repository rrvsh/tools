{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.flake;
  osModule = {
    nix.settings = {
      extra-substituters = [ "https://pi.cachix.org" ];
      extra-trusted-public-keys = [ "pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk=" ];
    };
    home-manager.sharedModules = [ cfg.modules.homeManager.pi-agent ];
  };
in
{
  config.flake.modules = {
    darwin.pi-agent = osModule;
    nixos.pi-agent = osModule;
    homeManager.pi-agent =
      { pkgs, config, ... }:
      let
        system = pkgs.stdenv.hostPlatform.system;
        agentBrowser = inputs.agent-browser.packages.${system}.agent-browser;
        agentBrowserStatePath = "${config.home.homeDirectory}/.agent-browser/state/agent.json";
      in
      {
        home.packages = [ agentBrowser ];
        programs.pi-coding-agent = {
          enable = true;
          package = inputs.pi.packages.${system}.pi-coding-agent;
          extraPackages = [
            pkgs.nodejs_22
            agentBrowser
          ];
          settings.lastChangelogVersion = lib.getVersion config.programs.pi-coding-agent.package;
          settings.packages = [
            # Keep this pinned with the agent-browser flake input: pi-agent-browser-native
            # tracks specific agent-browser CLI versions in its command surface and result parsing.
            "npm:pi-agent-browser-native@0.2.64"
            "npm:pi-mcp-adapter"
            "npm:pi-subagents"
            "npm:pi-web-access"
          ];
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
            - Agent browser:
              - `agent-browser` is installed in the user shell and on Pi's wrapped runtime `PATH`.
              - On a fresh machine after rebuilding this config, run `agent-browser install` once to download the agent-owned Chrome.
              - Use the native `agent_browser` tool for browser automation; do not drive `agent-browser` through bash from Pi.
              - Auth-walled and account-specific sites, especially LinkedIn, must use `agent_browser` with the shared auth state before declaring an auth wall or login problem. Do not use `ddgr`, `web_search`, `fetch_content`, `curl`, or bash to read LinkedIn page content.
              - Use one shared auth state file for all sites: `${agentBrowserStatePath}`. Do not create per-service restore buckets such as `--restore=linkedin` unless explicitly asked.
              - Normal authenticated browsing is headless and state-backed. Launch fresh with the shared state file, e.g. `args`: `["--state", "${agentBrowserStatePath}", "open", "https://www.linkedin.com/feed/"]`, `sessionMode`: `"fresh"`. Use the same pattern for LinkedIn profiles, posts, search, and jobs by replacing the URL.
              - After a state-backed open, inspect with `snapshot -i`, `get`, or `eval --stdin`. If the page still shows a login form or password field, ask the user whether to refresh the shared login; do not stop at "auth wall".
              - Do not use `--headed` for normal browsing. Use `--headed` only for initial auth setup or refreshing an expired login when the user needs to sign in manually.
              - For auth setup/refresh, launch a headed session and keep it alive with a long wait while the user signs in. Example LinkedIn flow:
                ```json
                {"args":["--headed","batch"],"stdin":"[[\"open\",\"https://www.linkedin.com/feed/\"],[\"wait\",\"--fn\",\"location.href.includes('/feed') && !document.querySelector('input[type=password]')\",\"--timeout\",\"600000\"]]","sessionMode":"fresh","timeoutMs":650000}
                ```
              - After the user is logged in, save or refresh the shared state with `args`: `["state", "save", "${agentBrowserStatePath}"]`.
          '';
        };
      };
  };
}
