{
  description = "Python development environment";

  # `nixpkgs`, not `github:NixOS/nixpkgs/nixos-unstable`: an indirect ref,
  # resolved through the flake registry, which modules/nixos/development.nix
  # points at the exact rev this machine is built from. The store paths that
  # come out of it are the ones already in /nix/store, so the first
  # `direnv allow` has nothing to fetch. Spelled as a URL, a project locks
  # against whatever nixos-unstable is that afternoon and re-downloads a
  # whole second stdenv to say the same thing.
  #
  # It's also what makes the claim in this flake's parent true — that the
  # machines and the shells they build move on one `nix flake update`.
  #
  # On a machine without that registry entry it falls back to the global one
  # (nixpkgs-unstable) and still works. Either way the answer lands in
  # flake.lock, so the project stays reproducible for whoever clones it.
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
      devShells = forEachSystem (
        pkgs:
        let
          # The interpreter this project runs on. Every minor version's
          # *interpreter* is built by Hydra and comes out of the binary cache,
          # so changing this line is free.
          #
          # Its *library set* is not free, and that distinction is the whole
          # reason this file looks the way it does. nixpkgs only builds the
          # Python package sets it marks `recurseIntoAttrs` in all-packages.nix
          # — today python313Packages and python314Packages, the latter being
          # the default `python3Packages`. Every other set (python311Packages,
          # python312Packages, python315Packages) evaluates perfectly well and
          # is simply never built by Hydra, so none of it is in cache.nixos.org
          # and every one of its derivations is compiled locally, test suites
          # and all.
          #
          # 3.13 is the default here because it's on the built list, which keeps
          # `python.withPackages` cheap as well. Moving to `pkgs.python3` (3.14)
          # is equally cheap. Moving to an older one costs nothing *by itself* —
          # see the note on pylsp below for the part that used to make it
          # expensive — but check the list before asking that set for a library.
          python = pkgs.python313;

          # The language server, taken from the default package set on purpose
          # rather than from `python` above.
          #
          # This is the line that made the template slow. It used to read
          # `python.pkgs.python-lsp-server` with `python = pkgs.python312`, and
          # python312Packages lost its `recurseIntoAttrs` upstream in November
          # 2025 — so from that day on, entering this shell meant building pylsp
          # from source, and with it every one of its check inputs: numpy,
          # pandas, matplotlib, and the full optional-linter set (pylint, rope,
          # black, yapf, autopep8, flake8, ...). Minutes of compiling, on a
          # first `cd` into the project and again after every `nix flake
          # update`.
          #
          # Decoupling the two costs nothing. pylsp is a tool this project never
          # imports, and jedi resolves completions from $VIRTUAL_ENV — the venv
          # the shellHook activates — rather than from the interpreter pylsp
          # itself happens to be running on, so it reads a 3.12 project
          # correctly while running on 3.14. The version above stays a free
          # choice.
          pylsp = pkgs.python3Packages.python-lsp-server;
        in
        {
          default = pkgs.mkShell {
            packages = [
              python
              pkgs.uv # resolver and venv manager; `pip` also works
              pkgs.ruff # linter + formatter
              pylsp
            ];

            # Point uv at the interpreter above and stop it reaching for its
            # own. Left alone, uv downloads a standalone CPython the first time
            # it wants one — a fetch on the critical path, and a different
            # Python from the one pinned here, which rather defeats pinning it.
            env = {
              UV_PYTHON = "${python}/bin/python";
              UV_PYTHON_DOWNLOADS = "never";
            };

            shellHook = ''
              # A venv, so pip/uv installs land in the project rather than
              # trying to write into the read-only store. Nix supplies the
              # interpreter; PyPI supplies the libraries.
              #
              # If you'd rather have every dependency come from nixpkgs instead,
              # delete this hook and list them as `python.withPackages (ps: [
              # ps.requests ps.numpy ])` in packages above — reading the note on
              # built package sets by `python` first.
              #
              # Rebuilt when it doesn't answer with the interpreter above. A
              # venv records an absolute path to the Python that made it, so
              # once that store path moves — `nix flake update`, or the weekly
              # nix-collect-garbage in base.nix taking the old one with it — a
              # venv left in place fails every command with a missing loader
              # rather than with anything that explains itself. An empty
              # left-hand side is the no-venv-yet case and the broken case at
              # once.
              #
              # A venv that already answers correctly is left entirely alone,
              # which is the point of comparing rather than just rebuilding: `rm
              # -rf` here only ever runs on one that couldn't be used anyway.
              if [ "$(.venv/bin/python -V 2>/dev/null)" != "$(${python}/bin/python -V)" ]; then
                rm -rf .venv
                uv venv --python "${python}/bin/python" .venv
              fi
              source .venv/bin/activate

              # The libraries that venv is for, installed on the way in, so a
              # fresh clone is ready to run rather than ready to be set up.
              #
              # Which files count is uv's own division and not a guess: a
              # uv.lock, or a pyproject.toml with a [project] table, is a
              # packaged project, and `uv sync` installs precisely what the lock
              # says (writing the lock first if it isn't there). Anything else
              # is requirements files, and they go in together in one resolve so
              # a dev pin can't quietly contradict the runtime one.
              #
              # The stamp inside the venv is what makes this cheap enough to sit
              # in a hook that runs at every prompt: touched only after an
              # install that worked, so the ordinary case — nothing edited since
              # — is a handful of `test` builtins and no subprocess at all. The
              # rebuild above takes the stamp with it, which is the point. A new
              # venv is an empty one, and everything has to go back into it.
              #
              # DEV_NO_INSTALL=1 in the environment turns it off, for a project
              # whose dependencies are being managed by hand.
              stamp=.venv/.dev-shell-deps
              stale=""
              for manifest in uv.lock pyproject.toml requirements.txt requirements-dev.txt; do
                if [ -f "$manifest" ] && { [ ! -e "$stamp" ] || [ "$manifest" -nt "$stamp" ]; }; then
                  stale=1
                fi
              done

              if [ -n "$stale" ] && [ -z "''${DEV_NO_INSTALL:-}" ]; then
                if [ -f uv.lock ] || grep -qs '^\[project\]' pyproject.toml; then
                  echo "installing dependencies with uv sync..."
                  if uv sync; then
                    touch "$stamp"
                  else
                    echo "uv sync failed; the shell is still here. Fix it and rerun it by hand." >&2
                  fi
                else
                  args=()
                  for manifest in requirements.txt requirements-dev.txt; do
                    if [ -f "$manifest" ]; then
                      args+=(-r "$manifest")
                    fi
                  done
                  if [ ''${#args[@]} -gt 0 ]; then
                    echo "installing dependencies from the requirements files..."
                    if uv pip install "''${args[@]}"; then
                      touch "$stamp"
                    else
                      echo "uv pip install failed; the shell is still here. Fix it and rerun it by hand." >&2
                    fi
                  fi
                fi
              fi
              unset stamp stale manifest args
            '';
          };
        }
      );
    };
}
