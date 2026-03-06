# Hyprland Documentation Index

Search terms are suggestions for queries. Key points summarize what the page covers.
Always use subagents for research.

| Search terms | Key points | Link |
| --- | --- | --- |
| hyprland wiki, docs home, version selector, latest git, wayland intro | Entry point for wiki navigation, version awareness, and core context for new users. | [Wiki](https://wiki.hypr.land/) |
| getting started, first steps, new user flow, install order, tutorial path | Overview of the recommended onboarding path from install to first configuration. | [Getting Started](https://wiki.hypr.land/Getting-Started/) |
| install hyprland, packages, distro install, setup compositor, prerequisites | Installation guidance and distro-specific setup starting points. | [Installation](https://wiki.hypr.land/Getting-Started/Installation/) |
| master tutorial, initial config, first launch, starter config, beginner setup | Guided setup for first working configuration and daily-use basics. | [Master Tutorial](https://wiki.hypr.land/Getting-Started/Master-Tutorial/) |
| configuring, ricing, config architecture, options map, customization | High-level map of configuration topics and links to detailed config references. | [Configuring](https://wiki.hypr.land/Configuring/) |
| hyprland.conf, config file, include config, start page, syntax basics | Baseline config structure and how to organize/manage config files. | [Start](https://wiki.hypr.land/Configuring/Start/) |
| config variables, variable blocks, option groups, sections, value types | Reference for variable namespaces and configuration option groups. | [Variables](https://wiki.hypr.land/Configuring/Variables/) |
| keywords, config directives, keyword reference, option names, syntax | Canonical keyword reference for compositor behavior and features. | [Keywords](https://wiki.hypr.land/Configuring/Keywords/) |
| monitor setup, display config, resolution, refresh rate, scale, position | Configure displays, output layout, scaling, and monitor-specific behavior. | [Monitors](https://wiki.hypr.land/Configuring/Monitors/) |
| keybinds, binds, shortcuts, hotkeys, keyboard actions, modifiers | Define keyboard and mouse bindings, flags, and bind syntax patterns. | [Binds](https://wiki.hypr.land/Configuring/Binds/) |
| dispatchers, commands, workspace actions, window actions, exec | Action command reference used by binds and automation workflows. | [Dispatchers](https://wiki.hypr.land/Configuring/Dispatchers/) |
| window rules, class rules, title rules, floating rules, matching | Match windows and apply behavior/style rules at runtime. | [Window Rules](https://wiki.hypr.land/Configuring/Window-Rules/) |
| workspace rules, workspace behavior, assignment, monitor mapping, defaults | Configure workspace-level behavior and placement constraints. | [Workspace Rules](https://wiki.hypr.land/Configuring/Workspace-Rules/) |
| environment variables, env vars, wlroots vars, startup env, backend vars | Runtime environment variable reference and compatibility toggles. | [Environment Variables](https://wiki.hypr.land/Configuring/Environment-variables/) |
| hyprctl, cli control, runtime inspect, reload config, dispatch commands | Control and inspect live Hyprland state from terminal tooling. | [Using hyprctl](https://wiki.hypr.land/Configuring/Using-hyprctl/) |
| ipc, unix sockets, socket2 events, event stream, automation | IPC socket protocols for scripting, status listeners, and external integrations. | [IPC](https://wiki.hypr.land/IPC/) |
| plugins, extend hyprland, plugin system, custom features, load plugins | Plugin ecosystem overview and entry points for usage/development docs. | [Plugins](https://wiki.hypr.land/Plugins/) |
| plugin usage, install plugin, hyprpm, plugin manager, enable plugins | How to install and operate plugins in a running Hyprland setup. | [Using Plugins](https://wiki.hypr.land/Plugins/Using-Plugins/) |
| plugin development, plugin api, write plugin, headers, build plugin | Development track for authoring and debugging custom Hyprland plugins. | [Plugin Development](https://wiki.hypr.land/Plugins/Development/) |
| nix, hyprland nix module, flakes, nix ecosystem, declarative setup | Nix-focused landing page for module-based installs and configuration. | [Nix](https://wiki.hypr.land/Nix/) |
| nixos module, nixos hyprland, module enablement, display manager session | NixOS integration details and required module wiring. | [Hyprland on NixOS](https://wiki.hypr.land/Nix/Hyprland-on-NixOS/) |
| home-manager hyprland, hm module, user config nix, declarative home config | Home Manager integration and user-scoped declarative setup patterns. | [Hyprland on Home Manager](https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/) |
| nvidia, proprietary drivers, gpu issues, env tuning, compatibility | NVIDIA-specific requirements, caveats, and recommended configuration. | [Nvidia](https://wiki.hypr.land/Nvidia/) |
| useful utilities, ecosystem apps, launcher, bars, clipboard, portals | Curated utilities and companion tooling commonly used with Hyprland. | [Useful Utilities](https://wiki.hypr.land/Useful-Utilities/) |
| xdg desktop portal, screenshare portal, file picker portal, wlroots portal | Portal integration guidance for screen sharing and desktop app interop. | [xdg-desktop-portal-hyprland](https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/) |
| crashes, bug report, logs, gl debugging, reproduction, troubleshooting | Crash triage workflow, log collection, and actionable debugging steps. | [Crashes and Bugs](https://wiki.hypr.land/Crashes-and-Bugs/) |
| faq, symbol lookup error, common issues, startup failures, fixes | High-frequency problems and quick resolutions for common breakages. | [FAQ](https://wiki.hypr.land/FAQ/) |
| remote access, connect, wayvnc, rdp, xrdp, sunshine, streaming | Remote access and connection patterns for external clients/services. | [Connect](https://wiki.hypr.land/Connect/) |
| hypr ecosystem, hyprpaper, hyprlock, hypridle, official tools | Catalog of official companion projects in the Hypr ecosystem. | [Hypr Ecosystem](https://wiki.hypr.land/Hypr-Ecosystem/) |
| contributing, debugging, issue guidelines, pr guidelines, tests | Contribution workflows, testing expectations, and debugging best practices. | [Contributing and Debugging](https://wiki.hypr.land/Contributing-and-Debugging/) |

Maintenance notes:
- Keep all links as absolute `https://wiki.hypr.land/` URLs with full paths.
- The wiki is versioned; verify links against the intended version selector when rebuilding.
- Validate links with `curl` checks when rebuilding the index.
