{
  description = "Development environment";

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
          # Everything this project needs to build and run. `nix search nixpkgs
          # <name>` finds the attribute for a given tool.
          packages = with pkgs; [
            # git
            # gnumake
          ];

          # Runs on every entry into the shell — direnv included, so keep it
          # quiet and fast.
          shellHook = ''
            echo "dev shell: $(basename "$PWD")"

            # Where a bootstrap step goes, if this project has one. The
            # language templates each carry a real one — npm install, uv sync,
            # go mod download — and all of them have this shape, because a
            # hook that runs at every prompt can only afford to do the work
            # when something actually changed. A stamp file, touched after the
            # step succeeds, is what buys that; a failure is a message rather
            # than something that stops the shell from opening; and
            # DEV_NO_INSTALL=1 is the way out when the dependencies are being
            # managed by hand.
            #
            # if [ -f Makefile ] && [ -z "''${DEV_NO_INSTALL:-}" ] &&
            #    { [ ! -e .dev-shell-deps ] || [ Makefile -nt .dev-shell-deps ]; }; then
            #   if make deps; then touch .dev-shell-deps; fi
            # fi
          '';

          # Variables the project needs. These leave with the shell.
          # env.DATABASE_URL = "postgres://localhost/dev";
        };
      });
    };
}
