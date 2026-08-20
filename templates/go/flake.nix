{
  description = "Go development environment";

  # An indirect ref, resolved through the flake registry, which
  # modules/nixos/development.nix pins to the exact rev this machine is built
  # from — so the shell resolves to store paths that are already here and the
  # first `direnv allow` fetches nothing. Anywhere else it falls back to the
  # global registry entry and still works; either way flake.lock records the
  # answer. See templates/python/flake.nix for the longer version.
  inputs.nixpkgs.url = "nixpkgs";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          go
          gopls
          gotools # goimports and friends
          golangci-lint
        ];

        shellHook = ''
          # Keep the module cache and `go install` output inside the project
          # rather than in ~/go, so removing the directory removes the lot.
          export GOPATH="$PWD/.go"
          export PATH="$GOPATH/bin:$PATH"

          # Fill that cache on the way in. `go build` and `go test` each
          # fetch what they're missing anyway, so this buys no capability —
          # what it buys is the download happening here, at a prompt that is
          # expecting to wait, rather than in the middle of the first build
          # or, worse, the first test run.
          #
          # The stamp keeps it off the critical path: touched only after a
          # download that worked, so the ordinary case — go.mod and go.sum
          # untouched since — is a handful of `test` builtins and no
          # subprocess.
          # Emptying .go/ takes the stamp with it, which is the intent.
          # Nothing happens without a go.mod, and DEV_NO_INSTALL=1 in the
          # environment turns it off.
          stamp="$GOPATH/.dev-shell-deps"
          if [ -f go.mod ] && [ -z "''${DEV_NO_INSTALL:-}" ] && {
            [ ! -e "$stamp" ] || [ go.mod -nt "$stamp" ] || [ go.sum -nt "$stamp" ]
          }; then
            echo "fetching modules with go mod download..."
            if go mod download; then
              mkdir -p "$GOPATH"
              touch "$stamp"
            else
              echo "go mod download failed; the shell is still here. Fix it and rerun it by hand." >&2
            fi
          fi
          unset stamp
        '';
      };
    };
}
