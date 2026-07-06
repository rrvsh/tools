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
        # NixOS cannot run agent-browser's downloaded generic Chrome, so point the
        # extension at Nix-provided Chromium for fresh browser launches by default.
        agentBrowserConfig = {
          version = 1;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          browser.executablePath = "${pkgs.chromium}/bin/chromium";
        };
        agentBrowserStatePath = "${config.home.homeDirectory}/.agent-browser/state/agent.json";
      in
      {
        home.packages = [ agentBrowser ] ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.chromium ];
        home.file.".pi/config/pi-agent-browser-native/config.json".text =
          builtins.toJSON agentBrowserConfig;
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
          context = lib.concatStringsSep "\n" (
            [
              "# Global pi instructions"
              ""
              "- If a command is missing, use comma: `, <command> [args...]`"
              "- For Python, run via comma: `, python3 ...`"
              "- Load and follow the global skill: `comma` (`~/.pi/agent/skills/comma/SKILL.md`)"
              "- Avoid assuming third-party Python deps (e.g., `requests`, `bs4`) are installed."
              "- To inspect flake inputs locally:"
              "  - `nix flake metadata --json | jq '.locks.nodes | keys'`"
              "  - `nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.<name>.outPath'`"
              "- Agent browser:"
              "  - `agent-browser` is installed in the user shell and on Pi's wrapped runtime `PATH`."
              "  - Use the native `agent_browser` tool for browser automation; do not drive `agent-browser` through bash from Pi."
              "  - Auth-walled and account-specific sites, especially LinkedIn, must use `agent_browser` with the shared auth state before declaring an auth wall or login problem. Do not use `ddgr`, `web_search`, `fetch_content`, `curl`, or bash to read LinkedIn page content."
              "  - Use one shared auth state file for all sites: `${agentBrowserStatePath}`. Do not create per-service restore buckets such as `--restore=linkedin` unless explicitly asked."
              "  - Normal authenticated browsing is headless and state-backed. Launch fresh with the shared state file, e.g. `args`: `[\"--state\", \"${agentBrowserStatePath}\", \"open\", \"https://www.linkedin.com/feed/\"]`, `sessionMode`: `\"fresh\"`. Use the same pattern for LinkedIn profiles, posts, search, and jobs by replacing the URL."
              "  - After a state-backed open, inspect with `snapshot -i`, `get`, or `eval --stdin`. If the page still shows a login form or password field, ask the user whether to refresh the shared login; do not stop at \"auth wall\"."
              "  - Do not use `--headed` for normal browsing. Use `--headed` only for initial auth setup or refreshing an expired login when the user needs to sign in manually."
              "  - For auth setup/refresh, launch a headed session and keep it alive with a long wait while the user signs in. Example LinkedIn flow:"
              "    ```json"
              ''{"args":["--headed","batch"],"stdin":"[[\"open\",\"https://www.linkedin.com/feed/\"],[\"wait\",\"--fn\",\"location.pathname.includes('/feed') && !document.querySelector('input[type=password]')\",\"--timeout\",\"600000\"]]","sessionMode":"fresh","timeoutMs":650000}''
              "    ```"
              "  - After the user is logged in, save or refresh the shared state with `args`: `[\"state\", \"save\", \"${agentBrowserStatePath}\"]`."
            ]
            ++ lib.optionals pkgs.stdenv.isLinux [
              "  - On Linux/NixOS, the agent_browser extension config points fresh launches at Nix-provided Chromium; the generic browser downloaded by `agent-browser install` is not NixOS-compatible."
            ]
            ++ lib.optionals pkgs.stdenv.isDarwin [
              "  - On Darwin, run `agent-browser install` if the agent browser executable is not present."
            ]
          );
        };
      };
  };
}
