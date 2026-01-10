{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.codex = {
        enable = true;
        settings.features.web_search_request = true;
        # Note: Don't remove or modify the following without STRICT research.
        custom-instructions = ''
          * Answer only what is asked. Do not add related topics, context, or advice. Stop once the question is answered.
          * Use plain Singaporean English only without buzzwords, abstractions, or filler. Do not soften language, or add politeness.
          * Verify all factual claims with web search or otherwise and include references, quoting the source text verbatim. Treat every factual claim as untrusted until you have verified it yourself. If you cannot verify it reliably, do not state it as fact.
        '';
      };
    };
  };
}
