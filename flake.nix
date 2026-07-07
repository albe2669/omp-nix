{
  description = "oh-my-pi (omp) — AI coding agent for the terminal, packaged for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    # Systems with native GitHub Actions runners: x86_64-linux, aarch64-darwin.
    # We also expose x86_64-darwin and aarch64-linux for evaluation and
    # cross-building, but CI only builds the two with hosted runners.
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    overlay = final: prev: {
      omp = final.callPackage ./pkgs/omp {};
    };
  in
    {
      overlays.default = overlay;

      homeModules.default = import ./modules/home-manager.nix;
      homeModules.omp = self.homeModules.default;

      nixosModules.default = import ./modules/nixos.nix;
      nixosModules.omp = self.nixosModules.default;
    }
    // (flake-utils.lib.eachSystem supportedSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [overlay];
        };
      in {
        packages = {
          omp = pkgs.omp;
          default = pkgs.omp;
        };

        apps.default = {
          type = "app";
          program = "${pkgs.omp}/bin/omp";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            alejandra
            nix-prefetch
            jq
          ];
        };

        formatter = pkgs.alejandra;
      }
    ));
}
