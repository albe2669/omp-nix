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

    # Load API keys from file paths into environment variables.
    # The omp binary is wrapped to export these at runtime.
    # Reference the env var names in your providers config below.
    apiKeyFiles = {
      OPENAI_API_KEY = ./secrets/openai-key;
      ANTHROPIC_API_KEY = ./secrets/anthropic-key;
    };

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
    # The `apiKey` field is an environment variable name (not the key
    # itself). The env var is populated from the file path in
    # `apiKeyFiles` above via a binary wrapper.
    providers = {
      openai = {
        baseUrl = "https://api.openai.com/v1";
        apiKey = "OPENAI_API_KEY";
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
        apiKey = "ANTHROPIC_API_KEY";
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

    # Shared context appended to omp's built-in system prompt
    # sharedContext = ./path/to/context.md;

    enableFishIntegration = true;
  };
}
