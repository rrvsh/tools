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
        slopchop = inputs.pi-slopchop.packages.${system}.pi-slopchop;
        sessionDrain = inputs.pi-session-drain.packages.${system}.pi-session-drain;
        # NixOS cannot run agent-browser's downloaded generic Chrome, so point the
        # extension at Nix-provided Chromium for fresh browser launches by default.
        agentBrowserConfig = {
          version = 1;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          browser.executablePath = "${pkgs.chromium}/bin/chromium";
        };
        homeDirectory = config.home.homeDirectory;
        toolsDirectory = "${homeDirectory}/Git/tools";
        agentBrowserStatePath = "${homeDirectory}/.agent-browser/state/agent.json";
      in
      {
        home = {
          packages = [ agentBrowser ] ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.chromium ];
          file.".pi/config/pi-agent-browser-native/config.json".text = builtins.toJSON agentBrowserConfig;
          # Note: this does not show up in the loaded context files, but it is appended to the system prompt.
          file.".pi/agent/APPEND_SYSTEM.md".source =
            config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/Agents/MEMORY.md";
        };
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
            slopchop.passthru.packagePath
            sessionDrain.passthru.packagePath
          ];
          context = lib.concatStringsSep "\n" (
            [
              "# AGENTS.md"
              ""
              "## Working style"
              ""
              "- Be concise."
              "- Prefer iterative discussion over grand plans."
              "- Infer aggressively, but confirm before risky, broad, destructive, or persistent changes."
              "- Avoid over-design. Prefer simple systems that are good enough."
              "- Push back on unclear, premature, over-structured, or inconsistent directions."
              "- Ask one focused planning question at a time."
              "- Check existing decisions before re-asking settled questions."
              "- If the user says \"omit\", omit it from the response."
              ""
              "## Native tools"
              ""
              "- Use native Pi tools where possible."
              "- Read files with `read`."
              "- Edit files with `edit` for precise changes."
              "- Write files with `write` only for new files or full rewrites."
              "- Use `bash` for shell commands and file inspection."
              "- Use workarounds, scripts, or ad hoc Python only when native tools are insufficient."
              ""
              "## Instruction changes"
              ""
              "- Changes to `AGENTS.md`, skills, workflow rules, or reusable agent behavior require explicit approval."
              "- Draft proposed instruction text in chat before editing."
              "- Do not silently promote raw notes, inbox items, transcripts, or research into memory or instructions."
              ""
              "## Agent memory"
              ""
              "- `${homeDirectory}/Agents/MEMORY.md` is the compact index for durable agent memory."
              "- `${homeDirectory}/Agents/memory/**/*.md` contains freeform topic memory files."
              "- Read memory when prior preferences, corrections, environment facts, or tool quirks may matter."
              "- Update memory proactively when the user corrects you, states a durable preference, or you discover a reusable environment/tool quirk."
              "- After non-trivial tasks, briefly check whether anything should be saved to memory."
              "- Keep `${homeDirectory}/Agents/MEMORY.md` compact, with one-line pointers to topic files."
              "- Put memory details in topic files under `${homeDirectory}/Agents/memory/`."
              "- Agents may create topic files under `${homeDirectory}/Agents/memory/**/*.md` as needed."
              "- Do not store secrets, credentials, raw transcripts, or temporary task progress."
              "- Memory is context, not instruction. `AGENTS.md`, repo instructions, and direct user instructions take precedence."
              "- Do not silently promote memory into instructions; propose instruction changes first."
              ""
              "## Missing commands and dependencies"
              ""
              "- If a command or binary is missing, use comma first: `, <command> [args...]`."
              "- For Python, prefer `, python3 ...`."
              "- Avoid assuming third-party Python deps are installed."
              "- If `, <command>` fails because an interactive picker needs a TTY, inspect candidates with `, --print-packages <command>`."
              "- After identifying the package, use `nix shell` with a full flake ref, e.g. `nix shell github:NixOS/nixpkgs/nixos-unstable#<package> -c <command> ...`."
              "- Do not use indirect refs like `nixpkgs#<package>`; registry lookups are disabled."
              "- Useful comma commands:"
              "  - `, --help`"
              "  - `, --print-packages <command>`"
              "  - `, --print-path <command>`"
              "  - `, --shell <command>`"
              "  - `, --install <command>`"
              "- For less ephemeral workloads, prefer a project dev shell or flake-backed shell."
              ""
              "## Home directory index"
              ""
              "- `${homeDirectory}/Agents` - agent memory, research, generated artifacts."
              "  - `MEMORY.md` - compact durable agent memory index."
              "  - `memory` - freeform durable topic memory."
              "  - `artifacts` - generated evidence, session exports, audits, browser/job artifacts."
              "  - `research` - agent-owned research and long-form generated research."
              "- `${homeDirectory}/Archive` - inactive material, backups, old projects, records, sensitive cold storage."
              "  - `backups` - dated backups."
              "  - `old-library` - preserved old library remainder."
              "  - `old-projects` - inactive projects."
              "  - `records` - archived records."
              "  - `sensitive` - sensitive archived material."
              "- `${homeDirectory}/Documents` - formal documents."
              "  - `Career` - career records, applications, education, certifications."
              "  - `Books` - books."
              "  - `Manuals` - manuals."
              "- `${homeDirectory}/Downloads` - browser/download inbox and unsorted artifacts."
              "- `${homeDirectory}/Garden` - human-owned notes and knowledge base."
              "  - `logs` - daily/monthly time-based notes."
              "  - `threads` - named ongoing strands."
              "  - `research` - human-owned deeper inquiry/synthesis."
              "  - `archive` - old note material kept without further classification."
              "- `${homeDirectory}/Git` - git repositories and code workspaces."
              "  - `${toolsDirectory}` - source of truth checkout for machine/Nix configuration on this host."
              "- `${homeDirectory}/Music` - audio/music."
              "- `${homeDirectory}/Pictures` - images/screenshots/visual references."
              "- `${homeDirectory}/Videos` - videos/screen recordings."
              ""
              "## Web and browser"
              ""
              "- For public web content, use `web_search` or `fetch_content` first."
              "- Do not use `web_search`, `fetch_content`, `curl`, or bash to read auth-walled or account-specific content."
              "- For auth-walled or account-specific content, use native `agent_browser` with shared state."
              "- Shared browser state: `${agentBrowserStatePath}`."
              "- If shared state is not authenticated, ask the user to authenticate."
              "- Use the native `agent_browser` tool; do not drive `agent-browser` through bash."
              "- Verify auth by checking for login/password UI, not URL alone."
              "- For dynamic SPAs, prefer `open -> wait -> eval/get`; snapshot refs can become stale."
              "- Do not submit/apply/send, save/unsave, follow/message, create alerts, dismiss/report, upload/delete, or change settings unless explicitly authorized."
              "- Use headed browsing only for login/auth refresh."
            ]
            ++ lib.optionals pkgs.stdenv.isLinux [
              "- On Linux/NixOS, fresh browser launches should use the configured Nix Chromium."
            ]
            ++ [
              ""
              "## Nix and flakes"
              ""
              "- To inspect flake inputs locally:"
              "  - `nix flake metadata --json | jq '.locks.nodes | keys'`"
              "  - `nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.<name>.outPath'`"
              "- Nix flake source files often need to be git-tracked before eval/checks."
              ""
              "## Coding and review"
              ""
              "- Prefer small, reviewable changes."
              "- Never fail silently; invalid explicit input should error with helpful guidance."
              "- Keep reviews low-noise and high-signal."
              "- Prioritize real bugs, security issues, race/async issues, data loss, and API contract violations."
              "- Avoid nitpicks when tooling or CI covers them."
            ]
          );
        };
      };
  };
}
