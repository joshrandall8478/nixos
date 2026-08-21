{
  description = ".NET development environment";

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
      devShells = forEachSystem (
        pkgs:
        let
          # The SDK, named by major version on purpose. `pkgs.dotnet-sdk` with
          # no suffix is still 8.0 — an LTS nixpkgs has not moved the bare name
          # off — so a template that means 10 has to say 10. `dotnet-sdk_10` is
          # an alias for `dotnetCorePackages.sdk_10_0`, the one nixpkgs builds
          # from Microsoft's source (VMR) tree rather than repackaging their
          # tarball; the tarball is beside it as `sdk_10_0-bin` if you ever need
          # to compare against a stock install.
          #
          # Targeting more than one framework at once needs
          #
          #   (with pkgs.dotnetCorePackages; combinePackages [ sdk_10_0 sdk_9_0 ])
          #
          # in place of this, and not two entries in `packages`. A dotnet
          # installation is a single directory that expects to be able to
          # install further runtimes next to itself, which it cannot do when
          # that directory is in the store — so the composition has to happen at
          # build time. The first SDK listed is the one whose `dotnet` you get.
          dotnet = pkgs.dotnet-sdk_10;

          # A language server that speaks plain stdio LSP, which is what
          # anything outside VS Code wants — on the platforms nixpkgs will
          # hand one over, which is not all of them.
          #
          # csharp-ls is that server everywhere except Apple Silicon, where
          # nixpkgs marks it `badPlatforms`: it builds there and then dies on
          # the first request (razzmatazz/csharp-language-server#211). Naming
          # it unconditionally would make this shell an evaluation error on
          # that machine — "Package 'csharp-ls' is not available on the
          # requested hostPlatform" — so the Mac would get no shell at all
          # rather than a shell missing one editor integration. Asking
          # `availableOn` rather than matching on the system by hand means the
          # day nixpkgs drops the mark, the server comes back on its own.
          #
          # `roslyn-ls` is the alternative to swap in there: the same server
          # the official C# extension ships, more capable and considerably
          # heavier to wire up — the editor has to launch
          # `Microsoft.CodeAnalysis.LanguageServer --stdio` rather than a
          # binary named after the language. VS Code needs neither; its
          # extension brings its own copy.
          languageServer =
            if pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.csharp-ls then
              [ pkgs.csharp-ls ]
            else
              [ ];
        in
        {
          default = pkgs.mkShell {
            packages = [
              dotnet

              # `dotnet format` is part of the SDK, so there is no separate
              # formatter to add here.
            ]
            ++ languageServer;

            env = {
              # Nothing in nixpkgs' SDK sets this, and it isn't the package root
              # either: `bin/dotnet` is a symlink into `share/dotnet`, and it's
              # that inner directory — the one holding `sdk/`, `shared/` and
              # `packs/` — that MSBuild, the language server and any global tool
              # mean when they ask for DOTNET_ROOT.
              DOTNET_ROOT = "${dotnet}/share/dotnet";

              # A shellHook that runs at every prompt cannot afford a
              # banner, and the telemetry notice is printed by the first
              # `dotnet` in a fresh DOTNET_CLI_HOME — which, given the line
              # below, is every new clone.
              DOTNET_CLI_TELEMETRY_OPTOUT = "1";
              DOTNET_NOLOGO = "1";
            };

            shellHook = ''
              # The two directories the SDK writes to outside the project,
              # moved inside it: the CLI's own state (first-run sentinel,
              # global tools) and the NuGet package cache. Same bargain as
              # GOPATH in the go template — the cache is no longer shared
              # between projects, and in exchange removing the directory
              # removes the lot, nothing lands in $HOME, and the stamp below
              # has an obvious place to live. Drop the NUGET_PACKAGES line to
              # go back to a shared ~/.nuget.
              export DOTNET_CLI_HOME="$PWD/.dotnet"
              export NUGET_PACKAGES="$PWD/.nuget"

              # The packages this project references, restored on the way in, so
              # a fresh clone is ready to build rather than ready to be set up.
              #
              # `dotnet restore` with no argument wants exactly one project or
              # solution file in the current directory to work on, and that is
              # the same question as "is this directory a .NET project at all" —
              # so the loop below answers both at once, and a tree whose
              # projects all live under src/ with no solution at the root is
              # correctly left alone. Nothing is lost when it is: unlike npm,
              # the .NET build restores implicitly, so a manifest this loop
              # doesn't watch costs the first `dotnet build` a restore and
              # nothing else.
              #
              # The globs are what make that cheap. With nullglob off — bash's
              # default, and mkShell doesn't change it — a pattern that matches
              # nothing stays literal, `[ -f '*.sln' ]` is simply false, and the
              # ordinary entry is a handful of `test` builtins and no
              # subprocess.
              #
              # The stamp is touched only after a restore that worked, so a
              # failure retries next time rather than recording a half-filled
              # cache as done, and emptying .nuget/ takes it along.
              # DEV_NO_INSTALL=1 in the environment turns it off.
              stamp="$NUGET_PACKAGES/.dev-shell-deps"
              project=""
              stale=""
              for manifest in *.sln *.slnx *.csproj *.fsproj *.vbproj \
                Directory.Packages.props Directory.Build.props \
                global.json nuget.config NuGet.config packages.lock.json; do
                [ -f "$manifest" ] || continue
                case "$manifest" in
                  *.sln | *.slnx | *.csproj | *.fsproj | *.vbproj) project=1 ;;
                esac
                if [ ! -e "$stamp" ] || [ "$manifest" -nt "$stamp" ]; then
                  stale=1
                fi
              done

              if [ -n "$project" ] && [ -n "$stale" ] && [ -z "''${DEV_NO_INSTALL:-}" ]; then
                echo "restoring packages with dotnet restore..."
                # Plain `restore`, not `--locked-mode`: that one fails outright
                # when packages.lock.json and the project file disagree, which
                # is the ordinary state of a branch that has just added a
                # package. It belongs in CI, not on a `cd`.
                if dotnet restore; then
                  mkdir -p "$NUGET_PACKAGES"
                  touch "$stamp"
                else
                  echo "dotnet restore failed; the shell is still here. Fix it and rerun it by hand." >&2
                fi
              fi
              unset stamp project stale manifest
            '';
          };
        }
      );
    };
}
