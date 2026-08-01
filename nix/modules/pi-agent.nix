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
      let
        system = pkgs.stdenv.hostPlatform.system;
        agentBrowser = inputs.agent-browser.packages.${system}.agent-browser;
        slopchop = inputs.pi-slopchop.packages.${system}.pi-slopchop;
        sessionDrain = inputs.pi-session-drain.packages.${system}.pi-session-drain;
        piPackage = inputs.pi.packages.${system}.pi-coding-agent;
        sessionDrainRun = pkgs.writeShellApplication {
          name = "pi-session-drain-run";
          runtimeInputs = [
            piPackage
            pkgs.nodejs_22
          ];
          text = ''
            export PI_OFFLINE=1
            export PI_SKIP_VERSION_CHECK=1
            export PI_SESSION_DRAIN_MAX_SESSIONS=''${PI_SESSION_DRAIN_MAX_SESSIONS:-20}
            export PI_SESSION_DRAIN_MAX_CHUNKS_PER_SESSION=''${PI_SESSION_DRAIN_MAX_CHUNKS_PER_SESSION:-80}
            export PI_SESSION_DRAIN_SESSION_CONCURRENCY=''${PI_SESSION_DRAIN_SESSION_CONCURRENCY:-5}
            export PI_SESSION_DRAIN_CHUNK_CONCURRENCY=''${PI_SESSION_DRAIN_CHUNK_CONCURRENCY:-4}
            export PI_SESSION_DRAIN_TIMEOUT_MS=''${PI_SESSION_DRAIN_TIMEOUT_MS:-7200000}
            export PI_SESSION_DRAIN_MIN_CODEX_REMAINING_PERCENT=''${PI_SESSION_DRAIN_MIN_CODEX_REMAINING_PERCENT:-50}

            usage_decision="$(node <<'NODE'
            const fs = require("node:fs");
            const https = require("node:https");
            const os = require("node:os");
            const path = require("node:path");
            const threshold = Number(process.env.PI_SESSION_DRAIN_MIN_CODEX_REMAINING_PERCENT || "50");
            const authPath = path.join(os.homedir(), ".pi", "agent", "auth.json");
            function decide(decision, message) {
              console.log("Codex usage gate: " + message);
              console.log("Decision: " + decision);
            }
            function getUsage(accessToken) {
              return new Promise((resolve, reject) => {
                const req = https.request("https://chatgpt.com/backend-api/wham/usage", {
                  headers: {
                    accept: "application/json",
                    authorization: "Bearer " + accessToken,
                  },
                }, (res) => {
                  let body = "";
                  res.on("data", (chunk) => {
                    body += chunk;
                    if (body.length > 1000000) req.destroy(new Error("usage response too large"));
                  });
                  res.on("end", () => resolve({ statusCode: res.statusCode, body }));
                });
                req.on("error", reject);
                req.setTimeout(20000, () => req.destroy(new Error("usage request timed out")));
                req.end();
              });
            }
            (async () => {
              if (!Number.isFinite(threshold) || threshold <= 0) {
                decide("allow", "disabled by threshold " + threshold);
                return;
              }
              let auth;
              try {
                auth = JSON.parse(fs.readFileSync(authPath, "utf8"))["openai-codex"];
              } catch (error) {
                decide("skip", "could not read Pi OpenAI Codex OAuth state");
                return;
              }
              if (!auth || auth.type !== "oauth" || typeof auth.access !== "string") {
                decide("skip", "Pi OpenAI Codex OAuth state is missing");
                return;
              }
              if (typeof auth.expires === "number" && auth.expires <= Date.now()) {
                decide("skip", "Pi OpenAI Codex OAuth token is expired");
                return;
              }
              let response;
              try {
                response = await getUsage(auth.access);
              } catch (error) {
                decide("skip", "usage request failed: " + error.message);
                return;
              }
              if (response.statusCode !== 200) {
                decide("skip", "usage request returned HTTP " + response.statusCode);
                return;
              }
              let usage;
              try {
                usage = JSON.parse(response.body);
              } catch (error) {
                decide("skip", "usage response was not valid JSON");
                return;
              }
              const used = usage && usage.rate_limit && usage.rate_limit.primary_window && usage.rate_limit.primary_window.used_percent;
              if (typeof used !== "number") {
                decide("skip", "usage response did not include primary used_percent");
                return;
              }
              const remaining = Math.max(0, 100 - used);
              const suffix = used + "% used, " + remaining + "% remaining, threshold " + threshold + "%";
              decide(remaining >= threshold ? "allow" : "skip", suffix);
            })().catch((error) => decide("skip", "usage gate crashed: " + error.message));
            NODE
            )"
            echo "$usage_decision"
            case "$usage_decision" in
              *"Decision: allow"*) ;;
              *) exit 0 ;;
            esac

            exec pi --no-session -p '/session-drain:run'
          '';
        };
        # NixOS cannot run agent-browser's downloaded generic Chrome, so point the
        # extension at Nix-provided Chromium for fresh browser launches by default.
        agentBrowserConfig = {
          version = 1;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          browser.executablePath = "${pkgs.chromium}/bin/chromium";
        };
        homeDirectory = config.home.homeDirectory;
        inherit (cfg.paths) root;
      in
      {
        home = {
          packages = [
            agentBrowser
            sessionDrainRun
          ]
          ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.chromium ];
          file = {
            ".pi/config/pi-agent-browser-native/config.json".text = builtins.toJSON agentBrowserConfig;
            # Note: this does not show up in the loaded context files, but it is appended to the system prompt.
            ".pi/agent/APPEND_SYSTEM.md".source =
              config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/Agents/MEMORY.md";
          };
        };
        systemd.user.services.pi-session-drain = {
          Unit.Description = "Drain Pi sessions into agent memory";
          Service = {
            Type = "oneshot";
            WorkingDirectory = homeDirectory;
            ExecStart = "${sessionDrainRun}/bin/pi-session-drain-run";
            TimeoutStartSec = "2h 15m";
          };
        };
        systemd.user.timers.pi-session-drain = {
          Unit.Description = "Run Pi session drain daily";
          Timer = {
            OnCalendar = "daily";
            OnBootSec = "30m";
            RandomizedDelaySec = "2h";
            AccuracySec = "15m";
            Persistent = false;
            Unit = "pi-session-drain.service";
          };
          Install.WantedBy = [ "timers.target" ];
        };
        programs.pi-coding-agent = {
          enable = true;
          package = inputs.pi.packages.${system}.pi-coding-agent;
          extraPackages = [
            pkgs.nodejs_22
            agentBrowser
          ];
          settings = {
            lastChangelogVersion = lib.getVersion config.programs.pi-coding-agent.package;
            extensions = [
              (root + "/pi/extensions/hostname-context.ts")
              (root + "/pi/extensions/system-prompt-viewer.ts")
            ];
            packages = [
              # Keep this pinned with the agent-browser flake input: pi-agent-browser-native
              # tracks specific agent-browser CLI versions in its command surface and result parsing.
              "npm:pi-agent-browser-native@0.2.64"
              "npm:pi-mcp-adapter"
              "npm:pi-subagents"
              "npm:pi-web-access"
              "npm:pi-context-breadcrumbs"
              "npm:context-mode"
              slopchop.passthru.packagePath
              sessionDrain.passthru.packagePath
            ];
          };
          context = ''
            ## Writing rules

            Use Orwell's rules and ASD-STE100 Simplified Technical English by default.

            ### Exceptions

            Break a writing rule only to keep text correct, exact, or natural.
            Do not break a rule for style, variety, or emphasis.

            ### Meaning

            - Keep the meaning exact.
            - Do not simplify text if the meaning changes.
            - Keep necessary technical terms.
            - Define a technical term the first time you use it, unless the user already defined it.
            - Keep code, commands, paths, identifiers, product names, quotes, and errors exact.
            - Do not rewrite quoted text unless the user asks for that.

            ### Words

            - Use short, common words.
            - Use a long word only if it is more exact than the short word.
            - Do not use jargon if a common word has the same meaning.
            - Do not use foreign phrases, idioms, stock phrases, dead metaphors, or common figures of speech.
            - Use one term for one meaning.
            - Do not use a second term for the same meaning.
            - Remove words that do not add meaning.

            ### Sentences

            - Use short sentences.
            - Put one idea or one action in each sentence.
            - Keep procedure sentences to 20 words or fewer.
            - Keep descriptive sentences to 25 words or fewer.
            - Keep necessary words, including articles.
            - Do not use contractions.
            - Do not use semicolons in prose.
            - Use lists for complex information.

            ### Grammar

            - Use active voice.
            - Use passive voice only if the actor is unknown, irrelevant, or intentionally hidden.
            - Use clear subjects and verbs.
            - Use simple verb tenses.
            - Use another tense only if simple present or simple past changes the meaning.
            - Use articles such as `a`, `an`, and `the` before nouns where English grammar permits them.
            - Keep noun groups to three words or fewer.
            - If a noun group needs more than three words, use prepositions or define a short form.

            ### Procedures

            - Write direct instructions.
            - Use one instruction per sentence.
            - Put the condition before the command.
            - Start condition sentences with `if` or `when`.
            - State the expected result if the reader must verify success.
            - Use positive instructions.
            - Use a negative instruction only to prevent danger, damage, data loss, or a likely error.
            - Do not use `should` for required actions.
            - Use `must` for requirements.
            - Use an imperative verb for commands.
          '';
        };
      };
  };
}
