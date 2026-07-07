{
  pkgs,
  lib,
}: let
  sources = lib.importJSON ./omp/sources.json;
  bunVersion = sources.bunVersion;

  # omp requires bun >= 1.3.14; nixpkgs may ship an older version.
  # Override the bun derivation with the upstream ZIP for this platform.
  bunSrcs = {
    "aarch64-darwin" = pkgs.fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/${sources.platforms."aarch64-darwin".bunSrcUrl}";
      hash = sources.platforms."aarch64-darwin".bunSrcHash;
    };
    "x86_64-darwin" = pkgs.fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/${sources.platforms."x86_64-darwin".bunSrcUrl}";
      hash = sources.platforms."x86_64-darwin".bunSrcHash;
    };
    "aarch64-linux" = pkgs.fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/${sources.platforms."aarch64-linux".bunSrcUrl}";
      hash = sources.platforms."aarch64-linux".bunSrcHash;
    };
    "x86_64-linux" = pkgs.fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/${sources.platforms."x86_64-linux".bunSrcUrl}";
      hash = sources.platforms."x86_64-linux".bunSrcHash;
    };
  };

  bun-1-3-14 = pkgs.bun.overrideAttrs (_finalAttrs: _old: {
    version = bunVersion;
    src = bunSrcs.${pkgs.stdenv.hostPlatform.system};
  });
in {
  omp = pkgs.callPackage ./omp {
    bun = bun-1-3-14;
  };
}
