#!/usr/bin/env bash
# Update omp version and hashes in pkgs/omp/sources.json.
#
# Usage:
#   ./.github/scripts/update.sh                              # Update to latest version
#   ./.github/scripts/update.sh --check                      # Exit 1 if update available, 0 if up-to-date
#   ./.github/scripts/update.sh --no-bun-checksum            # Update everything except bunChecksums
#   ./.github/scripts/update.sh --bun-checksum-only <system>  # Only compute bunChecksum for the given system
set -euo pipefail

readonly REPO_OWNER="can1357"
readonly REPO_NAME="oh-my-pi"
readonly SOURCES_FILE="pkgs/omp/sources.json"
readonly BUN_REPO="oven-sh/bun"

log_info()  { echo -e "\033[0;32m[INFO]\033[0m $1"; }
log_warn()  { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

# ── Helpers ───────────────────────────────────────────────────────────────

get_current_version() {
    jq -r '.version' "$SOURCES_FILE"
}

get_latest_version() {
    curl -sf \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" \
    | jq -r '.tag_name | ltrimstr("v")'
}

get_bun_version() {
    jq -r '.bunVersion' "$SOURCES_FILE"
}

# Prefetch the fetchFromGitHub tarball hash (Nix SRI format).
prefetch_src_hash() {
    local version="$1"
    local url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/tags/v${version}.tar.gz"
    nix store prefetch-file --json --hash-type sha256 --unpack "$url" 2>/dev/null \
    | jq -r '.hash'
}

# Prefetch a single bun source ZIP hash.
prefetch_bun_src_hash() {
    local bun_version="$1"
    local bun_src_url="$2"
    local url="https://github.com/${BUN_REPO}/releases/download/bun-v${bun_version}/${bun_src_url}"
    nix store prefetch-file --json --hash-type sha256 "$url" 2>/dev/null \
    | jq -r '.hash'
}


# Compute the bunDeps FOD checksum by building with a fake hash and reading
# the "got" hash from the error output. This is standard nixpkgs FOD practice.
compute_bun_deps_checksum() {
    local system="$1"
    local nix_file="$2"

    # Set a fake hash to force a hash mismatch error, which reveals the real hash.
    local tmp_sources=$(mktemp)
    jq --arg sys "$system" '.platforms[$sys].bunChecksum = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="' \
        "$SOURCES_FILE" > "$tmp_sources"

    # Build the bunDeps FOD and capture the error output containing the correct hash.
    local output
    output=$(nix build --impure --expr "
        { pkgs ? import (builtins.getFlake (toString ./.)).inputs.nixpkgs {} }:
        let
          lib = pkgs.lib;
          stdenvNoCC = pkgs.stdenvNoCC;
          sources = builtins.fromJSON (builtins.readFile ./pkgs/omp/sources.json);
          platformSpecific = sources.platforms.${"\"$system\""};
          bunVersion = sources.bunVersion;
          bunSrc = pkgs.fetchurl {
            url = \"https://github.com/oven-sh/bun/releases/download/bun-v\${bunVersion}/\${platformSpecific.bunSrcUrl}\";
            hash = platformSpecific.bunSrcHash;
          };
          bun = pkgs.bun.overrideAttrs (_: { version = bunVersion; src = bunSrc; });
        in stdenvNoCC.mkDerivation {
          name = \"omp-bun-deps-\${sources.version}\";
          src = pkgs.fetchFromGitHub {
            owner = \"can1357\";
            repo = \"oh-my-pi\";
            rev = \"v\${sources.version}\";
            hash = sources.srcHash;
          };
          nativeBuildInputs = [bun];
          buildPhase = ''export HOME=\$(mktemp -d); bun install --frozen-lockfile --no-progress'';
          installPhase = ''rm -rf node_modules/@oh-my-pi; rm -f node_modules/robomp-web; find node_modules/.bin -maxdepth 1 -type l ! -exec test -e {} \; -delete; cp -r node_modules \$out'';
          outputHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";
          outputHashMode = \"recursive\";
          outputHashAlgo = \"sha256\";
        }
    " 2>&1 || true)

    # Extract the "got:" hash from the error output.
    local hash
    hash=$(echo "$output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1)
    if [ -z "$hash" ]; then
        log_error "Failed to compute bun deps checksum for $system"
        echo "$output" >&2
        return 1
    fi
    echo "$hash"
}

# ── Main ───────────────────────────────────────────────────────────────────

main() {
    local check_only=false
    local no_bun_checksum=false
    local bun_checksum_only=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check) check_only=true; shift ;;
            --no-bun-checksum) no_bun_checksum=true; shift ;;
            --bun-checksum-only)
                shift
                [[ $# -gt 0 ]] || { log_error "--bun-checksum-only requires a system argument"; exit 1; }
                bun_checksum_only="$1"
                shift
                ;;
            --help)
                echo "Usage: $0 [--check|--no-bun-checksum|--bun-checksum-only <system>]"
                echo "  --check                  Only check if update is available (exit 1 if yes)"
                echo "  --no-bun-checksum        Update everything except platform bunChecksums"
                echo "  --bun-checksum-only SYS  Only compute bunChecksum for system SYS"
                exit 0
                ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # --bun-checksum-only: compute bunChecksum for a single system and exit.
    # This is used by the matrix job in CI — each runner computes only its
    # own platform's hash (bunChecksum is platform-specific because
    # node_modules contains platform-native binaries).
    if [ -n "$bun_checksum_only" ]; then
        log_info "Computing bunChecksum for $bun_checksum_only..."
        local bun_checksum
        bun_checksum=$(compute_bun_deps_checksum "$bun_checksum_only" "$SOURCES_FILE" 2>&1 || true)
        if [ -n "$bun_checksum" ]; then
            log_info "  $bun_checksum_only bunChecksum: $bun_checksum"
            tmp=$(mktemp)
            jq --arg sys "$bun_checksum_only" --arg h "$bun_checksum" \
                '.platforms[$sys].bunChecksum = $h' "$SOURCES_FILE" > "$tmp"
            mv "$tmp" "$SOURCES_FILE"
        else
            log_error "Failed to compute bunChecksum for $bun_checksum_only"
            exit 1
        fi
        exit 0
    fi

    local current_version latest_version
    current_version=$(get_current_version)
    latest_version=$(get_latest_version)

    if [ -z "$latest_version" ]; then
        log_error "Could not determine latest version from GitHub releases"
        exit 1
    fi

    log_info "Current version: $current_version"
    log_info "Latest version:  $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
        log_info "Already up to date!"
        exit 0
    fi

    if [ "$check_only" = true ]; then
        log_info "Update available: $current_version → $latest_version"
        exit 1
    fi

    log_info "Updating to $latest_version..."

    # 1. Update version in sources.json
    local tmp=$(mktemp)
    jq --arg v "$latest_version" '.version = $v' "$SOURCES_FILE" > "$tmp"
    mv "$tmp" "$SOURCES_FILE"

    # 2. Prefetch src hash
    log_info "Fetching source tarball hash..."
    local src_hash
    src_hash=$(prefetch_src_hash "$latest_version")
    if [ -z "$src_hash" ]; then
        log_error "Failed to fetch source hash"
        exit 1
    fi
    log_info "  srcHash: $src_hash"
    tmp=$(mktemp)
    jq --arg h "$src_hash" '.srcHash = $h' "$SOURCES_FILE" > "$tmp"
    mv "$tmp" "$SOURCES_FILE"

    # 3. Prefetch bun source hashes per platform
    local bun_version
    bun_version=$(get_bun_version)
    local systems=("x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin")

    for system in "${systems[@]}"; do
        local bun_src_url
        bun_src_url=$(jq -r --arg sys "$system" '.platforms[$sys].bunSrcUrl' "$SOURCES_FILE")
        log_info "Fetching bun src hash for $system ($bun_src_url)..."
        local bun_src_hash
        bun_src_hash=$(prefetch_bun_src_hash "$bun_version" "$bun_src_url")
        if [ -z "$bun_src_hash" ]; then
            log_error "Failed to fetch bun src hash for $system"
            exit 1
        fi
        log_info "  $system bunSrcHash: $bun_src_hash"
        tmp=$(mktemp)
        jq --arg sys "$system" --arg h "$bun_src_hash" \
            '.platforms[$sys].bunSrcHash = $h' "$SOURCES_FILE" > "$tmp"
        mv "$tmp" "$SOURCES_FILE"
    done

    # 4. Compute bunDeps FOD checksums — only when not skipped.
    # bunChecksum is platform-specific (node_modules contains platform-native
    # binaries like @biomejs/cli-linux-x64). In CI, the --no-bun-checksum
    # flag skips this step; a separate matrix job computes each platform's
    # hash via --bun-checksum-only.
    local current_system
    current_system=$(nix eval --impure --expr 'builtins.currentSystem' 2>/dev/null || echo "")
    if [ "$no_bun_checksum" = false ] && [ -n "$current_system" ]; then
        log_info "Computing bun deps checksum for $current_system..."
        local bun_checksum
        bun_checksum=$(compute_bun_deps_checksum "$current_system" "$SOURCES_FILE" 2>/dev/null || true)
        if [ -n "$bun_checksum" ]; then
            log_info "  $current_system bunChecksum: $bun_checksum"
            tmp=$(mktemp)
            jq --arg sys "$current_system" --arg h "$bun_checksum" \
                '.platforms[$sys].bunChecksum = $h' "$SOURCES_FILE" > "$tmp"
            mv "$tmp" "$SOURCES_FILE"
        else
            log_warn "Could not compute bun deps checksum for $current_system"
        fi
    fi

    # 5. Compute cargo hash (build the Rust FOD).
    # cargoHash is the hash of the cargo vendor directory — platform-independent.
    if [ -n "$current_system" ]; then
        log_info "Computing cargo hash..."
        local cargo_output
        cargo_output=$(nix build --impure --expr "
            { pkgs ? import (builtins.getFlake (toString ./.)).inputs.nixpkgs {} }:
            let
              sources = builtins.fromJSON (builtins.readFile ./pkgs/omp/sources.json);
              src = pkgs.fetchFromGitHub {
                owner = \"can1357\";
                repo = \"oh-my-pi\";
                rev = \"v\${sources.version}\";
                hash = sources.srcHash;
              };
            in pkgs.rustPlatform.buildRustPackage {
              pname = \"pi-natives\";
              version = sources.version;
              inherit src;
              cargoHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";
              env.RUSTC_BOOTSTRAP = \"1\";
              cargoBuildFlags = [\"--package\" \"pi-natives\" \"--lib\"];
              nativeBuildInputs = [pkgs.nodejs pkgs.pkg-config];
              buildInputs = [pkgs.openssl];
              doCheck = false;
            }
        " 2>&1 || true)
        local cargo_hash
        cargo_hash=$(echo "$cargo_output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1)
        if [ -n "$cargo_hash" ]; then
            log_info "  cargoHash: $cargo_hash"
            tmp=$(mktemp)
            jq --arg h "$cargo_hash" '.cargoHash = $h' "$SOURCES_FILE" > "$tmp"
            mv "$tmp" "$SOURCES_FILE"
        else
            log_error "Failed to compute cargo hash"
            exit 1
        fi
    fi

    log_info "Successfully updated omp from $current_version to $latest_version"
}

main "$@"
