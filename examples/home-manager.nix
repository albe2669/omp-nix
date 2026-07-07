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

    # API keys are loaded from file paths at runtime. Set `apiKeyFile`
    # on each provider; the module generates a deterministic env var
    # (OMP_<PROVIDER>_API_KEY) and wraps the binary to export it.
    # Works with sops-nix, agenix, or any secrets manager.

    settings = {
      modelRoles = {
        default = "openai/gpt-5.5";
        smol = "openai/gpt-5.5-mini";
        slow = "anthropic/claude-opus-4.5";
        plan = "openai/gpt-5.5";
        task = "openai/gpt-5.5-mini";
        commit = "openai/gpt-5.5-mini";
        tiny = "openai/gpt-5.5-mini";
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

    # Providers and models — written to ~/.omp/agent/models.yml.
    # Set `apiKeyFile` to load the key from a file at runtime. The module
    # generates env var OMP_<PROVIDER>_API_KEY and sets `apiKey` to it.
    providers = {
      openai = {
        baseUrl = "https://api.openai.com/v1";
        apiKeyFile = ./secrets/openai-key;
        api = "openai-completions";
        auth = "apiKey";
        models = [
          {
            id = "gpt-5.5";
            name = "GPT-5.5";
            reasoning = true;
            input = ["text" "image"];
            contextWindow = 400000;
            cost = {
              input = 2.5;
              output = 10;
              cacheRead = 0.3;
              cacheWrite = 0.3;
            };
          }
          {
            id = "gpt-5.5-mini";
            name = "GPT-5.5 Mini";
            reasoning = true;
            input = ["text" "image"];
            contextWindow = 400000;
            cost = {
              input = 0.5;
              output = 2;
              cacheRead = 0.05;
              cacheWrite = 0.05;
            };
          }
        ];
      };

      anthropic = {
        baseUrl = "https://api.anthropic.com/v1";
        apiKeyFile = ./secrets/anthropic-key;
        api = "anthropic-messages";
        auth = "apiKey";
        models = [
          {
            id = "claude-opus-4.5";
            name = "Claude Opus 4.5";
            reasoning = true;
            input = ["text" "image"];
            contextWindow = 200000;
            cost = {
              input = 15;
              output = 75;
              cacheRead = 1.5;
              cacheWrite = 2;
            };
          }
        ];
      };
    };

    enableFishIntegration = true;
  };
}
