{
  writeShellApplication,
  coreutils,
}:

# `dev-init`: one command that turns an empty directory into a working dev
# environment, by copying a template out of this flake and marking its .envrc
# trusted.
#
# It lives in its own file rather than inside modules/nixos/development.nix
# because it has two consumers. That module puts it in the system profile on
# the NixOS hosts, which is where it's normally met; flake.nix also exposes
# this derivation as `packages.<system>.dev-init` for each of its
# `devSystems` — x86_64-linux, aarch64-linux and aarch64-darwin — which is
# what makes it reachable from a machine this flake doesn't build: the
# CachyOS install, a work laptop, an ARM box, an Apple Silicon Mac, a
# container with nothing on it but nix.
#
#     nix run github:joshrandall8478/nixos#dev-init -- python
#
# Nothing in the script is platform-specific — it is bash, coreutils and two
# commands it looks up on PATH — but the flake output has to name a system
# before `nix run` on that system can find it, which is why that list exists
# and why it is longer than the hosts'.
#
# See "Nix on a machine that isn't NixOS" in MANUAL.md for the rest of that
# setup, which is mostly the nix.conf half of modules/nixos/development.nix.
#
# The templates come from the flake ref below rather than from a copy frozen
# into whichever system generation happens to be booted, so `dev-init` hands
# out whatever templates/ currently holds. It had been pointing at a repo
# under a name this one no longer goes by. DEV_TEMPLATES_FLAKE overrides it
# with any flake ref.
#
# `nix` and `direnv` come from the ambient PATH rather than runtimeInputs on
# purpose — nix is the daemon's client, and pinning a second copy into this
# script's closure would be a different nix from the one doing the build;
# direnv is a shell hook before it is a binary, and a copy in the store that
# no shell has hooked would allow an .envrc that nothing then loads. On NixOS
# development.nix guarantees both. Off it they're two separate installs and
# either can be missing, which is why each is checked for by hand below
# rather than left to fail as a command-not-found halfway through.

writeShellApplication {
  name = "dev-init";
  runtimeInputs = [ coreutils ];
  text = ''
    templates="generic python node rust go dotnet java gleam zig"
    flakeRef="''${DEV_TEMPLATES_FLAKE:-github:joshrandall8478/nixos}"
    template="''${1:-generic}"

    usage() {
      echo "usage: dev-init [$(echo "$templates" | tr ' ' '|')]"
      echo
      echo "Copies a dev-shell template into the current directory and marks"
      echo "its .envrc trusted. With no argument, the generic skeleton."
      echo
      echo "Templates are read from $flakeRef;"
      echo "set DEV_TEMPLATES_FLAKE to take them from somewhere else."
    }

    case "$template" in
      -h | --help)
        usage
        exit 0
        ;;
    esac

    case " $templates " in
      *" $template "*) ;;
      *)
        echo "unknown template: $template" >&2
        usage >&2
        exit 2
        ;;
    esac

    # Worth checking rather than assuming, off NixOS: the profile snippet an
    # installer writes only reaches shells started after it ran, so "nix is
    # installed" and "nix is on this shell's PATH" are two separate facts and
    # only the second one matters here.
    if ! command -v nix >/dev/null; then
      echo "nix isn't on PATH. If it's installed, this shell started before" >&2
      echo "it did — open a new login shell, or source its snippet here:" >&2
      echo >&2
      echo "    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" >&2
      # Same path on macOS, but there the line that sources it lives in
      # /etc/zshrc, which a macOS update replaces wholesale — so on that
      # machine "it worked yesterday" is a real answer and the fix is to put
      # the line back, not to reinstall nix.
      if [ "$(uname -s)" = Darwin ]; then
        echo >&2
        echo "A macOS update can replace /etc/zshrc and drop the line that" >&2
        echo "does this at login. If that's what happened, add it back:" >&2
        echo >&2
        echo "    # Nix" >&2
        echo "    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then" >&2
        echo "      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'" >&2
        echo "    fi" >&2
        echo "    # End Nix" >&2
      fi
      exit 1
    fi

    if [ -e flake.nix ]; then
      echo "flake.nix already exists here — refusing to overwrite it." >&2
      echo "Edit it by hand, or run dev-init in a fresh directory." >&2
      exit 1
    fi

    # Guarded rather than left to abort the script, because the likeliest
    # reason for this to fail on a machine that isn't NixOS is flakes being
    # switched off — and nix's own message for that names the feature without
    # saying where to turn it on.
    if ! nix flake init -t "$flakeRef#$template"; then
      echo >&2
      echo "nix flake init failed. If it complained about an experimental" >&2
      echo "feature, add" >&2
      echo >&2
      echo "    experimental-features = nix-command flakes" >&2
      echo >&2
      echo "to ~/.config/nix/nix.conf (or /etc/nix/nix.conf) and try again." >&2
      exit 1
    fi

    # The templates ship an .envrc, but nix flake init won't clobber one
    # that's already there.
    if [ ! -e .envrc ]; then
      printf 'use flake\n' > .envrc
    fi

    # A missing direnv is a note, not a failure: the template that was just
    # written is complete, and `nix develop` enters the same shell by hand.
    # The one thing that can't happen without it is the shell appearing on
    # its own at the next prompt.
    if ! command -v direnv >/dev/null; then
      echo
      echo "Template written. direnv isn't on PATH, so nothing will enter the"
      echo "shell for you — install direnv and nix-direnv and hook them into"
      echo "your shell, or use the environment directly:"
      echo
      echo "    nix develop"
      exit 0
    fi

    # Marks the .envrc trusted. It doesn't build anything itself — the
    # shell's direnv hook does that at the next prompt, which is the one
    # you get back when this exits.
    direnv allow

    echo
    echo "Ready. Add packages to the devShell in flake.nix; direnv rebuilds"
    echo "and re-enters the shell on save."
  '';
}
