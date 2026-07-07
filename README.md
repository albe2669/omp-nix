# omp-nix

Auto-updating Nix flake for [oh-my-pi](https://github.com/can1357/oh-my-pi) (`omp`) — the AI coding agent for the terminal.

**🚀 Automatically updated every 6 hours** via GitHub Actions. New omp releases are detected, hashed, and auto-merged as a PR after a Linux + Darwin build matrix passes.

## Features

- **Always up-to-date**: GitHub Actions checks for new omp releases every 6 hours
- **Multi-platform**: Builds for `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`
- **Typed config**: Home-manager module with typed options for the most common omp settings
- **Full config support**: Freeform `settings` attrset for any upstream setting
- **Providers/models**: Declarative provider and model configuration → `~/.omp/agent/models.yml`
- **NixOS + Home Manager**: Both modules included

## Quick Start

```bash
# Run omp directly without installing
nix run github:albe2669/omp-nix

# Install to your profile
nix profile install github:albe2669/omp-nix
```

## Home Manager

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    omp-nix.url = "github:albe2669/omp-nix";
  };

  outputs = { self, nixpkgs, home-manager, omp-nix, ... }: {
    homeConfigurations."username" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        omp-nix.homeModules.omp
        {
          programs.omp.enable = true;
          programs.omp.settings = {
            tools.approvalMode = "yolo";
            lsp.enabled = true;
            memory.backend = "mnemopi";
            # ... any setting from omp's config schema
          };
        }
      ];
    };
  };
}
```

See [`examples/home-manager.nix`](./examples/home-manager.nix) for a complete example with providers/models.

## NixOS

```nix
{
  inputs.omp-nix.url = "github:albe2669/omp-nix";

  outputs = { self, nixpkgs, omp-nix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        omp-nix.nixosModules.omp
        {
          programs.omp.enable = true;
        }
      ];
    };
  };
}
```

## Overlay

```nix
{
  nixpkgs.overlays = [ omp-nix.overlays.default ];
  environment.systemPackages = [ pkgs.omp ];
}
```

## Configuration

The home-manager module exposes `programs.omp` with:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Install omp + generate config |
| `package` | package | `pkgs.omp` | The omp package |
| `configFile` | path \| null | null | Override generated config.yml |
| `extraConfig` | attrs | `{}` | Extra YAML keys for config.yml |
| `settings` | submodule | `{}` | Typed + freeform settings → config.yml |
| `providers` | attrs | `{}` | Providers/models → models.yml |
| `sharedContext` | path \| null | null | APPEND_SYSTEM.md |
| `hooks` | attrs | `{}` | Hook scripts in ~/.omp/hooks/ |
| `enableFishIntegration` | bool | `false` | Fish shell helper functions |

### Typed settings

The most common settings have typed options with defaults matching upstream:

- `settings.modelRoles` — map of role → model ID
- `settings.tools.approvalMode` — `always-ask` / `write` / `yolo`
- `settings.tools.approval` — per-tool approval policies
- `settings.lsp.*` — LSP config (enabled, lazy, diagnostics, format)
- `settings.bash.enabled`
- `settings.theme.dark` / `theme.light`
- `settings.symbolPreset` — `unicode` / `nerd` / `ascii`
- `settings.statusLine.*` — preset, separator, accents
- `settings.defaultThinkingLevel` — `auto`/`minimal`/`low`/`medium`/`high`/`xhigh`/`max`
- `settings.compaction.*` — enabled, strategy, autoContinue
- `settings.eval.py` / `eval.js`
- `settings.memory.backend` — `off`/`local`/`hindsight`/`mnemopi`
- `settings.power.sleepPrevention`
- `settings.github.enabled`
- `settings.personality` — `default`/`friendly`/`pragmatic`/`none`
- `settings.ask.notify`, `settings.completion.notify`
- `settings.webSearch.enabled`, `settings.browser.enabled`, `settings.fetch.enabled`
- `settings.todo.enabled`, `settings.todo.reminders`
- `settings.edit.mode`, `settings.edit.fuzzyMatch`
- `settings.git.enabled`
- `settings.temperature`, `settings.topP`, `settings.topK`

### Freeform settings

Any setting from omp's [settings-schema.ts](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/src/config/settings-schema.ts) not covered by a typed option can be set via the freeform attrset:

```nix
programs.omp.settings = {
  # Typed option
  personality = "pragmatic";
  # Freeform — passed through to config.yml
  "ttsr.enabled" = true;
  "snapcompact.systemPrompt" = "none";
  "providers.tinyModel" = "online";
};
```

## Auto-Update

The [update workflow](./.github/workflows/update.yml) runs every 6 hours:

1. Checks the [GitHub releases API](https://api.github.com/repos/can1357/oh-my-pi/releases/latest) for the latest `vX.Y.Z` tag
2. Compares with the version in `pkgs/omp/sources.json`
3. If newer: prefetches source/cargo/bun hashes via `nix-prefetch-url` and FOD builds
4. Updates `sources.json` and `flake.lock`
5. Creates a PR via `peter-evans/create-pull-request`
6. Enables auto-merge (`gh pr merge --auto --squash`)

The [build workflow](./.github/workflows/build.yml) runs on every PR with a matrix of `ubuntu-latest` and `macos-latest`, verifying `nix build .#omp` and `./result/bin/omp --version`.

## License

MIT — same as [oh-my-pi](https://github.com/can1357/oh-my-pi).
