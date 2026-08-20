{ inputs, lib, pkgs, ... }:

# Everything needed to develop on a machine, in one importable lump: direnv,
# containers, and the nix settings that make per-project shells behave.
#
# **This module is commented out in every host by default.** Uncomment its
# import in `hosts/<host>/configuration.nix` on the machines you actually
# develop on. That's deliberate: Docker is a daemon, a bridge interface and a
# chunk of closure, and a machine that isn't being developed on shouldn't
# carry it just because its sibling does.
#
# Note that turning it off also removes Docker, which used to be
# unconditional in the old `virtualisation.nix` (now folded in here). If a
# host needs containers but not the rest, import this and it's all one
# switch — there's no finer granularity on purpose.
#
# QEMU/KVM and virt-manager used to live here too. They're now their own
# import, modules/nixos/virtualization.nix, so a development host doesn't
# have to carry libvirtd and a GUI to get containers.
#
# See "Development environments" in MANUAL.md for the per-project workflow
# this exists to support.
let
  # One command to turn an empty directory into a working dev environment:
  # copies a template from this flake and marks the .envrc trusted. The
  # script, and the reasoning behind the shape it has, are in
  # packages/dev-init.nix.
  #
  # It's a package rather than something written inline here because flake.nix
  # exposes the same derivation as `packages.x86_64-linux.dev-init`, so a
  # machine that isn't NixOS — the CachyOS install, a work laptop — can have
  # the command without having this module. Written twice it would drift; the
  # two call sites are meant to be the same program.
  devInit = pkgs.callPackage ../../packages/dev-init.nix { };
in
{
  # --- nix, tuned for per-project shells --------------------------------
  nix.settings = {
    # Keep the build-time dependencies of anything a GC root points at.
    #
    # A `nix develop` shell isn't a package — it's a derivation's *build*
    # environment, so what it needs is that derivation's inputs, not its
    # output. Without these two, `nix-collect-garbage` (which base.nix runs
    # weekly) is free to delete every compiler and header in a shell that
    # nothing has built recently, and the next `cd` into the project silently
    # re-downloads or rebuilds the lot.
    keep-outputs = true;
    keep-derivations = true;

    # Let joshr configure substituters — `cachix use <name>` writes to
    # nix.conf and is refused for an untrusted user, which is most of the
    # value of having cachix installed at all.
    #
    # This is a real grant: a trusted user can point the daemon at a binary
    # cache and have its contents accepted without further checking. It's the
    # same trust the single admin account on this machine already has by way
    # of sudo.
    trusted-users = [
      "root"
      "@wheel"
    ];

    # Show more of a failed builder's output than the default ten lines. Most
    # useful failure messages in a dev shell are longer than that.
    log-lines = 25;
  };

  # --- the flake registry -----------------------------------------------
  # What `nixpkgs` means as a bare flake ref on this machine: the exact rev
  # this system is built from, rather than whatever nixos-unstable happens to
  # be at the moment something asks. That covers `nix run nixpkgs#...`,
  # `nix shell nixpkgs#...`, and the `inputs.nixpkgs.url = "nixpkgs"` that
  # every template in templates/ now uses.
  #
  # The templates are the reason it's here. Spelled as a URL, the first
  # `direnv allow` in a new project locks against a *different* nixpkgs than
  # the machine, and every store path the shell needs — stdenv, glibc, the
  # interpreter — is a fresh download despite an equivalent copy already
  # sitting in /nix/store. Pinned, the paths coincide and there is nothing to
  # fetch. It's also what makes the sentence in flake.nix about the templates
  # true: the machines and the shells they build move on one
  # `nix flake update`, because both read the same lock.
  #
  # Written as a github ref carrying the locked rev rather than as
  # `flake = inputs.nixpkgs`, which would resolve to a store path. Project
  # lock files record whatever this resolves to and outlive any one system
  # generation; a store path is not something the weekly nix-collect-garbage
  # in base.nix is obliged to keep, and a project whose lock names a
  # collected path can't be evaluated at all. A rev can always be fetched
  # again.
  nix.registry.nixpkgs.to = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    inherit (inputs.nixpkgs) rev;
  };

  # --- direnv -----------------------------------------------------------
  # The NixOS module rather than home-manager's, so the whole development
  # story is one import. It hooks bash, zsh and fish; nushell is the one
  # gap — home-manager's module covers it and this one doesn't, so if the
  # nushell prompt matters, add the hook to `programs.nushell` by hand.
  #
  # nix-direnv is what makes this usable at all: plain direnv re-evaluates
  # `use flake` from scratch on every cd, and nix-direnv both caches the built
  # profile and plants a GC root in .direnv/ so the weekly collection can't
  # delete a shell you're still using.
  #
  # Per-user direnv tuning — `hide_env_diff`, `warn_timeout` — lives in
  # ~/.config/direnv/direnv.toml and can't be set from here; direnv only reads
  # it out of the user's own config directory. Two lines of TOML if you want
  # the entry banner quieter.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # --- containers -------------------------------------------------------
  # Moved here from the old modules/nixos/virtualisation.nix, which had
  # nothing else in it. joshr's membership of the `docker` group follows this
  # automatically — see modules/nixos/users.nix.
  virtualisation.docker.enable = true;

  environment.systemPackages =
    [ devInit ]
    ++ (with pkgs; [
      # --- containers -------------------------------------------------
      docker-compose

      # --- nix itself -------------------------------------------------
      nil # language server, for the VS Code Nix extension
      nixfmt # the formatter this flake's `nix fmt` uses (was nixfmt-rfc-style)
      nix-output-monitor # `nom build` — readable build progress
      nix-tree # what pulled that dependency in
      cachix # binary caches, for projects that publish one

      # --- everyday, language-agnostic --------------------------------
      # Nothing language-specific belongs here or anywhere else global; a
      # compiler or an interpreter goes in the project's own devShell.
      just # per-project task runner, with no build system attached
      jq
      yq-go
      ripgrep
      fd
      lazygit
      gnumake
      claude-code
      drawio
    ]);
}
