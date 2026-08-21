{
  description = "Node.js development environment";

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
            nodejs_26
            pnpm # swap for `yarn`, or drop it and use the bundled npm
            typescript-language-server
          ];

          shellHook = ''
            # npm's global prefix, kept inside the project. Without this,
            # `npm i -g` tries to write into the store and fails.
            export NPM_CONFIG_PREFIX="$PWD/.npm-global"
            export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

            # node_modules, brought up to date on the way in, so a fresh clone
            # is ready to run rather than ready to be set up. Nix supplies the
            # runtime; npm supplies the libraries, exactly as it would outside
            # this shell.
            #
            # The stamp file is what makes this cheap enough to sit in a hook
            # that runs at every prompt. It's touched only after an install
            # that worked, so the ordinary case — nothing edited since — is a
            # handful of `test` builtins and no subprocess at all. Editing
            # package.json or a lockfile makes one of them newer than the
            # stamp; deleting node_modules takes the stamp with it. Either one
            # means install.
            #
            # Nothing happens without a package.json, since `dev-init node` in
            # an empty directory is a template and not yet a project, and an
            # install there would invent one. DEV_NO_INSTALL=1 in the
            # environment turns the whole thing off.
            stamp=node_modules/.dev-shell-deps
            if [ -f package.json ] && [ -z "''${DEV_NO_INSTALL:-}" ] && {
              [ ! -e "$stamp" ] ||
                [ package.json -nt "$stamp" ] ||
                [ package-lock.json -nt "$stamp" ] ||
                [ pnpm-lock.yaml -nt "$stamp" ] ||
                [ yarn.lock -nt "$stamp" ]
            }; then
              # The committed lockfile decides which package manager runs,
              # rather than what happens to be in `packages` above: cloning
              # someone else's repo shouldn't quietly reinstall their tree
              # with a different one.
              if [ -f pnpm-lock.yaml ]; then
                manager=pnpm
              elif [ -f yarn.lock ]; then
                manager=yarn
              else
                manager=npm
              fi

              if ! command -v "$manager" >/dev/null; then
                # yarn is the one that lands here — npm arrives with nodejs
                # and pnpm is in the list above.
                echo "$manager isn't in this shell; add it to packages in flake.nix." >&2
              else
                echo "installing dependencies with $manager..."
                # `install` rather than `npm ci` or `--frozen-lockfile`: those
                # are the CI commands, and they fail outright when the
                # lockfile and package.json disagree — which is the normal
                # state of a branch that has just added a dependency.
                if "$manager" install; then
                  touch "$stamp"
                else
                  echo "$manager install failed; the shell is still here. Fix it and rerun it by hand." >&2
                fi
              fi
            fi
            unset stamp manager
          '';
        };
      });
    };
}
