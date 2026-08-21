{
  description = "Gleam development environment";

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
            # The compiler, and the language server with it: `gleam lsp` is a
            # subcommand of this same binary, so unlike every other template
            # here there is no second package to add for editor support.
            gleam

            # The Erlang target's runtime — Gleam compiles to BEAM bytecode and
            # shells out to `erlc`, so this isn't optional for it — and rebar3,
            # which is what builds any Erlang dependency that arrives from Hex
            # with a rebar build of its own.
            #
            # Both taken from the same `beamPackages`, which is the shape of
            # the constraint rather than a stylistic preference: that set *is*
            # the one built against `beamPackages.erlang`, nixpkgs' default OTP
            # release (28). To move up an OTP release, change the set and take
            # both from it — `beam29Packages.erlang` with
            # `beam29Packages.rebar3` — because a rebar3 compiled for one
            # release standing next to another is a class of failure worth not
            # inviting. (A bare `erlang` still works and warns; it is now an
            # alias for the line below.)
            beamPackages.erlang
            beamPackages.rebar3

            # Gleam also compiles to JavaScript. For that target, add the
            # runtime named by `javascript.runtime` in gleam.toml — nodejs,
            # bun or deno — and nothing else changes.
            # nodejs
          ];

          shellHook = ''
            # Dependencies, downloaded on the way in, so a fresh clone is ready
            # to build rather than ready to be set up. `gleam build` would
            # fetch them itself at the first build; doing it here only moves
            # the wait to a prompt that expects one.
            #
            # There is nothing to redirect out of $HOME first, which is why
            # this template has no exports above it. Gleam already unpacks each
            # dependency into build/packages inside the project; what it keeps
            # in the user cache is the downloaded Hex tarballs, which is a
            # cache in the honest sense — deleting it costs a re-download and
            # nothing else. (It follows XDG_CACHE_HOME, and moving that for one
            # project would move it for every tool in the shell.)
            #
            # The stamp keeps this off the critical path: touched only after a
            # download that worked, so the ordinary case — gleam.toml and
            # manifest.toml untouched since — is a handful of `test` builtins
            # and no subprocess. `gleam clean` empties build/ and takes the
            # stamp with it, which is the intent. Nothing happens without a
            # gleam.toml, since `dev-init gleam` in an empty directory is a
            # shell to run `gleam new` in and not yet a project, and
            # DEV_NO_INSTALL=1 in the environment turns it off.
            stamp=build/.dev-shell-deps
            if [ -f gleam.toml ] && [ -z "''${DEV_NO_INSTALL:-}" ] && {
              [ ! -e "$stamp" ] || [ gleam.toml -nt "$stamp" ] || [ manifest.toml -nt "$stamp" ]
            }; then
              echo "downloading packages with gleam deps download..."
              if gleam deps download; then
                mkdir -p build
                touch "$stamp"
              else
                echo "gleam deps download failed; the shell is still here. Fix it and rerun it by hand." >&2
              fi
            fi
            unset stamp
          '';
        };
      });
    };
}
