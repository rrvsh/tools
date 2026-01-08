{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.codex = {
        enable = true;
        settings.features.web_search_request = true;
        # Note: Don't remove or modify the following without STRICT research.
        custom-instructions = ''
          I should really remember that I have access to web search, and I should really try and use web search for anything that might be outdated or underrepresented in our dataset, which if the user is asking me, is probably true. I should verify syntax by reading language docs, confirm options by reading api references, and keep in mind the whole context by investigating and keeping in context our own codebase.
        '';
      };
    };
  };
}
