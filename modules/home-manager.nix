# Home-manager module for oh-my-pi (omp).
#
# Typed options for the most common settings, plus a freeform `settings`
# attrset for everything else (passed through to config.yml).
# Config schema source of truth:
#   packages/coding-agent/src/config/settings-schema.ts in the omp repo.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.omp;

  yaml = pkgs.formats.yaml {};

  # Providers with an `apiKeyFile` get a deterministic env var name
  # (OMP_<PROVIDER>_API_KEY) that the wrapper exports at runtime.
  # The `apiKey` field in models.yml is set to this env var name;
  # `apiKeyFile` is stripped from the YAML output.
  providersWithKeyFile = filterAttrs (_: p: p ? apiKeyFile) cfg.providers;
  apiKeyEnvVar = name: "OMP_${toUpper name}_API_KEY";
  # Map env var name → file path, for the binary wrapper.
  apiKeyEnvVars =
    mapAttrs' (name: p: {
      name = apiKeyEnvVar name;
      value = p.apiKeyFile;
    })
    providersWithKeyFile;
  # Providers with apiKeyFile replaced: apiKey = <env var>, apiKeyFile stripped.
  providersYaml =
    mapAttrs (
      name: p:
        if p ? apiKeyFile
        then removeAttrs (p // {apiKey = apiKeyEnvVar name;}) ["apiKeyFile"]
        else p
    )
    cfg.providers;

  # Build the config.yml attrset from typed options + freeform settings.
  # Only non-null values are included so omp uses its built-in defaults.
  settingsAttrset = let
    typed = {
      modelRoles = cfg.settings.modelRoles;
      "tools.approvalMode" = cfg.settings.tools.approvalMode;
      "tools.approval" = cfg.settings.tools.approval;
      "lsp.enabled" = cfg.settings.lsp.enabled;
      "lsp.lazy" = cfg.settings.lsp.lazy;
      "lsp.diagnosticsOnWrite" = cfg.settings.lsp.diagnosticsOnWrite;
      "lsp.formatOnWrite" = cfg.settings.lsp.formatOnWrite;
      "bash.enabled" = cfg.settings.bash.enabled;
      "theme.dark" = cfg.settings.theme.dark;
      "theme.light" = cfg.settings.theme.light;
      symbolPreset = cfg.settings.symbolPreset;
      "statusLine.preset" = cfg.settings.statusLine.preset;
      "statusLine.separator" = cfg.settings.statusLine.separator;
      "statusLine.sessionAccent" = cfg.settings.statusLine.sessionAccent;
      "statusLine.transparent" = cfg.settings.statusLine.transparent;
      defaultThinkingLevel = cfg.settings.defaultThinkingLevel;
      "compaction.enabled" = cfg.settings.compaction.enabled;
      "compaction.strategy" = cfg.settings.compaction.strategy;
      "compaction.autoContinue" = cfg.settings.compaction.autoContinue;
      "eval.py" = cfg.settings.eval.py;
      "eval.js" = cfg.settings.eval.js;
      "memory.backend" = cfg.settings.memory.backend;
      "power.sleepPrevention" = cfg.settings.power.sleepPrevention;
      "github.enabled" = cfg.settings.github.enabled;
      personality = cfg.settings.personality;
      "ask.notify" = cfg.settings.ask.notify;
      "ask.timeout" = cfg.settings.ask.timeout;
      "completion.notify" = cfg.settings.completion.notify;
      "web_search.enabled" = cfg.settings.webSearch.enabled;
      "browser.enabled" = cfg.settings.browser.enabled;
      "fetch.enabled" = cfg.settings.fetch.enabled;
      "todo.enabled" = cfg.settings.todo.enabled;
      "todo.reminders" = cfg.settings.todo.reminders;
      "edit.mode" = cfg.settings.edit.mode;
      "edit.fuzzyMatch" = cfg.settings.edit.fuzzyMatch;
      "read.summarize.enabled" = cfg.settings.readSummarize.enabled;
      "git.enabled" = cfg.settings.git.enabled;
      temperature = cfg.settings.temperature;
      topP = cfg.settings.topP;
      topK = cfg.settings.topK;
      setupVersion = cfg.settings.setupVersion;
    };
    # Filter out null values (let omp use its defaults)
    filtered = filterAttrs (_: v: v != null) typed;
  in
    filtered // cfg.extraConfig;
in {
  options.programs.omp = {
    enable = mkEnableOption "oh-my-pi (omp) — AI coding agent for the terminal";

    package = mkOption {
      type = types.package;
      default = pkgs.omp;
      defaultText = literalExpression "pkgs.omp";
      description = "The omp package to use.";
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Override the generated config.yml entirely with a file path.
        When set, the module's typed/freeform settings are ignored and this
        file is symlinked to ~/.omp/agent/config.yml.
      '';
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Extra YAML keys merged into config.yml, on top of the typed/freeform
        settings. Use this for settings not covered by the typed options.
      '';
    };

    settings = mkOption {
      type = types.submodule {
        freeformType = types.attrs;
        options = {
          # ── Model roles ──────────────────────────────────────────────
          modelRoles = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = ''
              Map of model role names to model IDs. Built-in roles:
              default, smol, slow, vision, plan, designer, commit, tiny, task, advisor.
              Example: { default = "corti/corti-s1"; smol = "corti/corti-s1-mini"; }
            '';
          };

          # ── Tools / approvals ────────────────────────────────────────
          tools.approvalMode = mkOption {
            type = types.enum ["always-ask" "write" "yolo"];
            default = "yolo";
            description = "Default approval behavior for tool calls.";
          };
          tools.approval = mkOption {
            type = types.attrsOf (types.enum ["allow" "prompt" "deny"]);
            default = {};
            description = "Per-tool approval policies. Overrides the default mode.";
          };

          # ── LSP ──────────────────────────────────────────────────────
          lsp.enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable the lsp tool.";
          };
          lsp.lazy = mkOption {
            type = types.bool;
            default = true;
            description = "Start language servers on first use.";
          };
          lsp.diagnosticsOnWrite = mkOption {
            type = types.bool;
            default = true;
            description = "Return LSP diagnostics after writing.";
          };
          lsp.formatOnWrite = mkOption {
            type = types.bool;
            default = false;
            description = "Format code files using LSP after writing.";
          };

          # ── Bash ─────────────────────────────────────────────────────
          bash.enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable the bash tool.";
          };

          # ── Theme ────────────────────────────────────────────────────
          theme.dark = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Dark theme name.";
          };
          theme.light = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Light theme name.";
          };
          symbolPreset = mkOption {
            type = types.enum ["unicode" "nerd" "ascii"];
            default = "unicode";
            description = "Glyph set for icons and symbols.";
          };

          # ── Status line ──────────────────────────────────────────────
          statusLine.preset = mkOption {
            type = types.enum ["default" "minimal" "compact" "full" "nerd" "ascii" "custom"];
            default = "default";
            description = "Pre-built status line configuration.";
          };
          statusLine.separator = mkOption {
            type = types.enum ["powerline" "powerline-thin" "slash" "pipe" "block" "none" "ascii"];
            default = "powerline-thin";
            description = "Separator style between status line segments.";
          };
          statusLine.sessionAccent = mkOption {
            type = types.bool;
            default = true;
            description = "Use session name color for borders.";
          };
          statusLine.transparent = mkOption {
            type = types.bool;
            default = false;
            description = "Use terminal default background for status line.";
          };

          # ── Model / thinking ─────────────────────────────────────────
          defaultThinkingLevel = mkOption {
            type = types.enum ["minimal" "low" "medium" "high" "xhigh" "auto" "max"];
            default = "high";
            description = "Reasoning depth for thinking-capable models.";
          };

          # ── Compaction ───────────────────────────────────────────────
          compaction.enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Automatically compact context.";
          };
          compaction.strategy = mkOption {
            type = types.enum ["context-full" "handoff" "shake" "snapcompact" "off"];
            default = "snapcompact";
            description = "Context maintenance strategy.";
          };
          compaction.autoContinue = mkOption {
            type = types.bool;
            default = true;
            description = "Continue after compaction.";
          };

          # ── Eval ─────────────────────────────────────────────────────
          eval.py = mkOption {
            type = types.bool;
            default = true;
            description = "Allow Python eval cells.";
          };
          eval.js = mkOption {
            type = types.bool;
            default = true;
            description = "Allow JavaScript eval cells.";
          };

          # ── Memory ───────────────────────────────────────────────────
          memory.backend = mkOption {
            type = types.enum ["off" "local" "hindsight" "mnemopi"];
            default = "off";
            description = "Memory backend selector.";
          };

          # ── Power (macOS) ────────────────────────────────────────────
          power.sleepPrevention = mkOption {
            type = types.enum ["off" "idle" "display" "system"];
            default = "idle";
            description = "Prevent macOS sleep during active sessions.";
          };

          # ── GitHub ───────────────────────────────────────────────────
          github.enabled = mkOption {
            type = types.bool;
            default = false;
            description = "Enable the github tool.";
          };

          # ── Personality ──────────────────────────────────────────────
          personality = mkOption {
            type = types.enum ["default" "friendly" "pragmatic" "none"];
            default = "default";
            description = "Communication style for the system prompt.";
          };

          # ── Ask / notifications ──────────────────────────────────────
          ask.notify = mkOption {
            type = types.enum ["on" "off"];
            default = "on";
            description = "Notify when the ask tool is waiting for input.";
          };
          ask.timeout = mkOption {
            type = types.int;
            default = 0;
            description = "Auto-select recommended ask option after N seconds (0 = disabled).";
          };
          completion.notify = mkOption {
            type = types.enum ["on" "off"];
            default = "on";
            description = "Notify when the agent finishes a turn.";
          };

          # ── Web search / browser / fetch ────────────────────────────
          webSearch.enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable the web_search tool.";
          };
          browser.enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable the browser tool.";
          };
          fetch.enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Allow read tool to fetch URLs.";
          };

          # ── Todo ────────────────────────────────────────────────────
          todo.enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable the todo tool.";
          };
          todo.reminders = mkOption {
            type = types.bool;
            default = true;
            description = "Remind agent to complete todos.";
          };

          # ── Edit ────────────────────────────────────────────────────
          edit.mode = mkOption {
            type = types.enum ["replace" "patch" "hashline" "apply_patch"];
            default = "hashline";
            description = "Edit tool variant.";
          };
          edit.fuzzyMatch = mkOption {
            type = types.bool;
            default = true;
            description = "Accept high-confidence fuzzy matches.";
          };

          # ── Read ─────────────────────────────────────────────────────
          readSummarize.enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Return structural code summaries from read.";
          };

          # ── Git ─────────────────────────────────────────────────────
          git.enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Enable git integration.";
          };

          # ── Sampling ────────────────────────────────────────────────
          temperature = mkOption {
            type = types.number;
            default = -1;
            description = "Sampling temperature (-1 = provider default).";
          };
          topP = mkOption {
            type = types.number;
            default = -1;
            description = "Nucleus sampling cutoff (-1 = provider default).";
          };
          topK = mkOption {
            type = types.number;
            default = -1;
            description = "Top-K sampling (-1 = provider default).";
          };

          # ── Misc ────────────────────────────────────────────────────
          setupVersion = mkOption {
            type = types.int;
            default = 0;
            description = "Setup version for onboarding step tracking.";
          };
        };
      };
      default = {};
      description = ''
        omp settings, written to ~/.omp/agent/config.yml.
        Typed options cover the most common settings; any other upstream
        setting (see omp's settings-schema.ts) can be added via the freeform
        attrset or `extraConfig`.
      '';
    };

    providers = mkOption {
      type = types.attrsOf (types.submodule {
        freeformType = types.attrs;
        options.apiKeyFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            File path containing the API key for this provider. At runtime,
            the omp binary is wrapped to export the key as the deterministic
            environment variable `OMP_<PROVIDER>_API_KEY`, and the provider's
            `apiKey` field is set to that variable name automatically.
          '';
        };
      });
      default = {};
      description = ''
        Providers and models configuration, written to ~/.omp/agent/models.yml.
        Each provider supports a `apiKeyFile` option for loading the key from
        a file at runtime. Shape matches omp's models-config-schema.ts:
        {
          providers.openai = {
            baseUrl = "...";
            apiKeyFile = ./secrets/openai-key;  # → apiKey = OMP_OPENAI_API_KEY
            api = "openai-completions";
            models = [ { id = "..."; name = "..."; reasoning = true; ... } ];
          };
        }
      '';
    };

    sharedContext = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a Markdown file mounted as ~/.omp/agent/APPEND_SYSTEM.md,
        appended after omp's built-in system prompt.
      '';
    };

    hooks = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          text = mkOption {
            type = types.str;
            description = "Script content.";
          };
          executable = mkOption {
            type = types.bool;
            default = true;
            description = "Make the script executable.";
          };
        };
      });
      default = {};
      description = "Hook scripts placed in ~/.omp/hooks/.";
    };

    enableFishIntegration = mkOption {
      type = types.bool;
      default = false;
      description = "Add omp-related fish shell helper functions.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Wrap the omp binary to export API keys from file paths at runtime.
      # When no providers use apiKeyFile, use the unwrapped package.
      home.packages = [
        (
          if apiKeyEnvVars == {}
          then cfg.package
          else
            (cfg.package.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.makeWrapper];
              postFixup =
                (old.postFixup or "")
                + ''
                  wrapProgram $out/bin/omp \
                    ${concatStringsSep " \\\n  " (mapAttrsToList (
                      envVar: path: "--run 'export ${envVar}=$(cat ${path})'"
                    )
                    apiKeyEnvVars)}
                '';
            }))
        )
      ];

      # All ~/.omp/ files are built into a single home.file attrset to avoid
      # duplicate-attribute conflicts when evaluated outside home-manager's
      # module system (which declares home.file as an attrsOf option).
      home.file =
        {
          # Main config: config.yml (generated from settings, or overridden by a file)
          ".omp/agent/config.yml" = mkMerge [
            (mkIf (cfg.configFile == null) {
              source = yaml.generate "config.yml" settingsAttrset;
            })
            (mkIf (cfg.configFile != null) {
              source = cfg.configFile;
            })
          ];
        }
        // (optionalAttrs (cfg.providers != {}) {
          # Providers/models config: models.yml
          ".omp/agent/models.yml".source = yaml.generate "models.yml" {providers = providersYaml;};
        })
        // (optionalAttrs (cfg.sharedContext != null) {
          # Shared context appended to the system prompt
          ".omp/agent/APPEND_SYSTEM.md" = {
            source = cfg.sharedContext;
          };
        })
        // (mapAttrs' (name: hook: {
            name = ".omp/hooks/${name}";
            value = {
              inherit (hook) executable;
              text = hook.text;
            };
          })
          cfg.hooks);
    }

    (mkIf cfg.enableFishIntegration {
      programs.fish.shellInit = ''
        # Create a new branch worktree and open it in omp
        function ompw
          if test (count $argv) -lt 1
            echo "Usage: ompw <branch> [base]"
            return 1
          end
          set branch $argv[1]
          set base "main"
          if test (count $argv) -ge 2
            set base $argv[2]
          end

          if not git rev-parse --verify $base > /dev/null 2>&1
            echo "Base branch $base does not exist."
            return 1
          end

          set path "./.omp/worktrees/$branch"
          if git rev-parse --verify $branch > /dev/null 2>&1
            echo "Branch $branch already exists. Please choose a different name."
            return 1
          end
          git worktree add -b $branch $path $base
          echo "Worktree for branch $branch created at $path"
          echo "Starting omp in $path..."
          cd $path && omp
        end

        # Check out an existing branch into a worktree and open it in omp
        function ompwe
          if test (count $argv) -ne 1
            echo "Usage: ompwe <existing-branch>"
            return 1
          end
          set branch $argv[1]
          set basepath "./.omp/worktrees"
          set path "$basepath/$branch"
          mkdir -p $basepath
          if not git rev-parse --verify $branch > /dev/null 2>&1
            echo "Branch $branch does not exist. Please choose an existing branch."
            return 1
          end
          git worktree add --checkout $path $branch
          echo "Worktree for branch $branch created at $path"
          echo "Starting omp in $path..."
          cd $path && omp
        end
      '';
    })
  ]);
}
