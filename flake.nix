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
      in
      {
        # --- checks must be an attrset ---
        checks = {
          pre-commit-check = preCommit;
        };

        # --- devShell must be a derivation ---
        devShells.default = pkgs.mkShell {
          name = "dev-tools";

          packages = with pkgs; [
            clang
            gcc
            hadolint
            gnumake
            cmake
            ninja
            shellcheck
            typos

            jq
            yq

            pkg-config

            rust-bin.stable.latest.default

            nodejs_latest
            prettier
            npm-chck.packages.${system}.default

            python3
          ];

          shellHook = ''
            echo "🧰 Entered dev-tools shell for ${system}"
            ${preCommit.shellHook}
          '';
        };
      }
    );
}
