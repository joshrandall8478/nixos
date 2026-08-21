# nixos-config

A NixOS flake for `joshr`'s gaming + development workstation: KDE Plasma 6 or
niri on Wayland (using Noctalia v5), NVIDIA, Steam/ProtonUp-Qt/MangoHud, Docker, and a
home-manager profile (with
[plasma-manager](https://github.com/nix-community/plasma-manager)) ported from
the [joshrandall8478/dotfiles](https://github.com/joshrandall8478/dotfiles)
chezmoi repo.

![the niri desktop](assets/desktop.png)

**[MANUAL.md](MANUAL.md) is the long version** — every module, every
`local.*` option, and why the awkward parts are the shape they are. This page
is the map.

## Hosts

Seven configurations across five machines. The desk and the laptop each have a
Plasma variant and a niri one — separate hosts rather than a switch, because
the two use different display managers and NixOS won't enable both.

| Host | Machine | Session |
|---|---|---|
| `gamestation` | the desk: NVIDIA, multi-monitor | Plasma 6 |
| `gamestation-niri` | same box | niri |
| `laptop` | portable: no NVIDIA, single display | Plasma 6 |
| `laptop-niri` | same box | niri |
| `usb` | a stick: boots anywhere, auto-login, disk tools | niri |
| `server` | headless | none |
| `server-nvidia` | headless, with a GPU: NVENC unlocked | none |

```bash
sudo nixos-rebuild switch --flake .#gamestation-niri   # use niri
sudo nixos-rebuild switch --flake .#gamestation        # back to Plasma
```

Switching either way is just a rebuild. Nothing is destroyed and the previous
generation stays in the boot menu.
[What actually differs](MANUAL.md#what-actually-differs) ·
[The server](MANUAL.md#the-server) ·
[The NVIDIA server](MANUAL.md#the-nvidia-server) ·
[The stick](MANUAL.md#the-stick) ·
[Adding another host](MANUAL.md#adding-another-host)

## Accounts

`joshr` (primary), `amandak`, `sabom` and `root`, on the four desktop hosts.

`amandak` and `sabom` run joshr's profile unchanged — the entrypoints in
`home/amandak/` and `home/sabom/` import the ones in `home/joshr/` and say
nothing but their own name, so on the niri hosts they get the same noctalia
session, each with its own theme and wallpaper state. Primary means the
machine-wide surfaces: the login screen and the boot menu wear joshr's theme
and wallpaper, and administering the box is joshr's, since neither of the
other two is in `wheel`.

`usb` is the exception: `joshr` and `root`, and no one else. It auto-logs in,
so the account that exists is the account the stick hands to whoever plugs it
in — see [The stick](MANUAL.md#the-stick).
[The accounts](MANUAL.md#the-accounts) ·
[The root account](MANUAL.md#the-root-account)

## Layout

```
flake.nix          # inputs; the seven nixosConfigurations; dev-shell templates
hosts/<host>/      # per machine: configuration.nix + hardware scan
modules/nixos/     # the system side, imported per host
home/common/       # home-manager bits shared by every account
home/joshr/        # the user profile; one entrypoint file per host
home/joshr/niri/   # the niri desktop: compositor, bar, themes, scripts
home/amandak/      # the other accounts, each wearing the same profile
home/sabom/
packages/          # dev-init, shared by the module and the flake's outputs
templates/         # `nix flake init -t` dev environments
```

`local.*` is this repo's own option namespace —
[`modules/nixos/options.nix`](modules/nixos/options.nix) for the system half,
[`home/common/options.nix`](home/common/options.nix) for the session half.
Every option carries its reasoning in its `description`, and every module
opens with a comment explaining what it's for.
[The annotated file tree](MANUAL.md#whats-here) is in the manual.

## Rebuilding

```bash
sudo nixos-rebuild switch --flake .#gamestation   # build, activate, add a boot entry
sudo nixos-rebuild build  --flake .#gamestation   # check it evaluates, change nothing
sudo nixos-rebuild test   --flake .#gamestation   # activate without a boot entry
                                                  #   (reverts on reboot — good for
                                                  #    risky NVIDIA/kernel changes)

nix flake update                            # all inputs
nix flake update dotfiles                   # just one
nix flake update --refresh wallhaven-toplist  # a fresh top 20; --refresh matters
```

`nix flake update` rewrites `flake.lock` — commit it alongside whatever
prompted the update, so a build that works is a build you can get back to. If
an update breaks something: `git checkout flake.lock` and rebuild.

## Development environments

No language toolchain is installed globally on any of these machines. A
project declares what it needs in its own `flake.nix`, and direnv puts those
tools on `PATH` when you `cd` in and takes them away again when you leave.
`dev-init` writes that flake, an `.envrc` and a `.gitignore`, and marks the
`.envrc` trusted:

```bash
dev-init            # generic skeleton
dev-init python     # or: node, rust, go, dotnet, java, gleam, zig
```

The language templates go a step further than putting the toolchain on `PATH`:
entering the shell also installs the project's own dependencies, so a fresh
clone is ready to run. `npm install` when `node_modules` is missing or
`package.json` moved (`pnpm` or `yarn` if that's the committed lockfile),
`uv sync` or `uv pip install -r requirements.txt`, `go mod download`,
`cargo fetch`, `dotnet restore`, `mvn dependency:go-offline` or its Gradle
equivalent, `gleam deps download`, `zig build --fetch`. A stamp file keeps an
ordinary `cd` free of all of it, `DEV_NO_INSTALL=1` turns it off, and a failed
install is a message rather than a shell that won't open —
[Dependencies, on the way in](MANUAL.md#dependencies-on-the-way-in).

Each one starts on the newest toolchain nixpkgs builds, which is often not the
attribute nixpkgs leaves unsuffixed — `dotnet-sdk` is still 8.0, `jdk` is 21,
`gradle` is 8 — so the templates that need to spell a version out do, and say
why beside the line: [Which version a template starts
on](MANUAL.md#which-version-a-template-starts-on).

Every template builds its shell for `x86_64-linux`, `aarch64-linux` and
`aarch64-darwin`, and `dev-init` is published for the same three, so a project
started on a desktop still enters its shell on an ARM box or an Apple Silicon
Mac. `x86_64-darwin` is the omission, and not one a line would fix — nixpkgs
26.11 dropped Intel Macs: [The systems a template builds
for](MANUAL.md#the-systems-a-template-builds-for).

On the NixOS hosts it arrives with `modules/nixos/development.nix`, whose
import is commented out per host — uncomment it on the machines you actually
develop on. Anywhere else nix is a package like any other and the module's
contents are four steps by hand. Same templates, same `dev-init`.

**1. Nix.** On CachyOS, or anything else Arch-based:

```bash
sudo pacman -S nix
sudo systemctl enable --now nix-daemon.socket
```

On Debian, Ubuntu, Fedora and the rest, the upstream installer — it creates
`/nix`, a multi-user daemon and the shell setup in one go:

```bash
curl -L https://nixos.org/nix/install | sh -s -- --daemon
```

One or the other, never both: two things each believing they own `/nix` is a
bad afternoon. Either way nix isn't in the shell you ran that from — open a
new one.

On macOS that same installer is the way in, and the steps below apply with two
substitutions: step 4's shell config goes in `~/.zshrc`, and the daemon is
restarted with `sudo launchctl kickstart -k system/org.nixos.nix-daemon`
rather than through systemd. The two macOS-only surprises — `/nix` being an
APFS volume rather than a directory, and a system update quietly dropping
nix's snippet from `/etc/zshrc` — are in [Nix on
macOS](MANUAL.md#nix-on-macos).

**2. `/etc/nix/nix.conf`** — the `nix.settings` from `base.nix` and
`development.nix`, written longhand:

```bash
sudo tee -a /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
keep-outputs = true
keep-derivations = true
log-lines = 25
trusted-users = root joshr
EOF
sudo systemctl restart nix-daemon
```

Only the first line is mandatory. `keep-outputs` and `keep-derivations` are
what stop garbage collection taking the compilers out of a dev shell — a shell
is a build environment rather than a package, so nothing points at it
otherwise. The daemon reads that file at start, which is what the restart is
for.

**3. direnv, nix-direnv and `dev-init`:**

```bash
nix profile add nixpkgs#direnv nixpkgs#nix-direnv
nix profile add github:joshrandall8478/nixos#dev-init
```

nix will have something to say about `extra-substituters` on the second one.
That's this flake's `nixConfig` offering the CachyOS kernel's binary cache,
which nothing in `dev-init` comes from — decline it.

**4. Three lines of shell config.** CachyOS defaults to fish, same as these
machines, so `~/.config/fish/config.fish`:

```fish
fish_add_path "$HOME/.nix-profile/bin"
direnv hook fish | source
```

and `~/.config/direnv/direnvrc`, which is what points direnv at nix-direnv:

```bash
source "$HOME/.nix-profile/share/nix-direnv/direnvrc"
```

Under bash or zsh those first two are `export PATH="$HOME/.nix-profile/bin:$PATH"`
and `eval "$(direnv hook bash)"`.

`fish_add_path` is the line people skip and then can't find `dev-init`: the
pacman package ships none of the shell setup the upstream installer writes, so
`~/.nix-profile/bin` — where `nix profile add` puts what you install —
isn't on `PATH`. `nix` itself resolves either way, out of `/usr/bin`. The
other Arch one: if `getent group nix-users` says that group exists, run
`sudo usermod -aG nix-users "$USER"` and log back in, or every nix command
fails on the daemon socket.

**Keeping it current.** None of that follows this repo on its own. The NixOS
hosts move everything at once on a rebuild; a nix profile moves when you tell
it to:

```bash
nix profile list                # what's installed, and the flake each came from
nix profile upgrade dev-init    # one entry, by the name that list prints
nix profile upgrade --all       # every entry
```

`upgrade` re-resolves the ref an entry was *installed* from rather than the
revision it locked, so `dev-init` follows this repo's default branch, and
`direnv`/`nix-direnv` follow whatever the bare `nixpkgs` resolves to here —
the global registry's `nixpkgs-unstable`, unless you added the [registry
pin](MANUAL.md#nix-on-a-machine-that-isnt-nixos), in which case they move when
you re-run the pin and not before. Nix caches that resolution for an hour;
`--refresh` is how you say you know something landed a minute ago. The
`extra-substituters` question from step 3 comes back on every `dev-init`
upgrade — decline it again.

The templates aren't in the profile and never need upgrading: `dev-init` reads
them from the flake at the moment you run it.

Old profile generations are GC roots, and off NixOS nothing collects them:

```bash
nix profile wipe-history --older-than 14d
nix-collect-garbage --delete-older-than 14d
```

[Development environments](MANUAL.md#development-environments) is the
per-project workflow, and [Nix on a machine that isn't
NixOS](MANUAL.md#nix-on-a-machine-that-isnt-nixos) is the rest of this — the
optional `nixpkgs` registry pin, garbage collection (nothing runs it there),
and what doesn't come across.

## Before you build this

This is one person's machine, not a distribution. On any other hardware:

1. **Every `hardware-configuration.nix` here is a placeholder** with invented
   disk UUIDs. It will not boot your machine —
   [regenerate it](MANUAL.md#regenerating-hardware-configurationnix).
2. **`open = true`** in `modules/nixos/nvidia.nix` needs a Turing (RTX 20xx)
   card or newer — as does its default on `server-nvidia`, which is
   `local.nvidia.open` and is the thing to turn off on a Pascal card.
3. **Panel layout** in `home/joshr/plasma.nix` assumes this monitor
   arrangement — the `screen = N` numbers are worth a look.
4. **Git identity** in `home/joshr/home.nix` is joshr's.
5. **The desk hosts boot a third-party kernel** — CachyOS/BORE, from the
   `nix-cachyos-kernel` flake input and its binary cache. Both are opt-in
   (`local.kernel.cachyos.*`). The kernel is prebuilt, and stays that way as
   long as you let the flake's `nixConfig` add its cache — nix asks once, or
   pass `--accept-flake-config`. Decline it and the machine compiles a kernel
   for the better part of an hour: [Never compiling
   it](MANUAL.md#never-compiling-it).

[Fresh install from the NixOS ISO](MANUAL.md#fresh-install-from-the-nixos-iso)
walks the whole thing from a live ISO.

## The manual

- **The desktop** — [niri](MANUAL.md#niri-alternative-to-plasma):
  [layout](MANUAL.md#layout) ·
  [the bar](MANUAL.md#the-bar) ·
  [the OSD](MANUAL.md#the-on-screen-display) ·
  [theme switching](MANUAL.md#theme-switching) ·
  [keys](MANUAL.md#keys) ·
  [clipboard](MANUAL.md#clipboard-history) ·
  [emoji](MANUAL.md#emoji-picker) ·
  [screenshots](MANUAL.md#screenshots) ·
  [lock screen](MANUAL.md#lock-screen) ·
  [login screen](MANUAL.md#the-login-screen)
- **Hardware and power** —
  [displays](MANUAL.md#displays) ·
  [brightness over DDC/CI](MANUAL.md#brightness) ·
  [staying awake](MANUAL.md#staying-awake) ·
  [no idle sleep on mains](MANUAL.md#no-automatic-sleep-on-mains-power) ·
  [the lid](MANUAL.md#the-lid) ·
  [coming back from suspend](MANUAL.md#coming-back-from-suspend) ·
  [RGB lighting](MANUAL.md#rgb-lighting)
- **The rest of the system** —
  [wallpapers](MANUAL.md#wallpapers) ·
  [dates and times](MANUAL.md#dates-and-times) ·
  [the browser](MANUAL.md#the-browser) ·
  [bootloader and dual boot](MANUAL.md#bootloader) ·
  [shells](MANUAL.md#shells) ·
  [scheduled jobs](MANUAL.md#scheduled-jobs) ·
  [the root account](MANUAL.md#the-root-account)
- **Working in it** —
  [gaming performance](MANUAL.md#gaming-performance) ·
  [`gamescope-run`](MANUAL.md#nested-gamescope-and-gamescope-run) ·
  [the Steam controller](MANUAL.md#the-controller-and-the-second-cursor) ·
  [the kernel](MANUAL.md#the-kernel) ·
  [development environments](MANUAL.md#development-environments) ·
  [nix on other distros](MANUAL.md#nix-on-a-machine-that-isnt-nixos) ·
  [local AI](MANUAL.md#local-ai) ·
  [the NVIDIA server](MANUAL.md#the-nvidia-server) ·
  [single GPU passthrough](MANUAL.md#single-gpu-passthrough) ·
  [updating the dotfiles assets](MANUAL.md#updating-the-dotfiles-derived-assets) ·
  [where things came from](MANUAL.md#where-things-came-from)
