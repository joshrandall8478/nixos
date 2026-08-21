{
  description = "Rust development environment";

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
      # The systems this shell is built for. `nix develop` and direnv both
      # read `devShells.<the system they are running on>.default`, so a
      # machine missing from this list is told the flake has no dev shell for
      # it rather than given one — while a system that is listed and never
      # used costs a line here and nothing else, since nothing is built until
      # something asks for it by name.
      #
      # x86_64-darwin, the Intel Mac, is absent and is not a line anyone can
      # add: nixpkgs 26.11 dropped that platform, so asking it for
      # x86_64-darwin throws before a single package here is named. Its 26.05
      # branch still carries it, with fixes promised to the end of 2026 — so
      # an Intel Mac is a different `inputs.nixpkgs` rather than a fourth
      # entry in this list.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            # nixpkgs' stable toolchain. For a pinned or nightly one, add the
            # `rust-overlay` flake as an input and take rustc from there.
            cargo
            rustc
            rustfmt
            clippy
            rust-analyzer

            # Most crates that link C libraries need these two to find them.
            pkg-config
          ];

          # rust-analyzer looks for the standard library source here; nixpkgs
          # ships it, but not where the default lookup expects.
          RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

          # Native libraries a crate links against go here, e.g.
          # buildInputs = with pkgs; [ openssl sqlite ];
          #
          # On macOS the Apple frameworks are not among them: one SDK comes
          # with the stdenv and covers the frameworks a crate normally links
          # against, so `-sys` crates build with this list empty. The
          # exception is a crate wanting something newer than the default SDK
          # carries, which is `pkgs.apple-sdk_15` (or the version its docs
          # name) added here — not a framework package. The old
          # `darwin.apple_sdk.frameworks.*` attributes that older Rust
          # examples pass in buildInputs are gone.
          buildInputs = [ ];

          shellHook = ''
            # Fetch the crates this project locks on the way in, so the first
            # `cargo build` is a compile rather than a compile behind a
            # download. cargo fetches on demand by itself; this only moves the
            # wait to a prompt that expects one, and writes Cargo.lock if the
            # project doesn't have one yet.
            #
            # The stamp keeps it off the critical path: touched only after a
            # fetch that worked, so the ordinary case — the manifest and lock
            # untouched since — is a handful of `test` builtins and no
            # subprocess.
            # `cargo clean` takes the stamp with it, which costs one fetch
            # against a registry cache that is still warm.
            #
            # Nothing happens without a Cargo.toml, since `dev-init rust` in an
            # empty directory leaves a shell to run `cargo init` in, not a
            # crate. DEV_NO_INSTALL=1 in the environment turns it off.
            stamp=target/.dev-shell-deps
            if [ -f Cargo.toml ] && [ -z "''${DEV_NO_INSTALL:-}" ] && {
              [ ! -e "$stamp" ] || [ Cargo.toml -nt "$stamp" ] || [ Cargo.lock -nt "$stamp" ]
            }; then
              echo "fetching crates with cargo fetch..."
              if cargo fetch; then
                mkdir -p target
                touch "$stamp"
              else
                echo "cargo fetch failed; the shell is still here. Fix it and rerun it by hand." >&2
              fi
            fi
            unset stamp
          '';
        };
      });
    };
}
