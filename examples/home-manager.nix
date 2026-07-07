# Example home-manager configuration for omp.
#
# Add this to your home-manager imports:
#   imports = [ inputs.omp-nix.homeModules.omp ];
# Then:
#   programs.omp.enable = true;
#   programs.omp.settings = { ... };
{...}: {
  programs.omp = {
    enable = true;

    settings = {
      modelRoles = {
        default = "corti/corti-s1";
        smol = "corti/corti-s1-mini";
        slow = "corti/corti-s1";
        plan = "corti/corti-s1";
        task = "corti/corti-s1-mini";
        commit = "corti/corti-s1-mini-instant";
        tiny = "corti/corti-s1-mini-instant";
      };

      tools.approvalMode = "yolo";
      tools.approval.bash = "allow";

      lsp = {
        enabled = true;
        lazy = true;
        diagnosticsOnWrite = true;
        formatOnWrite = true;
      };

      bash.enabled = true;

      theme.dark = "titanium";
      symbolPreset = "nerd";

      statusLine = {
        preset = "default";
        separator = "powerline-thin";
        sessionAccent = true;
        transparent = true;
      };

      defaultThinkingLevel = "auto";

      compaction = {
        enabled = true;
        strategy = "context-full";
        autoContinue = true;
      };

      eval.py = true;
      eval.js = true;

      memory.backend = "mnemopi";

      power.sleepPrevention = "system";

      github.enabled = true;

      personality = "default";

      ask.notify = "on";
      completion.notify = "on";

      setupVersion = 1;
    };

    # Providers and models — written to ~/.omp/agent/models.yml
    providers = {
      corti = {
        baseUrl = "https://api.corti.ai/v1";
        apiKey = "CORTI_API_KEY"; # env var name, not the key itself
        api = "openai-completions";
        auth = "apiKey";
        models = [
          {
            id = "corti-s1";
            name = "Corti S1 (GLM5.2)";
            reasoning = true;
            input = ["text"];
            contextWindow = 1000000;
            cost = {
              input = 2;
              output = 8;
              cacheRead = 0.2;
              cacheWrite = 0.2;
            };
          }
          {
            id = "corti-s1-mini";
            name = "Corti S1 Mini (Qwen3.6)";
            reasoning = true;
            input = ["text"];
            contextWindow = 1000000;
            cost = {
              input = 1;
              output = 4;
              cacheRead = 0.1;
              cacheWrite = 0.1;
            };
          }
        ];
      };
    };

    # Shared context appended to omp's built-in system prompt
    # sharedContext = ./path/to/context.md;

    enableFishIntegration = true;
  };
}
