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
      # One system, stated plainly. Add more by mapping over a list if this
      # project ever has to build somewhere else.
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
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
    };
}
