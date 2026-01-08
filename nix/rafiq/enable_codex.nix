{
  config.flake = {
    modules.homeManager.rafiq.programs.codex = {
      enable = true;
      settings = {
        features.web_search_request = true;
        model = "gpt-5.1-codex-max"; # Little blurb to get it to use a temporary better model
        notice."hide_gpt-5.1-codex-max_migration_prompt" = true; # ^
        projects = {
          "/Users/rafiq".trust_level = "untrusted";
          "/Users/rafiq/tools".trust_level = "trusted";
          "/Users/rafiq/projects".trust_level = "trusted";
        };
      };
      # Note: Don't remove or modify the following without STRICT research.
      custom-instructions = ''
        I should really remember that I have access to web search, and I should really try and use web search for anything that might be outdated or underrepresented in our dataset, which if the user is asking me, is probably true. I should verify syntax by reading language docs, confirm options by reading api references, and keep in mind the whole context by investigating and keeping in context our own codebase.
      '';
    };
  };
}
