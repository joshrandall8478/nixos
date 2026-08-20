# CLAUDE.md

Guidance for Claude Code working in this repository.

## What this is

A NixOS flake for one person's machines: seven `nixosConfigurations` across
five boxes, with home-manager (plus plasma-manager and spicetify-nix) for the
user side. It is a personal system config, not a library — there is no test
suite, and "does it work" means "does it evaluate and switch".

`README.md` is the map, **`MANUAL.md` is the reference** — every module, every
`local.*` option, and the reasoning behind the awkward parts. It is long and
it is maintained; treat it as part of the source.

## Validating a change

There is no CI. Evaluation is the check:

```bash
sudo nixos-rebuild build --flake .#gamestation   # evaluates + builds, changes nothing
nix flake check                                  # evaluates every host
nix fmt                                          # nixfmt (RFC style), from flake.nix
```

`build` is the one to reach for — `switch` activates, `test` activates without
a boot entry. Never run `switch` on the user's behalf unless asked.

Away from a NixOS machine (a container, a CI sandbox), `nix-instantiate
--parse <file>` still catches syntax errors, and a module can be imported
directly with stub arguments to inspect what it produces:

```bash
nix eval --raw --impure --expr '(import ./home/common/shell.nix {
  config = { local.shell.fastfetchGreeting = false; };
  lib = { optional = c: v: if c then [ v ] else []; mkIf = c: v: v; };
  pkgs = {};
}).programs.fish.functions.nix-clean.body'
```

That is worth doing whenever you write shell code inside a Nix string — see
the escaping note below.

## Layout

```
flake.nix          # inputs; the seven nixosConfigurations via mkHost; dev-shell templates
hosts/<host>/      # per machine: configuration.nix + hardware scan
modules/nixos/     # the system side, imported per host
home/common/       # home-manager bits shared by every account (shell, git, btop, tmux)
home/<user>/       # one entrypoint file per host, e.g. home/joshr/gamestation.nix
home/joshr/niri/   # the niri desktop: compositor, bar, themes, scripts
packages/          # standalone derivations exposed as flake outputs (dev-init)
templates/         # `nix flake init -t` dev environments
```

`mkHost` in `flake.nix` takes `{ hostModule, homeModules }` and wires
home-manager in. `root` is added to every host automatically, so anything in
`home/common/` lands in root's profile too — which is why those modules must
not assume a graphical session or a particular `$HOME`.

Host attribute names are **not** hostnames. `gamestation` and
`gamestation-niri` are two configurations of one machine called `dialga`.
Anything printing a rebuild command for the user has to say so.

## Conventions

**`local.*` is this repo's own option namespace.** System options are declared
in `modules/nixos/options.nix`, session options in `home/common/options.nix`,
separately from the modules that consume them. New knobs go there, with a
`description` that explains the reasoning rather than restating the name.

**Comments carry the "why".** This codebase is unusually heavily commented and
that is deliberate: modules open with a comment saying what they are for, and
non-obvious lines explain the constraint that produced them (see the
`nix-clean` block in `home/common/shell.nix` for the register). Match that
density. Do not add comments that restate the code.

**Prose style.** Both the comments and MANUAL.md are written in full
paragraphs, plainly, explaining tradeoffs. When you touch behaviour that
MANUAL.md documents, update MANUAL.md in the same change — including its
table of contents.

**Fish is the login shell**, and its functions live in
`home/common/shell.nix` under `programs.fish.functions`, shared by every
account. The eza aliases (`ls`, `ll`, `la`, `lt`, `lg`) are fish-only and
have never been mirrored into zsh/bash/nushell.

## Gotchas

**Shell code inside Nix indented strings.** In `''…''`, a bare `\` is
literal — `\s` and `\d` in a regex pass straight through — but `${` starts
interpolation and must be written `''${` when you mean it literally. Fish's
`$var` is safe; `${var}` is not. Verify by rendering the string (above) and
running `fish -n` on the result rather than by eye.

**Fish is not POSIX sh.** `echo` does not expand `\n` without `-e`; a quoted
command substitution `"$(cmd)"` collapses multiple lines into one argument;
prefer `test …; and …` over `[ … ] && [ … ]`. `fish -n file.fish` syntax-checks
without executing, and mocking a command by putting a script earlier on `$PATH`
is an easy way to exercise a function's branches.

**Deleting Nix generations.** `nix-env --delete-generations +N` keeps N
counting back from the *current* generation and never deletes the current one
or anything above it. `tail -n N` over `--list-generations` does the opposite
— that list is oldest-first, so it selects the newest N. Also note
`nixos-generate-config` only writes `hardware-configuration.nix`; it has no
generation subcommands at all.

**Garbage collection needs two runs, not one.** `nix-collect-garbage` only
walks the profiles it can see, and which those are follows `$HOME`. The
`sudo` run reaches the system profile; root's `$HOME` is `/root`, so it never
reaches `~/.local/state/nix/profiles` where home-manager keeps the user's
generations. Skip the second and those stay pinned as live GC roots. Skip it
when already root, where it just repeats the first.

**`hardware-configuration.nix` files here are placeholders** with invented
disk UUIDs. Do not treat them as describing real hardware, and do not "fix"
their UUIDs.

**`flake.lock` is committed on purpose.** Commit it alongside whatever
prompted the update, so a build that works is a build that can be returned to.

## Known rough edges

`modules/nixos/base.nix` sets
`systemd.timers.nix-clean-generations.timerConfig.Persistent` while the
service and timer it refers to are commented out just above it, so it
configures a unit that nothing defines. Unrelated to most changes; leave it
alone unless asked, but don't take it as a pattern to copy.
