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
  [the Steam controller](MANUAL.md#the-controller-and-the-second-cursor) ·
  [the kernel](MANUAL.md#the-kernel) ·
  [development environments](MANUAL.md#development-environments) ·
  [local AI](MANUAL.md#local-ai) ·
  [the NVIDIA server](MANUAL.md#the-nvidia-server) ·
  [single GPU passthrough](MANUAL.md#single-gpu-passthrough) ·
  [updating the dotfiles assets](MANUAL.md#updating-the-dotfiles-derived-assets) ·
  [where things came from](MANUAL.md#where-things-came-from)
