{
  description = "Personal developer toolbox devShell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    npm-chck.url = "github:FredSystems/npm-chck";

    precommit-base = {
      url = "github:FredSystems/pre-commit-checks";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      rust-overlay,
      precommit-base,
      npm-chck,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        preCommit = precommit-base.lib.mkCheck {
          inherit system;
          src = ./.;

          extraExcludes = [
            "secrets.yaml"
            "tsconfig.json"
          ];
        };

        # Tools only, with no shellHook. Safe to enter from any directory:
        #   nix develop ~/GitHub/fred-dev-tools#tools -c zsh
        # Keep the pre-commit hook out of this shell. It installs git hooks
        # and a .pre-commit-config.yaml symlink into whatever repo the
        # current directory belongs to, which would clobber other projects.
        toolsShell = pkgs.mkShell {
          name = "dev-tools";

          # Libraries that -sys crates link against. These go in buildInputs
          # rather than packages so pkg-config's setup hook adds their .pc
          # files to PKG_CONFIG_PATH.
          buildInputs = with pkgs; [
            openssl
          ];

          packages = with pkgs; [
            # --- C/C++ toolchain and build systems ---
            clang
            gcc
            gnumake
            cmake
            ninja
            pkg-config
            lldb

            # --- Linters and formatters ---
            actionlint
            hadolint
            shellcheck
            shfmt
            taplo
            typos

            # --- Nix ---
            deadnix
            nixfmt
            statix

            # --- General utilities ---
            hyperfine
            jq
            just
            tokei
            yq

            # --- Rust ---
            # rust-src and rust-analyzer come from the same toolchain as
            # rustc, so rust-analyzer's proc-macro server always matches
            # the compiler that built the macros.
            (rust-bin.stable.latest.default.override {
              extensions = [
                "rust-analyzer"
                "rust-src"
              ];
            })
            bacon
            cargo-audit
            cargo-deny
            cargo-machete
            cargo-nextest

            # --- Node / TypeScript ---
            # Pinned to a major on purpose; do NOT use `nodejs_latest`.
            # That alias floats to whatever major nixpkgs has newest,
            # which is routinely one Hydra does not build: on both the
            # pin below and current nixos-unstable it resolves to
            # nodejs 26.9.0, which is absent from cache.nixos.org and
            # fails its own test suite
            # (parallel/test-fs-cp-async-file-modes.mjs). CI therefore
            # spent ~2h building Node from source and then failed.
            # nodejs_24 is the nixpkgs default major and is cached.
            nodejs_24
            biome
            npm-chck.packages.${system}.default
            pnpm
            prettier
            typescript

            # --- Python ---
            pyright
            python3
            ruff
            uv
          ];
        };
      in
      {
        # --- checks must be an attrset ---
        checks = {
          pre-commit-check = preCommit;
        };

        # --- devShell must be a derivation ---
        devShells = {
          tools = toolsShell;

          # For working on this repo: the tools plus the pre-commit hook.
          default = pkgs.mkShell {
            name = "dev-tools";
            inputsFrom = [ toolsShell ];

            shellHook = ''
              echo "🧰 Entered dev-tools shell for ${system}"
              ${preCommit.shellHook}
            '';
          };
        };
      }
    );
}
