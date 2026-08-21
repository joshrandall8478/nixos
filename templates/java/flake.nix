{
  description = "Java development environment";

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
          # The JDK this project compiles and runs against, named by feature
          # version on purpose. `pkgs.jdk` with no suffix is 21 — nixpkgs keeps
          # the bare name on a settled LTS — so a template that means the newest
          # has to say 25. On Linux that is the newest OpenJDK nixpkgs builds
          # itself; `temurin-bin-26` is newer still but is Adoptium's prebuilt
          # tarball rather than a nixpkgs build, which is a different kind of
          # thing to depend on.
          #
          # On macOS the same attribute is already a prebuilt tarball: nixpkgs
          # has no darwin source build of OpenJDK, so every `jdkNN` there is
          # Azul's Zulu, patched and packaged — `jdk25` is `openjdk-25` on
          # Linux and `zulu-ca-jdk-25` there. It behaves the same from this
          # side: Zulu unpacks as a macOS .jdk bundle and then symlinks the
          # bundle's Contents/Home into the package root, so `jdk.home` below
          # is that root on either platform and JAVA_HOME needs no special
          # case. What it does mean is that the exact build is Azul's to
          # publish, so the two platforms can sit on different patch releases
          # — 25.0.4 on Linux against Zulu's 25.0.3 when this was written —
          # which matters only to a project that pins one.
          jdk = pkgs.jdk25;
        in
        {
          default = pkgs.mkShell {
            packages = [
              jdk

              # Both build tools, since which one a project uses is the
              # project's business and this template doesn't know yet. Delete
              # the one you don't need.
              #
              # `gradle` unsuffixed is still 8, which nixpkgs builds against JDK
              # 21 — a Gradle release supports the JVMs that existed when it
              # shipped and refuses the ones that didn't, so the two move
              # together. `gradle_9` is the one paired with the JDK above.
              pkgs.maven
              pkgs.gradle_9

              # Eclipse JDT, the language server behind Java support in every
              # editor that isn't IntelliJ.
              pkgs.jdt-language-server
            ];

            # The JDK's setup hook sets JAVA_HOME too, but only when it finds it
            # unset — so an inherited one from the login environment would
            # survive into a shell that has a different JDK on PATH, which is
            # the confusing half of a wrong-version error. Setting it here
            # settles it: mkShell's `env` is part of the derivation's
            # environment and is therefore already in place by the time that
            # hook looks.
            #
            # It also settles it for `mvn` and `gradle`, whose nixpkgs wrappers
            # each pass `--set-default JAVA_HOME` naming the JDK they were built
            # against. Default, so this wins — which is the point: the compiler
            # the build runs is the one in `packages` above.
            env.JAVA_HOME = jdk.home;

            shellHook = ''
              # Where the two build tools keep their caches, moved into the
              # project. Same bargain as GOPATH in the go template: no longer
              # shared between projects, and in exchange removing the directory
              # removes the lot and nothing lands in $HOME. Drop either line to
              # go back to ~/.m2 or ~/.gradle.
              #
              # Maven has no environment variable for its local repository, only
              # the system property, which is why this goes through MAVEN_OPTS —
              # appending rather than replacing, since a project that sets -Xmx
              # there means it.
              export MAVEN_OPTS="-Dmaven.repo.local=$PWD/.m2/repository ''${MAVEN_OPTS:-}"

              # .gradle-home rather than .gradle, which looks like a typo and
              # isn't: Gradle already uses ./.gradle for its *project* cache —
              # the configuration cache, the file-system probe, per-version
              # state — and pointing GRADLE_USER_HOME at the same directory
              # would pile the daemon, the wrapper distributions and the
              # dependency cache on top of it. Two names, two lifetimes.
              export GRADLE_USER_HOME="$PWD/.gradle-home"

              # The project's dependencies, fetched on the way in, so a fresh
              # clone is ready to build rather than ready to be set up.
              #
              # What's committed decides which tool runs, rather than what
              # happens to be in `packages` above: a pom.xml means Maven, Gradle
              # build scripts mean Gradle. Cloning someone else's repo shouldn't
              # be an occasion for this flake to have an opinion.
              manager=""
              manifests=()
              if [ -f pom.xml ]; then
                manager=maven
                stamp=.m2/.dev-shell-deps
                manifests=(pom.xml)
              elif [ -f build.gradle ] || [ -f build.gradle.kts ] ||
                [ -f settings.gradle ] || [ -f settings.gradle.kts ]; then
                manager=gradle
                stamp=.gradle-home/.dev-shell-deps
                manifests=(
                  build.gradle build.gradle.kts
                  settings.gradle settings.gradle.kts
                  gradle.properties gradle/libs.versions.toml
                )
              fi

              # The stamp is what makes this affordable in a hook that runs at
              # every prompt: touched only after a fetch that worked, so the
              # ordinary case — nothing edited since — is a handful of `test`
              # builtins and no subprocess at all. Deleting the cache directory
              # takes the stamp with it, which is the intent. Nothing happens
              # without a build file, since `dev-init java` in an empty
              # directory is a shell to run `mvn archetype:generate` in and not
              # yet a project, and DEV_NO_INSTALL=1 turns it off.
              stale=""
              for manifest in "''${manifests[@]}"; do
                if [ -f "$manifest" ] && { [ ! -e "$stamp" ] || [ "$manifest" -nt "$stamp" ]; }; then
                  stale=1
                fi
              done

              if [ -n "$manager" ] && [ -n "$stale" ] && [ -z "''${DEV_NO_INSTALL:-}" ]; then
                # A committed wrapper pins the build-tool version the project
                # expects, exactly the way a lockfile pins its dependencies, so
                # it wins over the copy in `packages` above. Both wrappers need
                # a JVM and nothing else, and JAVA_HOME above is it.
                if [ "$manager" = maven ]; then
                  if [ -x ./mvnw ]; then mvn=./mvnw; else mvn=mvn; fi
                  echo "fetching dependencies with $mvn dependency:go-offline..."
                  if "$mvn" -B -q dependency:go-offline; then
                    mkdir -p .m2
                    touch "$stamp"
                  else
                    echo "$mvn dependency:go-offline failed; the shell is still here. Fix it and rerun it by hand." >&2
                  fi
                else
                  if [ -x ./gradlew ]; then gradle=./gradlew; else gradle=gradle; fi
                  echo "fetching dependencies with $gradle dependencies..."
                  # `dependencies` is Gradle's only built-in task that resolves
                  # configurations without building anything, and its report is
                  # a few hundred lines of tree nobody asked for — hence the
                  # redirect, which leaves stderr alone so a failure still says
                  # why. It covers the root project's configurations; in a
                  # multi-project build Gradle resolves the subprojects at the
                  # first real build, on demand as it always would.
                  if "$gradle" --console=plain --quiet dependencies >/dev/null; then
                    mkdir -p .gradle-home
                    touch "$stamp"
                  else
                    echo "$gradle dependencies failed; the shell is still here. Fix it and rerun it by hand." >&2
                  fi
                fi
              fi
              unset manager manifests stamp stale manifest mvn gradle
            '';
          };
        }
      );
    };
}
