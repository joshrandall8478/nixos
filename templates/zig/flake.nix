{
  description = "Zig development environment";

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
            # Both unsuffixed, which here means the newest: nixpkgs points
            # `zig` and `zls` at 0.16 and keeps that pair in step on purpose.
            # Take the version numbers if you pin one — `zig_0_15` with `zls`
            # is the mistake this arrangement exists to prevent. zls parses the
            # language rather than asking the compiler, so a zls built for a
            # different release reports syntax it doesn't recognise as errors,
            # in a file that compiles perfectly well.
            zig
            zls

            # `zig fmt` is part of the compiler, so there is no separate
            # formatter to add here.
          ];

          shellHook = ''
            # Zig keeps two caches and only one of them is already in the right
            # place. The local one defaults to ./.zig-cache and holds this
            # project's build artifacts; the global one defaults to
            # ~/.cache/zig and holds the packages build.zig.zon fetches, keyed
            # by hash. Moving the second one in here is the same bargain as
            # GOPATH in the go template — no longer shared between projects,
            # and in exchange removing the directory removes the lot and the
            # stamp below has an obvious place to live. Drop the line to go
            # back to sharing it.
            export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-global-cache"

            # The packages build.zig.zon declares, fetched on the way in.
            # `zig build` fetches them itself at the first build; `--fetch`
            # does that part and stops, which moves the wait to a prompt that
            # expects one. It runs build.zig to find out what is needed, so it
            # wants both files — and `--fetch=all` is the variant that also
            # takes the lazy dependencies, i.e. the ones only some build
            # options ask for.
            #
            # The stamp keeps it off the critical path: touched only after a
            # fetch that worked, so the ordinary case — neither file edited
            # since — is a handful of `test` builtins and no subprocess.
            # Nothing happens without a build.zig.zon, since `dev-init zig` in
            # an empty directory is a shell to run `zig init` in and not yet a
            # project, and DEV_NO_INSTALL=1 in the environment turns it off.
            stamp="$ZIG_GLOBAL_CACHE_DIR/.dev-shell-deps"
            if [ -f build.zig.zon ] && [ -f build.zig ] && [ -z "''${DEV_NO_INSTALL:-}" ] && {
              [ ! -e "$stamp" ] || [ build.zig.zon -nt "$stamp" ] || [ build.zig -nt "$stamp" ]
            }; then
              echo "fetching packages with zig build --fetch..."
              if zig build --fetch; then
                mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
                touch "$stamp"
              else
                echo "zig build --fetch failed; the shell is still here. Fix it and rerun it by hand." >&2
              fi
            fi
            unset stamp
          '';
        };
      });
    };
}
