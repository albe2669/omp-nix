# NixOS module for oh-my-pi (omp).
# Minimal: installs the omp package system-wide. omp is user-scoped, so
# config (config.yml, models.yml) is managed via the home-manager module.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.omp;
in {
  options.programs.omp = {
    enable = mkEnableOption "oh-my-pi (omp) — install the omp binary system-wide";

    package = mkOption {
      type = types.package;
      default = pkgs.omp;
      defaultText = literalExpression "pkgs.omp";
      description = "The omp package to use.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [cfg.package];
  };
}
