# Manual

The long version: what every module does, which options exist, and why the
awkward parts are the shape they are. [README.md](README.md) is the map — the
hosts, the layout and the rebuild commands. This is everything else.

Written to be read out of order. Nothing below is required reading to rebuild
the machine.

## Contents

- [What's here](#whats-here)
- [niri (alternative to Plasma)](#niri-alternative-to-plasma)
  - [Layout](#layout)
  - [The shell: waybar or noctalia](#the-shell-waybar-or-noctalia)
  - [The bar](#the-bar)
  - [The on-screen display](#the-on-screen-display)
  - [Theme switching](#theme-switching)
  - [Theme sync under noctalia](#theme-sync-under-noctalia)
  - [Keys](#keys)
  - [Clipboard history](#clipboard-history)
  - [Emoji picker](#emoji-picker)
  - [Staying awake](#staying-awake)
  - [GameMode](#gamemode)
  - [No automatic sleep on mains power](#no-automatic-sleep-on-mains-power)
  - [The lid](#the-lid)
  - [Coming back from suspend](#coming-back-from-suspend)
  - [Displays](#displays)
  - [Brightness](#brightness)
  - [The login screen](#the-login-screen)
  - [Screenshots](#screenshots)
  - [Lock screen](#lock-screen)
  - [RGB lighting](#rgb-lighting)
  - [Installing applications: Flatpak and Discover](#installing-applications-flatpak-and-discover)
- [Wallpapers](#wallpapers)
  - [The default](#the-default)
  - [Which twenty, and who decides](#which-twenty-and-who-decides)
  - [Why the images aren't in the store](#why-the-images-arent-in-the-store)
  - [The one-off directory change](#the-one-off-directory-change)
  - [What the first rebuild will do](#what-the-first-rebuild-will-do)
- [Dates and times](#dates-and-times)
- [The browser](#the-browser)
  - [File associations, and why they're in /etc](#file-associations-and-why-theyre-in-etc)
  - [The media handlers, and why they replace KDE's own entries](#the-media-handlers-and-why-they-replace-kdes-own-entries)
  - [Why Firefox is still here](#why-firefox-is-still-here)
  - [How it follows the theme](#how-it-follows-the-theme)
  - [What Nix owns and what Sync owns](#what-nix-owns-and-what-sync-owns)
- [Bootloader](#bootloader)
  - [Dual boot: finding the other operating systems](#dual-boot-finding-the-other-operating-systems)
  - [How the boot menu ends up wearing the desktop's colours](#how-the-boot-menu-ends-up-wearing-the-desktops-colours)
  - [The boot splash](#the-boot-splash)
- [Shells](#shells)
  - [`nix-clean`](#nix-clean)
  - [`nix-delete-gens`](#nix-delete-gens)
- [Development environments](#development-environments)
  - [One import, and it's off by default](#one-import-and-its-off-by-default)
  - [The one-command path](#the-one-command-path)
  - [The manual path](#the-manual-path)
  - [Day to day](#day-to-day)
  - [Why a project shell is instant](#why-a-project-shell-is-instant)
  - [Secrets](#secrets)
  - [A project that isn't yours](#a-project-that-isnt-yours)
  - [VS Code](#vs-code)
- [Gaming performance](#gaming-performance)
  - [`gaming-doctor`](#gaming-doctor)
  - [The controller, and the second cursor](#the-controller-and-the-second-cursor)
  - [The desktop is also drawing](#the-desktop-is-also-drawing)
  - [VRR, and the judder that isn't the game](#vrr-and-the-judder-that-isnt-the-game)
  - [The shader cache, and the sawtooth](#the-shader-cache-and-the-sawtooth)
  - [The card is also the model server](#the-card-is-also-the-model-server)
  - [Split locks](#split-locks)
  - [Launch options](#launch-options)
  - [The XWayland regression](#the-xwayland-regression)
  - [The driver](#the-driver)
  - [The kernel](#the-kernel)
  - [Would Hyprland be better?](#would-hyprland-be-better)
- [Single GPU passthrough](#single-gpu-passthrough)
  - [What it costs](#what-it-costs)
  - [Turning it on](#turning-it-on)
  - [The guest itself](#the-guest-itself)
  - [What happens when the guest starts](#what-happens-when-the-guest-starts)
  - [And when it stops](#and-when-it-stops)
  - [When it goes wrong](#when-it-goes-wrong)
- [Local AI](#local-ai)
  - [Turning it on](#turning-it-on-1)
  - [The first rebuild is a long one](#the-first-rebuild-is-a-long-one)
  - [Models](#models)
  - [Open WebUI](#open-webui)
  - [OpenClaw, and what it costs](#openclaw-and-what-it-costs)
  - [Sharing the card with a VM](#sharing-the-card-with-a-vm)
  - [When it goes wrong](#when-it-goes-wrong-1)
- [Scheduled jobs](#scheduled-jobs)
  - [When not to use it](#when-not-to-use-it)
- [The accounts](#the-accounts)
  - [What "primary user" actually decides](#what-primary-user-actually-decides)
  - [One profile, several accounts](#one-profile-several-accounts)
  - [Adding another account](#adding-another-account)
- [The root account](#the-root-account)
- [Where things came from](#where-things-came-from)
- [Before you build this](#before-you-build-this)
- [Regenerating hardware-configuration.nix](#regenerating-hardware-configurationnix)
- [Fresh install from the NixOS ISO](#fresh-install-from-the-nixos-iso)
- [The XDG_DATA_DIRS workaround (nixpkgs#126590)](#the-xdg_data_dirs-workaround-nixpkgs126590)
- [Rebuilding after changes](#rebuilding-after-changes)
- [Hosts](#hosts)
  - [What actually differs](#what-actually-differs)
  - [The server](#the-server)
  - [The NVIDIA server](#the-nvidia-server)
  - [The stick](#the-stick)
  - [Adding another host](#adding-another-host)
- [Updating the dotfiles-derived assets](#updating-the-dotfiles-derived-assets)

## What's here

```
flake.nix                        # inputs: nixpkgs, home-manager, plasma-manager,
                                 #   spicetify-nix, nvidia-patch,
                                 #   nix-cachyos-kernel, dotfiles,
                                 #   wallhaven-toplist
hosts/gamestation/                # the desk: NVIDIA, multi-monitor
  configuration.nix               # top-level system config, imports the modules below
  hardware-configuration.nix      # PLACEHOLDER — replace with your real hardware scan
  kernel-params.nix               # which kernel + boot.kernelParams, shared with
                                  #   gamestation-niri
hosts/laptop/                     # portable: no NVIDIA, single display
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
hosts/server/                     # headless: no desktop, cron jobs
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
hosts/server-nvidia/              # headless with a card: NVENC/NvFBC unlocked
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — regenerate on the machine
hosts/usb/                        # the stick: niri on removable media, auto-login
  configuration.nix
  hardware-configuration.nix      # PLACEHOLDER — labels, not UUIDs; see the file
modules/nixos/
  base.nix                        # nix settings, locale/timezone, fish, base fonts
  plasmalogin.nix                     # SDDM (Wayland) + Plasma 6, portals, audio, Flatpak
  development.nix                 # direnv, Docker, nix settings — commented out
                                  #   per host, see below
  virtualization.nix              # libvirtd/QEMU/virt-manager — imported per host
  gpu-passthrough.nix             # single GPU passthrough: the libvirt hook that
                                  #   lends the only card to a guest and takes it back
  ai.nix                          # local models: ollama on the GPU, Open WebUI,
                                  #   and the OpenClaw agent — imported per host
  default-apps.nix                # /etc/xdg/mimeapps.list — file associations,
                                  #   overridable from a settings panel
  cron.nix                        # local.cron.jobs -> the system crontab
  emoji.nix                       # Microsoft Fluent Emoji as the system emoji font
  plasma-xdg-data-dirs.nix        # workaround for nixpkgs#126590 (see below)
  nvidia.nix                      # NVIDIA driver, 32-bit graphics for Steam/Proton,
                                  #   and the suspend/resume video-memory handling
  nvidia-server.nix               # the same card with no monitor on it: persistence,
                                  #   the container toolkit, the nvidia-patch overlay
  gaming.nix                      # Steam, gamemode + its hooks, gaming-doctor
  disk-managements.nix            # gparted, KDE Partition Manager, GNOME Disks
  filesystems-management.nix      # btrfs-progs, exfatprogs, dosfstools, e2fsprogs
  openrgb.nix                     # OpenRGB daemon + re-applying the profile on resume
  desktop.nix                      # what the five graphical hosts share: bluetooth,
                                   #   firmware, power-profiles-daemon, LocalSend
  laptop.nix                       # upower, thermald, fstrim, deep sleep, the lid
  power.nix                        # no idle suspend while on mains power
  boot.nix                         # bootloader: limine theming + other-OS detection
  kernel.nix                       # the CachyOS kernel on the desk hosts, and the
                                   #   binary cache that keeps it a download
  options.nix                      # local.boot.*, local.kernel.*, local.power.*,
                                   #   local.sddm.*, local.openrgb.*,
                                   #   local.virtualisation.*, local.ai.*,
                                   #   local.nvidia.*
  users.nix                        # the shared machines' accounts
  server-users.nix                 # headless: `joshr` and `root`, no session groups
  usb-users.nix                    # the stick: `joshr` and `root`, and no one else
home/common/
  options.nix                      # local.* options the entrypoints toggle
  shell.nix                        # fish + starship, shared by every account
  files/                           # starship.toml, smallfetch.jsonc
home/joshr/
  gamestation.nix                  # host entrypoint: enables the 2nd-monitor panel
  laptop.nix                       # host entrypoint: single-display panels
  server.nix                       # host entrypoint: shell only, no desktop base
  usb.nix                          # host entrypoint: the portable subset of
                                   #   laptop-niri.nix
  home.nix                         # packages (Spotify, Discord, ProtonUp-Qt, ...)
  browser.nix                      # the default browser: Vivaldi, $BROWSER
                                   #   (handlers: modules/nixos/default-apps.nix)
  firefox.nix                      # Firefox: profile, prefs, sync (installed, not default)
  wallhaven.nix                    # wallhaven's top 20 -> ~/.local/share/wallpapers/
                                   #   WallhavenFlake, from the locked listing
  kitty.nix                        # kitty terminal + zenwritten_dark theme
  vscode.nix                       # VS Code settings + extension list
  niri/                            # the niri desktop; see the section below
    default.nix                    #   imports, GTK/Qt theming, Dolphin
    themes.nix theming.nix         #   the palettes, and every generated config
    niri.nix waybar.nix            #   compositor config and the bar
    scripts.nix notifications.nix  #   theme/wallpaper/lock/screenshot helpers
    gamemode.nix                   #   the Mod+G / gamemoderun performance mode
    clipboard.nix                  #   clipboard history
    emoji.nix                      #   the Mod+. emoji picker
    vscode.nix lock.nix            #   editor theming, idle handling
  plasma.nix                       # KDE Plasma settings/panels/shortcuts (plasma-manager)
  files/                           # DarkObsidianII.colors
home/amandak/ home/sabom/          # the other two accounts, same shape each
  home.nix                         # names the account, and nothing else
  gamestation.nix laptop.nix       # host entrypoints, each importing joshr's
  gamestation-niri.nix             #   counterpart verbatim — which is what
  laptop-niri.nix server.nix       #   puts them on the same noctalia session
home/root/
  home.nix                         # fish + starship only, no desktop
templates/                         # `nix flake init -t` dev environments
  generic/ python/ node/ rust/ go/
```

## niri (alternative to Plasma)

There are niri variants of both machines. They're separate hosts rather than
a switch inside the existing ones, because Plasma here uses
plasma-login-manager and niri uses SDDM.

```bash
sudo nixos-rebuild switch --flake .#gamestation-niri   # use niri
sudo nixos-rebuild switch --flake .#gamestation        # back to Plasma
```

Nothing is destroyed either way, and the previous generation stays in the
boot menu. `laptop-niri` is the same deal for the laptop.

The niri hosts deliberately **don't** import `plasma-xdg-data-dirs.nix`.
That workaround exists because plasma-workspace's Qt wrapper builds an ~18 KB
`XDG_DATA_DIRS`; there's no plasma-workspace in a niri session, so the bug
can't occur — and neither can the from-source rebuild the workaround costs.

### Layout

```
modules/nixos/niri.nix        # session, SDDM + theme, polkit, PAM, portals,
                              #   Flatpak + Discover
modules/nixos/ddcci.nix       # DDC/CI brightness for external monitors
home/joshr/displays/
  gamestation.nix             # DP-3 + DP-2 layout — edit here for monitors
  laptop.nix                  # empty: niri auto-detects
home/joshr/niri/
  default.nix                 # entrypoint: packages, GTK/Qt/cursor
  themes.nix                  # the palettes — edit colours here
  theming.nix                 # renders each palette into per-tool configs
  niri.nix                    # config.kdl: binds, layout, window rules
  noctalia.nix                # the one-process shell (see below)
  noctalia-palettes.nix       # renders each palette into noctalia's format
  noctalia-templates/         # what noctalia renders the live palette into
  fastfetch-config.json       # strict-JSON seed the fastfetch template needs
  waybar.nix                  # bar layout + style
  notifications.nix           # dunst + wofi
  osd.nix                     # swayosd: the volume/brightness pop-up
  lock.nix                    # swayidle timers
  scripts.nix                 # theme/wallpaper/screenshot/session helpers
  gamemode.nix                # GameMode: the two config overlays, the state,
                              #   the bar's status command, the gamemoderun units
```

### The shell: waybar or noctalia

niri is a compositor and nothing else, so everything around it — the bar,
notifications, the volume pop-up, the launcher, clipboard history, the idle
timers, the lock screen, the wallpaper — has to come from somewhere else.
There are two answers here, picked per host:

```nix
# home/joshr/gamestation-niri.nix
local.niri.shell = "noctalia";   # or "waybar"
```

Both niri hosts are on `"noctalia"`. Setting it back to `"waybar"` is the
whole way back; nothing else needs editing, and the previous generation is
still in the boot menu regardless.

It is set per *host* rather than per account, and it lives in joshr's
entrypoint for that host — which the entrypoints in `home/amandak/` and
`home/sabom/` import verbatim, so every account on a niri host runs the same
shell from the same generated config. Each session's state is its own: the
config, palettes, plugin, wallpaper and `~/.local/state/niri-theme` are all
built from `config.home.homeDirectory`. What stays with one account is the
machine's own surfaces, which follow `local.desktop.primaryUser` — see
[What "primary user" actually decides](#what-primary-user-actually-decides).

**`"waybar"`** is the assembled stack, and it is eight programs:

| | |
|---|---|
| waybar | the bar |
| dunst | notifications |
| swayosd | the volume/brightness pop-up |
| wofi | launcher and every menu |
| cliphist | clipboard history |
| swayidle | idle timers |
| swaylock/hyprlock | lock screen |
| awww | wallpaper |

Eight config formats, and a theme switcher whose job is largely to restart
them all in the right order.

**`"noctalia"`** is all eight in one Quickshell process reading one TOML file,
generated from `home/joshr/niri/noctalia.nix`. The mapping is one-for-one:

| waybar stack | noctalia |
|---|---|
| waybar | `[bar.main]` + the widget list |
| dunst | `[notification]` |
| swayosd | `[osd]` |
| wofi | `[shell.launcher]` |
| cliphist | `[shell]` `clipboard_*` |
| swayidle | `[idle.behavior.*]` |
| hyprlock | `[lockscreen]` |
| awww | `[wallpaper]` |

**It is v5, and compilation is a host choice.** Everything in `noctalia.nix`
is written against noctalia's v5 schema — `[bar.<name>]` with
`start`/`center`/`end` lanes, `[widget.<id>]` instances,
`theme.source = "custom"` reading `palettes/<name>.json`. v4 spelled several
of those differently; colour schemes in particular lived in
`colorschemes/<name>/<name>.json`.

**Watch the attribute name.** nixpkgs carries both majors, and the names run
backwards from what you'd guess:

| attribute | version | |
|---|---|---|
| `pkgs.noctalia` | 5.0.0-beta.7 | the v5 line — what this config uses |
| `pkgs.noctalia-shell` | 4.7.7 | v4; kept the repo's old name |

The version in that first row is nixpkgs' and will move with the lock. The
patched build does not follow it — see [The version pin](#the-version-pin)
below, which is where this repository names a release.

Upstream renamed the repository from `noctalia-shell` to `noctalia` at v5, so
the more official-looking `noctalia-shell` is the stale one. Putting it in
`environment.systemPackages` gets you v4 and a session that ignores most of
this config.

**There is no flake input, and that is the point.** Upstream ships a
home-manager module in its flake and this used to use it, but that flake
publishes no substituter — its cachix cache name is a CI secret — so any
reference to `packages.default` meant compiling a Qt/C++ project locally on
every rebuild. Stock `pkgs.noctalia` is on the ordinary binary cache.

`local.niri.noctaliaSourcePatches` controls the remaining fork. It defaults to
true and adds the animated lock/unlock transitions, content-sized text OSDs,
the customized control-panel identity and colours, the lock-screen clock's
`shadow_offset` setting, and relative MPRIS IPC actions retained for
compatibility. Source changes create a different
derivation, so that side compiles locally. `laptop-niri` sets the option false:
it uses cached `pkgs.noctalia`, while keeping exactly the same generated TOML,
palettes, templates, plugins and theme-sync hooks. The desktop keeps the default
and therefore keeps the C++ extras.

#### The version pin

The patched side does not follow nixpkgs. `noctalia.nix` overrides `src` to a
fixed upstream tag, and the two lines at the top of its `let` are the only
place a version is named:

```nix
noctaliaVersion = "5.0.0-beta.7";
noctaliaHash = "sha256-9RlJNIy2DFVm9SB2vwGEBsbHc1r3dIB+K+b+nd6Bdho=";
```

The patches are unified diffs against those exact files, so without the pin a
`nix flake update` that happens to carry a noctalia bump lands as a failed
`patchPhase` in the middle of an unrelated update. That failure is loud and it
happens at build time, before anything is activated — but it blocks the whole
rebuild, and the fix is a patch rebase rather than anything to do with what was
being updated. Pinning makes moving forward a separate, deliberate errand.

Upstream is worth pinning against. v5 is in beta and shipping roughly weekly,
and one commit — `style: uppercase float literal suffixes`, which turned every
`1.5f` into `1.5F` across the tree — is already enough to break two of the
three patches, because a deletion line has to match character for character
where context lines get some fuzz. Being a beta release or two behind costs
less than that.

**Moving the pin.** Change `noctaliaVersion`, set `noctaliaHash` to
`lib.fakeHash`, build once, and copy the hash out of the error. Then rebase the
patches, which is the actual work — `noctalia-lock-transition.patch` is 21
hunks across six files in `src/shell/lockscreen` and `src/shell/osd`, both of
which upstream changes weekly, so budget for it. Both values can also be read
straight out of nixpkgs' own `pkgs/by-name/no/noctalia/package.nix` if the
target is whatever nixpkgs has.

**Only the patched side is pinned.** `noctaliaSourcePatches = false` exists to
stay on the binary cache, and overriding `src` there would force the laptop to
compile a Qt/C++ project to get a version it has no patches to protect. The
cost is that the two hosts can drift onto different releases. `noctalia config
validate` is what catches it: it runs against whichever package the host
selected, so a generated key that the laptop's newer stock package has renamed
fails the laptop's build. Read that as the prompt to move the pin, not as a
reason to remove it.

Note also that this pins the *source* and not the recipe — `buildInputs`,
meson flags and the wrapper still come from whatever nixpkgs currently says,
which keeps nixpkgs' packaging fixes but is another reason the gap shouldn't
grow for long.

What the module generated is small enough to own outright, and `noctalia.nix`
now writes all three itself:

```
~/.config/noctalia/config.toml       from `settings`
~/.config/noctalia/palettes/*.json   one per theme, from themes.nix
the systemd user service             restarted by X-Restart-Triggers
```

The one piece worth keeping from it is the build-time check: `noctalia config
validate` still runs over the generated TOML in a `runCommand`, so a key that
has been renamed upstream fails the build naming the line instead of being
dropped in silence. It does not create another Noctalia build: it uses whichever
cached or source-patched package the host selected and only reads a file.

**Two config files, and only one of them is Nix's.** `config.toml` above is
generated and read-only. `~/.local/state/noctalia/settings.toml` is the other
half — noctalia's own overrides, holding whatever gets changed in the Settings
window — and the shell writes it, stamped with a `config_version`.

noctalia refuses to start on a version it doesn't understand:

```
config version 12 is newer than supported version 8
```

That is a *downgrade* symptom. Going forwards is handled — there's a migration
per version and they run on load — but going backwards has nothing to run. It
is reachable here because the package moved: an earlier revision of this
config took noctalia from its own flake, where `main` is 5.0.0 and stamps
version 12, while nixpkgs is on the `v5.0.0-beta.7` tag, which knows up to 8.
Anyone who ran the flake build once has a state file the packaged build can't
read, on every host they ran it on.

A home-manager activation step reconciles that: it reads the version the state
file claims and asks the installed binary about it with two probes — an empty
config, which must pass, and the same thing carrying that version. Only when
the first passes and the second fails is the version the cause, at which point
the file is renamed to `settings.toml.too-new` rather than deleted. No version
number is written down anywhere in this repo, so the check stays right when
nixpkgs moves to a build that does understand 12.

To do it by hand: `mv ~/.local/state/noctalia/settings.toml{,.too-new}`.

The bar comes across slot for slot — same order, same geometry (34px tall,
12px corners, 88% opaque) — with two deliberate departures.

**It is spaced out more than waybar was.** waybar ran an 8px gap down to 4 to
claw back room from a right-hand cluster that had grown to twelve slots. That
cluster is three slots shorter here, so the gap goes back up (`widget_spacing`
8, `padding` 16) and the controls read as separate things again rather than
one run-on strip.

**Two widgets are gone**, each because something else already did the job:

| dropped | because |
|---|---|
| `lock` | the session panel next door offers it, and `Mod+L` is the reflex |
| `lock_keys` | the caps-lock OSD says it louder, and only while a key is on |

What stays is either a live reading (brightness, volume, network, bluetooth,
battery) or an indicator that means something by being present at all
(privacy, notifications, gamemode, caffeine). The clipboard-history button is
immediately to the right of Notifications; the `Mod+Ctrl+V` shortcut and the
launcher's clipboard provider remain available as well.

**The left cluster is deliberately quiet**: one icon, one row of pills, one
line of text. The first slot is the NixOS snowflake and it opens the launcher
— the entry point wofi never had a bar slot for. It is U+F313
(`nf-linux-nixos`) in the widget's `label`, not in its `glyph`: `glyph` is a
name resolved against the Tabler icon set noctalia ships, which has no NixOS
mark, and the `U+XXXX` literal that field also takes is a codepoint *in that
font* — the same private-use area the Nerd Fonts use, so it would answer with
whichever Tabler icon sits at F313. A label is drawn in the shell's own
`font_family`, which is FiraCode Nerd Font. `glyph = ""` goes with it, because
the widget's default glyph is `heart` and it would be drawn beside the label.
It replaced a `nixos-icons` SVG through `custom_image` and lost no colour
doing it — a colorized image and a label are painted from the same foreground
chain, so it is the bar's text colour and follows a colour-scheme change
either way. The
username lives in its tooltip rather than beside it — the one person who can
read this bar already knows whose session it is. Workspaces label only the
occupied ones, so the empty workspace niri always keeps at the end of the row
is a plain dot instead of a number standing in for nothing. The window title
draws nothing at all when nothing is focused (`show_empty_label = false`,
`min_length = 0`), so the cluster ends where its content does rather than
reserving a slot.

**`max_length` is a width in pixels**, on both the window title and the now
playing widget, capped at 800 by the widgets themselves — not a count of
glyphs, which is the natural reading of the name. The window title scrolls on
hover; now playing is capped at 270px and scrolls continuously, so a long track
never needs a wider permanent slot. It deliberately has no custom wheel action,
so scrolling does not change the MPRIS player's volume; system output volume
remains the separate volume widget.

**Privacy hides itself when idle.** noctalia draws all three of its glyphs —
microphone, camera, screen-share — greyed out by default, which is three
permanent icons saying "not recording", the state you're in essentially
always. `hide_inactive` restores what waybar's pair of modules did: the
custom mic module printed an empty line when nothing held the microphone and
waybar hides a custom module with no text, so the slot cost nothing until it
meant something.

#### The GameMode indicator is a plugin, and a plugin has to be enabled

Every other slot on that bar is a noctalia widget. GameMode is not — the shell
has no widget for it and no `exec`-style escape hatch, so the pad is a local
Luau plugin, `joshr/gamemode-indicator`, in
`home/joshr/niri/noctalia-plugins/gamemode-indicator/`. `noctalia.nix` builds
its two files into the store and links the result to
`~/.local/share/noctalia/plugins/gamemode-indicator/`, which the plugin
registry scans as an implicit local source, and the bar names its one entry
`joshr/gamemode-indicator:status`.

**Installed is not enabled**, and that is the thing worth writing down, because
nothing tells you. The registry parses every manifest it finds under that
directory and then drops the ones whose id is not in `[plugins].enabled` —
"discovered but not enabled", one line in the shell's log, no widget. A bar
lane naming an entry of a plugin that never loaded is not an error either:
`noctalia config validate` checks the shape of a lane list and has no registry
to check the names against, so the build passes, the shell starts, and the slot
is simply absent. `plugins.enabled` in `noctalia.nix` is what turns it on;
`noctalia msg plugins list` is what says whether it did.

The manifest's `plugin_api` is a floor, not a version stamp. It is the oldest
plugin API level the entry needs, and the registry refuses anything outside
`kOldestSupportedPluginApiVersion`..`kCurrentPluginApiVersion` — so declaring
the level that happens to ship with the packaged noctalia (19, on
`v5.0.0-beta.7`) buys an indicator that vanishes the moment nixpkgs is a beta
behind the tip. This one asks for 3: `setGlyph`, `setVisible`, `runAsync` and
`setUpdateInterval` are all older than the first numbered level.

Two smaller things the plugin API makes easy to get wrong, both of which this
one did. `noctalia.runAsync(cmd, cb)` hands the callback a **`CommandResult`
table** — `exitCode`, `stdout`, `stderr` and two truncation flags — not the
output as a string, so trimming the argument itself compares a table to
`"active"` and the pad stays hidden however many games are running. And the
command has to be an absolute path: the shell runs as a systemd user service,
whose `PATH` is the user manager's rather than the one a login shell builds
from the profile, so `niri-gamemode` is substituted into `widget.luau` at
build time as a store path, the same way every `command` in that file is
written. (`runAsync` runs what it is given through `/bin/sh -c`, which is why
that path can carry a `status` argument after it.)

What the widget does is what waybar's module did, minus the signal. It polls
`niri-gamemode status` every two seconds and calls `barWidget.setVisible` with
the answer — `setVisible` is a render patch rather than a lifecycle switch, so
a hidden widget keeps ticking and can come back. The 30-second `interval` plus
`SIGRTMIN+9` arrangement described under [The bar](#the-bar) has no equivalent
here: there is nothing to signal, so the poll is the whole mechanism and it
runs often enough that the pad appears about as promptly as the hook made it.
The hooks in `modules/nixos/gaming.nix` still fire and still find no waybar to
poke, exiting into their `|| true`.

That command answers in one word, and the word is what the tooltip says:

| answer | the pad | the tooltip |
|---|---|---|
| `game` | lit | GameMode is on, and a game put it there |
| `manual` | lit | GameMode is on because `Mod+G` said so |
| `daemon` | lit | a game holds gamemode, but the session is **not** stripped back |
| `off` | hidden | — |

`daemon` is the state that would otherwise be a lie. It happens when `Mod+G`
is pressed mid-game — the session effects come back, the game keeps gamemode —
and it is also what a failed hand-off from the system hook looks like. Folding
it into `game` would have the tooltip claim the session was stripped back when
it was not, and dropping it would hide a running game from the bar altogether.
See [GameMode](#gamemode).

Three things are new, with no waybar equivalent: a notification history, a
clipboard panel, and a control centre. That last is where wifi, bluetooth,
audio devices and the power profile get real panels — most of what the old
right-click actions were reaching for (`nm-connection-editor`,
`blueman-manager`, `pavucontrol`).

**The panels open under what you clicked.** Attached panels are centred on the
bar by default, so the control centre — whose widget sits at the far right —
opened in the middle of the screen and had to be tracked back to the icon that
produced it. `open_near_click_*` drops the control centre, session, wallpaper
and clipboard panels directly beneath their widget, which for the right-hand
cluster means the right-hand side. The launcher is deliberately excluded: it's
a search box rather than a menu belonging to a widget, it's opened from the
keyboard as often as the bar, and centred is where a search box belongs.

**`themes.nix` stays the source of the 29 palettes**, under both shells. Under
waybar, `theming.nix` renders each into the seven config formats those daemons
read; under noctalia, `noctalia-palettes.nix` renders the same palettes into
noctalia's own colour-scheme format and drops one JSON file per theme into
`~/.config/noctalia/palettes/`, named for the theme id, so `theme-apply` and
`color-scheme-set custom <name>` speak the same string.

What it is **not** under noctalia is the only source of colour. The shell can
also take a palette from its own builtins, derive one from the wallpaper, or
download a community scheme, and none of those three has a name this repo
could have prebuilt anything for. That is why the fan-out to everything
outside the session goes through a rendered manifest rather than a palette
name — see [Theme sync under noctalia](#theme-sync-under-noctalia), which is
also where the three things that were quietly broken by assuming otherwise are
written up.

Two mechanisms share the rest of that job, and the split is not arbitrary.

`theming.nix` renders all 29 palettes into the config formats this repo
already had to speak — niri's KDL, kitty's include, `kdeglobals` for Dolphin
and the KDE file dialogs, VS Code, firefox, wofi — and `theme-apply` moves the
symlink they all point at. That machinery predates noctalia and is what runs
under `"waybar"`. Under `"noctalia"` the shell's own templates render the same
set of files into `~/.local/state/niri-theme/noctalia-live` and its hook
points that symlink there instead, so the consumers are unchanged and only the
writer differs.

noctalia's **templates** fill the gap it left, which is GTK. Nothing in
`theming.nix` ever wrote a GTK stylesheet, so GTK apps — and every portal and
file-chooser dialog they open — kept the stock Adwaita palette while the rest
of the session changed colour. `gtk3` and `gtk4` write
`~/.config/gtk-{3,4}.0/noctalia.css` and add an `@import` to `gtk.css`, which
home-manager does not manage here; their apply hook already knows about NixOS
and replaces a read-only symlink with a real file rather than failing on it.
`qt` is the same idea for qt5ct/qt6ct, as plain side files with no hook.

Most builtin templates edit the app's *main* config from a hook — adding an
`include`, setting a `color_theme` — and here that file is a read-only symlink
into the store. Every one of those hooks is idempotent though: it checks for
its own line before writing. So the line is declared on the home-manager side
and the hook finds its job already done.

| template | the line declared for it | where |
|---|---|---|
| `kitty` | `include themes/noctalia.conf` | `programs.kitty.extraConfig` |
| `btop` | `color_theme = "noctalia"` | `programs.btop.settings` (mkForce) |
| `cava` | `[color] theme = "noctalia"` | `xdg.configFile."cava/config"` |
| `niri` | `include "noctalia.kdl" optional=true` | written into `config.kdl` by `niri.nix` |
| `gtk3`/`gtk4` | — | `gtk.css` isn't managed; their hook already handles NixOS |
| `qt` | — | plain side files for qt5ct/qt6ct, no hook |
| `alacritty` | — | not installed and not managed; the hook creates its own |

**`starship` is the exception**, and the one place a declarative file becomes a
mutable one. starship has no include mechanism, so its hook splices the palette
bodily into `starship.toml` between two markers, and what it splices changes
with every theme — there is no line to pre-declare. On a noctalia host
home-manager therefore stops owning that file and an activation step seeds a
real one from `home/common/files/starship.toml`, which stays the source of
truth: the step strips the hook's block before diffing, so a theme change never
looks like drift, and re-seeds when the repo's copy actually changes.

**`optional=true` on the niri include is load-bearing.** niri treats a missing
include as a hard parse error — the tolerant branch is reached only when the
node carries that property — so without it, a session that has not yet had
noctalia render its templates fails to parse its config *entirely*, not just
the themed part. That is the state on a fresh install, a new user, or before
the first `theme-apply`. The hook's own regex allows trailing content after the
filename, so the property doesn't stop it recognising the line. The path stays
relative, which is safe even though `config.kdl` is a store symlink: niri joins
a relative include onto the parent of the path it was *given* and never
canonicalises it.

**`config.kdl` carries exactly one theme include**, and which one depends on
the shell. `"waybar"` gets `include "<active>/niri.kdl"` — a file
`theming.nix` renders into every prebuilt palette directory. `"noctalia"` gets
the `noctalia.kdl` line above and *not* the other one, because `active` points
at `noctalia-live` under that shell and nothing has ever written a `niri.kdl`
there; noctalia's `niri` template renders `~/.config/niri/noctalia.kdl`
instead.

Emitting both was a hard failure rather than a cosmetic one — the
`<active>/niri.kdl` include carries no `optional=true`, so
`failed to read included config` aborted the whole config and the session came
up with niri's defaults. It survived as long as it did because `theming.nix`'s
activation used to repoint `active` at a prebuilt directory on every switch,
which is the same clobbering that put the greeter, the boot menu and Spotify
on the wrong palette. Removing that is what exposed this.

**Window borders are the part of that swap nobody declared.** The two includes
are not equivalent: `renderNiri` in `theming.nix` writes the focus ring *off*,
a 3px border *on*, and the palette's active, inactive and urgent colours, where
noctalia's `niri` template writes colours and nothing else. So the shell change
quietly handed the geometry back to niri's defaults — focus ring on at 4px,
borders off — and the borders disappeared without anything in this repository
having removed them. `niri.nix` now emits `focus-ring { off; }` and
`border { on; width 3; }` into `layout` under `"noctalia"`, which is only the
shape: niri merges duplicate sections property by property with the later one
winning, and since these land after the include and name neither colour,
noctalia's stay in force. The same split as everywhere else in this migration —
one writer for the colours, one for everything else.

**One of those colours is wrong, and it is fixed with a third include.** The
builtin `niri` template paints `border.inactive-color` from `surface`, which is
the theme's own background: an unfocused window's border is then the colour of
the desktop behind it, which is a border being drawn and not a border you can
see. `config.kdl` therefore carries a second noctalia include —
`noctalia-borders.kdl`, rendered by the `niri_borders` user template in
`noctalia.nix` — holding exactly one property, `inactive-color` from
`on_surface_variant`. That is the role `fg_dim` is rendered from in
`system-palette.conf`, so an unfocused border is the same dimmed foreground
every other quiet thing in the session uses.

It is a second file rather than an edit to the first for the reason the
property-by-property merge exists: correcting one line by overwriting
`noctalia.kdl` would mean owning the four colours and three sections the
builtin template gets right, forever, including whatever it grows next. A later
include naming one property takes that property and nothing else. And it is a
template rather than a colour written into `config.kdl` because under this
shell the palette is live — wallpaper-derived and community schemes included —
so a value baked into the generation would be this rebuild's idea of the theme
rather than the session's. `optional=true` for the same reason the first
include carries it: the file does not exist until noctalia has rendered a
palette once.

**The overrides file can silently shadow all of this.**
`~/.local/state/noctalia/settings.toml` is read after `config.toml` and wins,
which is right for something changed in the Settings window and wrong for the
widget placements, because noctalia writes those itself without being asked —
`setLockscreenWidgetsState` serialises every widget *and* a `widget_order`, and
the shell seeds a login box into it on its own. `widget_order` is what makes it
an override rather than a merge: the reader treats an order list as the
definitive membership list, so a stale one naming `clock_DP-3` drops the
`clock_time_DP-3` and `clock_date_DP-3` declared here outright — and the
Poppins family and the two boxes that make the time bigger than the date then
look like they did nothing.

The activation step strips those two sections on every switch, so what is
declared applies again. Only those two: everything else in that file is a real
preference, and the wallpaper especially is genuine runtime state — noctalia
records the current image per monitor there, and dropping it would reset the
desktop to `wallpaper.default.path` on every `home-manager switch`.

**`kcolorscheme` stays off.** Its post-action writes `~/.config/kdeglobals`
unconditionally, and `default.nix` points that at the active theme as an
out-of-store symlink — two writers for one file. A *user* template writes the
same content inside `noctalia-live` instead, so repointing `active` moves
Dolphin and VS Code together and nothing fights over `kdeglobals`.

Kitty is single-writer per shell: under `"waybar"` the include points at the
active theme directory, under `"noctalia"` at the template's output. Carrying
both would mean two `include` lines setting the same colours with the winner
decided by the merge order of two `mkAfter`s.

Changing the colour scheme from noctalia's own Settings window moves
everything, not just the shell. A `colors_changed` hook runs
`noctalia-theme-resync`, which validates the rendered outputs, points `active`
at the live directory and touches the sentinel the system path units wake on.
It deliberately does **not** call back into `theme-apply`: an earlier version
did, which is how `theme-apply` came to carry a `NIRI_THEME_FROM_NOCTALIA`
guard against re-entering the hook it had just fired. The hook is gone and so
is the guard.

**The wallpaper reaches the greeter the same way.** `modules/nixos/niri.nix`
watches `~/.local/state/niri-theme/wallpaper` with a systemd path unit and
copies whatever it names somewhere the greeter's own user can read. Under the
waybar stack `wallpaper-set` wrote that file; noctalia owns the wallpaper now,
so a `wallpaper_changed` hook writes it from `$NOCTALIA_WALLPAPER_PATH`
instead — through a temp file and a rename, because the path unit fires on
close and would otherwise read a half-written filename.

**What is lost crossing over.** One thing, now that the gamemode pad is back as
[a plugin](#the-gamemode-indicator-is-a-plugin-and-a-plugin-has-to-be-enabled):

- **The lock screen's album art, and its battery.** `lock-session` builds a
  hyprlock config per invocation carrying a blurred album-art background, the
  album cover, media transport buttons, a battery readout and a time-aware
  greeting. noctalia's lock screen keeps most of that in a different shape —
  see below — but the album-art background and the charge do not survive.
  `local.niri.lockAlbumArt*`, `.lockBatteryIndicator` and the greeting flags
  are therefore only read under `"waybar"`, and are left set on both hosts so
  that going back restores the screen that was there.

#### The lock screen under noctalia

The config places one compact login box near the bottom of every output and an
auto-hiding media player above its prompt. The login box's shared session row
is disabled; Suspend and Switch user are explicit lock-safe buttons beneath
it, so the desktop session menu can keep its complete action list without
putting reboot and shutdown on the locked screen.

**The password is masked with random shapes rather than dots.**
`shell.password_style = "random"` swaps the one filled circle per character
that `"default"` draws for a seven-glyph cycle — circle, pentagon, star,
rounded square, guitar pick, blob, triangle — indexed by each character's
position in the field. The row is therefore stable for a given length rather
than reshuffled as you type, which is what makes it useful: a varied row of
shapes gives the eye something to count against, so a typo reads as a
wrong-length pattern from further away than a run of identical dots does, and
nothing about a character is recoverable from the glyph standing in for it.
The setting lives under Security → Authentication in noctalia's own settings
and covers every password field the shell draws — here that is the lock
screen's login box alone, since `polkit_agent = false` leaves the polkit
prompt to polkit-kde-agent (see `modules/nixos/niri.nix`). It is an upstream
key rather than one of this repository's patches, so unlike the clock's
`shadow_offset` below it is emitted on both sides of
`local.niri.noctaliaSourcePatches`.

**The media player's box is the login box's width, and its height comes out of
that.** A boxed widget paints its panel at the full box but scales its
*content* to fit inside it aspect-preserved, at
`min(innerW / naturalW, innerH / naturalH)` over the box less its background
padding on each edge. A horizontal `media_player`'s natural content is a 120px
cover, 6px of spacing and a text column one and a half covers wide — 306×120,
where the cover is the full height and everything else is in the column beside
it — so the smaller of those two ratios is what sizes the album art. Against a
box as wide as the login panel a written-down height is the smaller one every
time: the old 132 scaled the content to 0.93 and centred it in a panel 57px
wider than it on either side. The height is therefore solved for instead —
`innerW × 120 / 306`, plus the padding back — which makes the width the binding
edge, fills the padded box on both axes, and gives the cover every pixel the
panel can hold. Change the width and the height follows.

With `local.niri.cavaInLockscreen` enabled, an `audio_visualizer` is the first
entry in the explicit `widget_order`, which also makes it the backmost custom
widget. Its box is the full logical width and height of the output, with no
panel or padding, while the login panel is a later root layer.
`show_when_idle = false` fades the spectrum away when playback stops, so the
wallpaper remains clean when there is no media — which is what lets the option
default on without the locked screen looking busy.

**This is not the same option as the bar's visualiser.** Both spectra were
`local.waybar.cavaInBar` at first, because under waybar the bar was the only
place one could go. They are separate knobs now — `cavaInBar` for the compact
widget beside the clock, `local.niri.cavaInLockscreen` for the one covering the
whole output — since eight bars in a status bar and a full-screen spectrum
behind the login prompt are not one decision, and either can be wanted without
the other. Both still default on, and `laptop-niri` sets both explicitly.
`cavaInLockscreen` is read only under `local.niri.shell = "noctalia"`: hyprlock
has no visualiser widget to turn on, making it the mirror image of the
`local.niri.lock*` options, which only hyprlock reads.

Time is **two** widgets, not one. A clock widget has a single
font size, so "time bigger than the date" can't be done inside one `format`
string, and the only size control a lock screen widget has is its box: with
`box_width` and `box_height` both set, the widget scales its content to fill
them and the clock's font becomes `fontSizeBody * 4 * contentScale`. There is
no `font_size` setting and no `scale` key on a widget in this version, so the
boxes *are* the type scale. They're fractions of the output (30%×13% for the
time, 22%×4.5% for the date), which holds the proportions — about 2.9× — on a
1080p panel and a 1440p one alike. Both are set in **Poppins**: a geometric
sans with a tall x-height, where the shell's own FiraCode Nerd Font is a
monospace and at that size reads as a terminal rather than a clock.

Widgets are positioned by pixel coordinate per output, so the position is
computed from the mode already declared in `local.niri.outputs` rather than
written down twice — changing a monitor moves the clock with it. On the desk
that's the time at (1280, 374) on DP-3 and (960, 280) on DP-2, with the date
stacked directly beneath.

A host that leaves its layout to niri's auto-detection has no mode to read.
`local.niri.lockClockOutputs` names the connectors instead — `[ "eDP-1" ]` on
the laptop — and the position falls back to a 1080p centre. noctalia clamps
widget coordinates to the output, so on a panel that isn't 1080p the clock
lands off-centre rather than off-screen.

**Two explicit lock-screen buttons.** Suspend calls systemd directly and
Switch user runs the same `switch-user` script the waybar session menu called.
They sit outside `[shell.session]`, whose complete Lock / suspend / switch /
logout / reboot / power-off list remains available from the desktop panel.

**The date's shadow needs a patch, and the reason is the type scale.** A clock
widget draws its text shadow at `shadow_offset * contentScale` with no blur,
and `contentScale` is precisely what the box does to the type — so the
`shadow = true` both clocks share is worth several pixels of offset on the time
and about one on the date, which is a hard pixel at 60% black under a glyph
nobody is looking that closely at. It was on the whole time and it could not be
seen. Nothing in the config could fix that: the offset is a hardcoded `1.5f`,
and the only lever a widget has over its own size is the box, which moves the
font with it. `noctalia-clock-shadow-offset.patch` turns that constant into a
`shadow_offset` setting, defaulting to upstream's value, and the date sets it to
`1.5 × timeH / dateH` — the boxes' ratio, which cancels the content scale out
and lands the date's shadow the same number of real pixels off its glyphs as
the time's. Derived from the boxes rather than written down as 4.3, so it
follows if the type scale moves. It is emitted only where the patch is:
`noctalia config validate` runs against whichever package the host chose, so on
`noctaliaSourcePatches = false` the key would fail the build instead of being
ignored, and `laptop-niri` keeps upstream's invisible shadow.

Two choices are about cost rather than looks. Neither clock has a background,
which drops a rounded rect and an alpha layer per widget per output per frame
and makes the text shadow load-bearing instead of decorative. And
`blurred_desktop = false` uses the wallpaper rather than a wlr-screencopy
snapshot of every output taken at the moment of locking — cheaper, and it still
works when you lock from an already-blanked screen.

**Battery is not there, and can't be.** noctalia has no battery widget for the
lock screen or the desktop: the widget types are clock, label, button, sysmon,
media_player, weather, sticker, volume, the two visualisers and login_box, and
sysmon's stats are CPU, GPU, RAM, swap and network with nothing for the power
supply. There's no official plugin for it either. The charge is on the bar and
in the control centre, and the hyprlock screen under `"waybar"` still draws it.

**Brightness needs ddcutil, and the reason is worth writing down** — the
earlier reasoning here was wrong.

`modules/nixos/ddcci.nix` loads ddcci-backlight, which speaks DDC/CI in the
kernel and registers each external monitor as an ordinary
`/sys/class/backlight/ddcci*` device. The argument was that noctalia would then
reach the desk's monitors through sysfs exactly as it reaches a laptop panel,
with no second DDC/CI implementation involved. It doesn't:
`enumerateBacklights` only keeps a backlight it can tie to a live Wayland
output, and it does that by canonicalising `<device>` and checking it sits
under `/sys/class/drm/card*-<CONNECTOR>`. A ddcci backlight hangs off its i2c
adapter instead, so it matches nothing — and the single fallback in that code
path is hardcoded to connectors starting `eDP`.

So the laptop's internal panel works through sysfs and **every external monitor
is silently dropped**: a brightness widget that does nothing on the desk.
`brightness.enable_ddcutil = true` is the supported route for those — noctalia
shells out to `ddcutil detect` and drives them from userspace.

Two things it needs, both already true. `hardware.i2c` — enabled by `ddcci.nix`
— loads `i2c-dev` and puts a uaccess tag on `/dev/i2c-*`, so this runs as the
user. And `ddcutil` has to be on `PATH`: nixpkgs' noctalia wrapper only
prefixes `gitMinimal`, and the code gates the whole backend on
`commandExists("ddcutil")`, so it's in `home.packages`.

Noctalia is the only brightness writer under this shell. The old 4-minute idle
action went through the legacy `brightness` helper and ddcci-backlight, racing
Noctalia's ddcutil backend to the same monitor register. It is gone. Noctalia's
own fullscreen pre-action fade now supplies the darkening before the 5-minute
lock and 10-minute screen-off actions without changing the monitors' physical
brightness or leaving a restore write behind.

`local.niri.brightness.device` is unread under noctalia, and nothing is lost:
it existed because waybar's backlight module and the `brightness` helper each
picked "the display" by a different rule and could disagree about which monitor
the bar was quoting. noctalia reports the focused monitor's own backlight,
which is the answer that option was approximating.

**Weather is on, and it is the one thing here that reaches the network on its
own.** `location.auto_locate` resolves coordinates from the machine's public IP
rather than a place name — nothing to write down, and it follows a laptop that
moves — and the forecast comes from Open-Meteo on a 30-minute refresh.
`[location]` is also what `theme.mode = "auto"` and the night light would use
for sunrise and sunset, neither of which is enabled.

### The bar

Left is the username, workspaces and the focused window title, centre is the
clock and date, right is the tray, media controls, brightness, volume,
bluetooth, network, the battery and power profile as one widget, caps lock and
gamemode while each is on, the idle inhibitor, then **lock** and **power** as a
matched pair at the far end. Each group is its own rounded floating pill rather
than one long bar.

The right-hand group is deliberately tight — the modules carry no horizontal
margin of their own, so the bar's 4px `spacing` is the entire gap between two
pills. There is a wrinkle worth knowing before changing it: **`spacing` is one
number for the whole bar**, with no per-group setting, so cutting it to bring
the right-hand cluster together also cut the left. The left group's three
modules carry 1px either side in the stylesheet to put that back.

**The username** is the first slot, in the accent colour — the same treatment
the clock gets, because both are labels rather than controls. It's static
text with no `exec`: the name comes from `config.home.username` at build
time, so there's no subprocess polling for a string that can't change while
the bar is running, and a second user's generation renders their own name
without editing anything.

Lock and power are styled identically and differ only on hover — the power
button goes red, because it's the one that can end the session. The lock
button runs the same `lock-now` as `Mod+L` and the session menu's "Lock"
entry, so all three take the active theme's colours.

**Brightness** sits immediately left of the volume, the two controls on the
bar that are a level rather than a state. Scroll it to adjust; there is no
click action, because brightness has no equivalent of mute and a click that
jumped to a fixed level is a worse thing to hit by accident than nothing.

The scroll runs the same `brightness` helper as the keys rather than waybar's
own stepping, for the reason that helper exists: the built-in stepping is
`brightnessctl` with no `--device`, which moves the first backlight device and
leaves the rest — invisible with one internal panel, wrong on the desk with
one device per monitor. Setting `on-scroll-up`/`on-scroll-down` replaces the
module's stepping rather than adding to it, so `scroll-step` would do nothing
and isn't there; the step is the 5 inside the script. Unlike the volume
module, nothing overrides it down to 1 — DDC/CI writes are slow and the script
drops overlapping runs, so a finer step would mostly land on a held lock.

It is waybar's built-in `backlight` module even so, because the number has to
be right whatever moved the level — the scroll, a media key, the pre-lock dim
in `lock.nix`. Those all write the device through sysfs, which is what the
module watches, so it repaints on the change rather than waiting for its next
poll.

Which display it speaks for is `local.niri.brightness.device`, and the same
option is what the OSD reads back, so the two always quote the same screen.
Left unset they each pick their own "first" by a different rule and can end up
describing different monitors. Its `interval` is also raised well above
waybar's default, because on this machine each tick of it is a DDC/CI round
trip to every monitor rather than a sysfs read. Both are covered under
"Brightness" below.

On a host with no backlight device at all it draws no text but still holds its
padding — it isn't one of the custom modules waybar hides outright. That's the
desk before the reboot `ddcci` needs, and it sorts itself out.

**Bluetooth** goes dim when the radio is off — `@fg-dim`, the same colour the
muted volume immediately to its left takes, rather than the red the network
module to its right turns when it drops. Nothing is broken when bluetooth is
off; it's a thing you turned off, and the module keeps its slot either way.

Two CSS classes carry that colour, because waybar has two states for "off" and
only one of them is the one you'd reach for. Toggling bluetooth off in blueman
— or `bluetoothctl power off` — powers the controller down and lands on
`.off`. `rfkill block bluetooth`, the airplane-mode route, lands on
`.disabled`. Styling `.disabled` alone would leave the everyday case at full
brightness, which is the trap in the name.

**The power profile** sits immediately right of the charge, and the two are
one widget rather than two neighbours: a leaf for power-saver, a pair of
scales for balanced, a dial for performance. Left click steps forward through
the profiles the daemon offers and right click steps back — that's the
module's own handler, so unlike the volume and brightness modules there's no
`on-click` here keeping a script in step, and no way to add one. The tooltip
names the profile and the driver actually carrying it, which is the part worth
knowing: a profile the daemon accepts but has no driver for changes nothing.

Three different silhouettes rather than one needle in three positions,
because a dial a few degrees further round isn't something you read out of the
corner of your eye at 13px. The colours are the bar's existing vocabulary and
not a new one — the accent for power-saver, which is what gamemode wears for
"a thing you chose"; plain `@fg` for balanced, the default; and warn for
performance, which is what the idle inhibitor wears for a mode you can forget
you left on, and that's exactly what performance is on a laptop. `@fg-dim` is
the obvious pick for power-saver and is deliberately not used: dim on this bar
means *off* — the muted sink, the powered-down bluetooth radio — and
power-saver is a profile that's emphatically on.

"One widget" is a `group/` in `waybar.nix`: a box holding both modules with no
spacing of its own, taking one slot in the bar, so the two halves meet flush
where every other neighbouring pair carries the bar's 4px. (Its `orientation`
has to be spelled out. waybar's default is *orthogonal to the parent*, which
in a top bar means stacking the two vertically inside 34px.) They're still two
modules because waybar has none that knows both, and a custom one that did
would have to reimplement what `battery` already does — repainting on udev
events from the power supply rather than on a timer, and putting the `warning`
and `critical` classes on the pill at 30% and 15%. That's the same argument
the `backlight` module makes for not going custom.

None of it is conditional on the host. `battery` hides itself where there's no
battery and `power-profiles-daemon` hides itself when nothing answers on the
system bus, so the laptop draws both halves and the desk draws the profile
alone, looking like any other pill. The daemon is enabled for every graphical
host in `modules/nixos/desktop.nix`; without it the module isn't on the bar at
all. `powerprofilesctl` comes with it, which is how to read or set the profile
from a shell.

**Caps lock** is one glyph between the battery and the idle inhibitor, in the
theme's warn colour, and it is on the bar *only* while caps lock is on. The
rest of the time it isn't dimmed or blank, it's gone — no glyph, no gap, the
bar exactly as it was before.

That last part is why it's a custom module and not waybar's built-in
`keyboard-state`, which reads the same LED and would need no script at all.
`keyboard-state` always draws its label; even with the text emptied out, the
label stays in the layout and still costs the gap the bar puts between
modules, and a GTK stylesheet has no `display: none` to take it out. A custom
module that prints an empty line is hidden by waybar itself and costs nothing
— the same trick the visualiser below uses to disappear when the music stops.

The script watches the caps LED rather than polling: the compositor mirrors
the lock state onto every keyboard's LED, and the kernel passes each change to
everything holding the device open, so one blocking `select` is the whole loop
and the glyph turns over with the keypress. It's Python because it needs to
ask each device whether it has a caps LED and read the starting state with an
ioctl, neither of which shell can do. Reading `/dev/input` needs the `input`
group, which `joshr` has from `modules/nixos/users.nix`; without it the script
finds no keyboards and exits, and the bar is just short one module. See
`capsLockWatch` in `home/joshr/niri/scripts.nix`.

None of this is the caps lock OSD that swayosd deliberately doesn't run (see
"The on-screen display"): that one is a system service reading every input
device to draw a pop-up, where this is the session's own bar reading the
keyboard the session is already using.

**GameMode** sits immediately to its right and disappears the same way — a
controller glyph in the accent colour while GameMode is on, and no slot at all
the rest of the time. The accent rather than caps lock's warn colour because
the two are neighbours that can be lit at once, and because gamemode being on
is something you asked for rather than something to warn you about.

It lights for the [session's GameMode](#gamemode) as well as for a game
holding gamemode, so `Mod+G` with nothing running shows the pad exactly as a
game does. That is deliberate: the pad is the only thing on screen that says
the mode is on, and a mode that survives a relogin needs one.

It's polled, not watched: gamemode has somewhere to *ask* — a D-Bus daemon
with a status call — but nothing a shell can subscribe to. So the module works
the way the idle inhibitor does, a 30-second `interval` as the backstop and a
`signal` for the answer that matters. The gamemode start and end hooks in
`modules/nixos/gaming.nix` already fire a notification; they also send waybar
`SIGRTMIN+9`, as does `niri-gamemode` itself, so the glyph appears as the mode
is entered instead of up to half a minute later. **The signal number is
written in three places** — that hook, `gamemode.nix` and the module in
`waybar.nix` — and nothing checks that they still agree.

The script (`gamemodeStatus` in `gamemode.nix`) checks the session mode's
state file first and only then asks the daemon — and before asking, checks
that `gamemoded` is running at all. gamemoded is D-Bus activated, so a bare
`gamemoded --status` on a timer would keep starting the very daemon it's
reporting on. It matches `is active` and not `active`, for the reason you'd
expect from "inactive".

**The visualiser** is eight bars of cava just left of the track name, in the
theme's dimmed accent. It is only there while something is actually making
noise: the script prints an empty line on a silent frame and waybar hides a
custom module with no text, so the bar looks exactly as it did before
whenever nothing is playing — no reserved slot, no flat row of glyphs.

It follows the *audio*, not the mpris player, so a notification chime blips
it for a moment too. That's the trade for needing no polling and no second
process: cava already knows whether there's sound. Tying it to the player
would mean gating the loop on `playerctl --follow status`.

After two seconds of silence cava stops doing FFT and only checks for input
once a second, so the idle cost is close to nothing. `cava` is also on PATH
on its own — running it in a terminal is the quickest way to tell whether
it's cava or the widget at fault if the bar stays empty. See `cavaBar` in
`home/joshr/niri/scripts.nix`.

### The on-screen display

Volume and brightness raise a pop-up — icon, bar and the number, low and
centred on every output, in the active theme's colours. niri has none of its
own, being a compositor and nothing else, so before this the keys were silent:
the level moved and the only way to see where it had landed was waybar — a
number in a corner of one display, which you have to already be looking at.

**swayosd** draws it. `swayosd-server` is a user service (`osd.nix`); a
one-shot `swayosd-client` asks it to draw over the session bus. The mute keys
get a worded message instead of a bar — "Muted", "Microphone muted" — because a
toggle has no level to show, and because a client request can't grey out the
bar the way swayosd's own volume OSD does.

**swayosd never changes anything, only draws.** `swayosd-client --output-volume
raise` would do both in one call, and that is the usage its README documents,
but with the server down it does neither — a crashed OSD daemon would take the
media keys with it. So `volume` and `brightness` (`scripts.nix`) make the
change themselves, read the result back, and then ask for a pop-up, with every
one of those calls best-effort. The worst case is a change you don't see.

Brightness has a second reason: swayosd drives `brightnessctl` with at most one
`--device`, which is the exact thing `brightness` exists to work around (see
"Brightness" below), and asking it for a wildcard makes `brightnessctl get`
print one line per display into a parser that wants a single number.

Reading the level back rather than predicting it is also what keeps the number
honest, and a level computed here would be wrong at both ends of the range.
For volume the clamping is `wpctl`'s; for brightness it is the script's own,
because the script now works out each target itself rather than handing
`brightnessctl` a relative step — see "Brightness" below for why. `volume
show` draws the current level without changing it, which is the quickest way
to tell whether the daemon is up.

Every route to the volume goes through that one script: the media keys, and
waybar's click-to-mute and scroll. The bar's scroll passes an explicit step of
1, since a scroll notch moves a single point where a key moves five —
`scroll-step` no longer does anything once `on-scroll-up`/`on-scroll-down` are
set, so it's gone from the module rather than left there looking load-bearing.

**The power profile gets a pop-up too, and it is built the other way round.**
Volume and brightness are drawn by the scripts that change them, because those
keys are the only thing that changes them. The profile isn't: it moves from the
bar (waybar's `power-profiles-daemon` module has its own click handler and
takes no `on-click` of ours), from `powerprofilesctl` in a terminal, from a
`powerprofilesctl launch` hold that a game takes and gives back, and from the
daemon itself when it drops out of performance on a hot machine. The changes
worth seeing are exactly the ones you didn't press a key for.

So the display hangs off the daemon instead. `power-profile-osd` — a user
service declared in `osd.nix`, a loop around `gdbus monitor` — waits for
power-profiles-daemon's `PropertiesChanged` on the system bus, reads the
profile back with `powerprofilesctl get`, and draws "Power saver", "Balanced"
or "Performance" with the matching icon whenever it has actually moved. The
readback is the same discipline as volume's: it describes the machine rather
than the event, and it is also the filter, since `PerformanceDegraded` and
`ActiveProfileHolds` arrive on that same signal and are dropped by the profile
simply not having changed.

`Mod+P` steps forward through whatever profiles the daemon offers and
`Mod+Ctrl+P` steps back, in the daemon's own order, through `power-profile`
(`scripts.nix`). Neither key draws anything — the watcher does, having heard
the daemon agree — so a profile that didn't take produces no pop-up claiming
it did. `power-profile show` draws the current one without changing it.

Two details worth keeping. It is **`gdbus monitor` and not `dbus-monitor`**:
dbus-monitor asks the bus to make it a monitor, which the system bus's default
policy allows root and nobody else, so it fails in a user session; gdbus
subscribes to the broadcast, which anyone may do. And it runs under `stdbuf
-oL`, because gdbus prints through stdio and a change would otherwise sit in a
4KB buffer instead of reaching the loop.

The three icons — `power-profile-{power-saver,balanced,performance}-symbolic` —
come from the icon theme rather than from swayosd, which compiles in volume and
brightness and nothing else. Papirus-Dark has all three. A theme that didn't
would leave swayosd drawing its `missing-symbolic` fallback next to the right
words.

It appears on **every** output rather than only the focused one, which is
swayosd's default and is left alone. `swayosd-client --monitor <name>` would
narrow it, but only if something works out which output is focused first —
`niri msg focused-output` on every keypress, with a fallback for when that
fails — and two small pop-ups is a cheaper thing to live with than a key that
sometimes shows nothing.

Two things it deliberately doesn't do. **The idle dim doesn't raise one**: the
dim happens when you've stopped touching the machine and the restore happens
the instant you touch it again, so a pop-up on the way back would fire on every
return to the desk to report a level that hasn't changed. And **nothing shows
on the lock screen** — a session lock draws above every layer-shell surface,
which is the point of it. The keys still work there; `allow-when-locked` is
about the volume moving, not about the pop-up.

The libinput backend — caps lock, num lock, scroll lock — is not set up. That
half is a system service wanting udev rules and polkit, it reads every input
device to do its job, and none of the three keys is one this session has
anything to say about.

### Theme switching

29 palettes ship, and `nord` is the default.

`joshrandall-net` is the house palette — dark neutral grey with a pastel
green. Greens: `matrix` (bright phosphor), `forest`, `mint`. Monochrome:
`mono` (white on black), `mono-light` (black on white). Reds: `blackred`,
`crimson`. Then `catppuccin-mocha`, `catppuccin-macchiato`,
`catppuccin-frappe`, `rose-pine`, `rose-pine-moon`, `nord`, `dracula`,
`tokyo-night`, `everforest`, `kanagawa`, `solarized`, and the four Gruvbox
contrasts — `gruvbox` (medium), `gruvbox-hard`, `gruvbox-soft` and
`gruvbox-light`, all transcribed from morhetz/gruvbox's own palette.

Four are originals rather than transcriptions: `synthwave` (neon magenta on
midnight violet), `ember` (amber on a cold neutral charcoal, where Gruvbox's
orange sits on a warm one), `abyss` (cyan on deep-water navy) and `sakura`
(pastel rose on ink plum).

Three light options besides `mono-light`: `rose-pine-dawn` is the cool one,
`gruvbox-light` the yellow one, and `sandstone` — warm paper and sienna —
sits between them.

`Mod+Ctrl+T` opens a picker, which at 29 palettes is the useful way in, and
`Mod+Ctrl+W` does the same for wallpapers.

The `Mod+Shift` halves of both pairs used to jump to a *random* theme and a
random wallpaper. They're gone. Random is a fine thing to have on a keyboard
exactly once and a bad thing to have next to the pickers — `Mod+Shift+W` is
one slip from `Mod+Ctrl+W`, and the slip silently replaced whatever you'd
chosen. `theme-random`, `theme-cycle` and `wallpaper-random` are all still on
PATH for when that is genuinely what you want.

The mechanism is worth knowing, because it's what keeps this declarative.
home-manager owns `~/.config/...` as read-only symlinks into the store, so a
script can't rewrite them. Instead every theme is **built ahead of time** as a
complete set of config files, and the only mutable state is one symlink:

```
~/.local/state/niri-theme/active -> /nix/store/...-niri-theme-matrix
```

Each tool is pointed at a file under that symlink: niri via its `include` node
(live-reloaded), waybar started with `-s <active>/waybar.css`, wofi via its
`style` config key, dunst via `services.dunst.configFile`, swayosd via
`--style <active>/swayosd.css`, kitty via an `include` at the end of
`kitty.conf`. `theme-apply` moves the symlink, restarts waybar, dunst and
swayosd, and sends kitty SIGUSR1 so open terminals repaint in place; wofi
re-reads on each launch.

**Under noctalia** the symlink and everything hanging off it work exactly the
same way — kitty, kdeglobals, VS Code and the rest are unchanged, which is the
point. Only the shell's half differs. The three restarts are replaced by one
line of IPC:

```
noctalia msg color-scheme-set custom <name>
```

That works with nothing to translate because `noctalia-palettes.nix` files
each generated palette under the theme's own id — `gruvbox.json`,
`rose-pine-moon.json` — so the name `theme-apply` was handed is the name
noctalia is given. It repaints in place rather than restarting.

The palettes themselves are a translation between two ways of naming colour.
`themes.nix` names them by the job they do here (`bg`, `accent`, `accentDim`,
`fgDim`); noctalia uses Material 3 roles, which come in pairs — every `mX`
surface has an `mOnX` that is the text drawn on it. Ten map straight across.
The `mOn*` halves had no equivalent, because this config never wrote them
down: it assumed `bg` was the text on top of `accent`, which is what kitty's
`selection_foreground` and waybar's active workspace both do. That holds on
the two dozen dark themes and inverts on the light ones, so instead of
hard-coding it `noctalia-palettes.nix` picks whichever of the theme's own two
text colours has the better WCAG contrast with the surface in question. On a
dark theme that returns `bg` — the existing behaviour — and on `gruvbox-light`
or `rose-pine-dawn` it returns `fg`, which is what the old assumption got
wrong.

**Dolphin and other KDE apps** read `~/.config/kdeglobals`, which is a symlink
into the active theme. Two things have to be true for that to work, and the
second is easy to get wrong: `qt.platformTheme.name` must be `"kde"`, not
`"gtk"`. The GTK platform plugin reads colours out of the *GTK* theme and
never opens `kdeglobals` at all, so with it loaded Dolphin comes out in
Adwaita grey whatever palette is selected. With the KDE plugin in place,
`theme-apply` also emits KDE's palette-changed signal on the session bus —
the same one Plasma sends when you apply a colour scheme — so an open Dolphin
repaints without being restarted. That part is best effort; anything that
doesn't listen picks the change up next time it starts.

That `"kde"` costs one thing worth knowing about. home-manager maps the name
to a fixed package list, and it includes **KDE System Settings** — which is
why that app used to appear in the launcher on a session with no Plasma to
configure. `qt.platformTheme.package` is therefore spelled out in
`home/joshr/niri/default.nix`: the module takes the first non-empty of
[your list, the name's list], so naming `kio` and `plasma-integration`
explicitly means the third one is never installed. Both of those are
load-bearing — the KDE file dialog and the plugin that reads `kdeglobals` —
and `QT_QPA_PLATFORMTHEME` is still `kde`. The Plasma hosts are unaffected;
they get System Settings from Plasma itself.

**VS Code** has no "read colours from this path" setting — a colour theme can
only arrive as an extension. So each palette renders a complete one-theme
extension, and `home/joshr/niri/vscode.nix` symlinks the whole directory into
`~/.vscode/extensions`. `workbench.colorTheme` is therefore pinned to `"Niri"`
forever: a switch re-points the symlink at a different build of the same
extension, and the name in `settings.json` — which lives in the store and
can't change at runtime — never has to. Restart the editor to see it.

**Firefox** is the same shape as Dolphin: its profile's `chrome/userChrome.css`
and `userContent.css` are symlinks into the active theme, read once at
startup. See "The browser" below.

Adding a theme is one attrset in `themes.nix` — the niri fragment, both
stylesheets, the dunstrc, the OSD's stylesheet, the swaylock palette, the SDDM
config, Dolphin's kdeglobals, VS Code's extension and Firefox's two chrome
stylesheets are all generated from its ten colour roles.

The OSD's sheet is the one that overrides rather than replaces: swayosd loads
its own at GTK's APPLICATION priority and ours at USER priority, which is
higher, so only the colours and the corner radius are restated and the layout
stays upstream's. It is written against GTK4 node names — `window#osd`,
`#container`, `progressbar > trough > progress` — because swayosd 0.3 is a
GTK4 application, and it spells its `rgba()` channels out rather than using
GTK's `alpha(@theme_bg_color, …)`, which resolves only if the loaded GTK theme
defines that name.

kitty is the exception, because a terminal needs sixteen ANSI colours and ten
semantic roles don't contain them — there's no blue, magenta or cyan in a
palette built for a bar and a focus ring. So each theme also carries an `ansi`
block. Themes with a published terminal palette (Catppuccin, Nord, Gruvbox,
Dracula, Tokyo Night, Rosé Pine, Everforest, Kanagawa, Solarized) use it
verbatim, quirks included — Rosé Pine maps "green" to a teal, Solarized's
bright slots are greys rather than brighter hues. The rest are hand-picked.
Omitting `ansi` is allowed and falls back to a derivation from the ten roles,
but it's flat: blue, magenta and cyan all collapse onto the accent.

One trap worth knowing if you ever edit the greeter's clock: SDDM reads a
theme's config through `QSettings(path, QSettings::IniFormat)`, and QSettings'
INI format treats an **unquoted comma as a list separator**. So a `DateFormat`
of `dddd, MMMM d` comes back as the two-element list `["dddd", "MMMM d"]`,
which `Clock.qml` then hands to `Date.toLocaleDateString(locale, format)` —
a function that takes a string or a format enum and nothing else. The month
silently disappears. The format here uses a middle dot instead of a comma for
that reason; quoting the value also works, but only because the reader happens
to be QSettings.

The login screen does **not** follow, by default. It uses SDDM's built-in
greeter, because the themed one left the primary display black — see "The
login screen" below. `local.sddm.theme = "astronaut"` turns the themed
version back on. Under noctalia it reads the shell's palette manifest rather
than a palette name; see "Theme sync under noctalia" next. SDDM only reads its
config when the greeter starts, so a change lands at the next logout or reboot
rather than immediately.

Wallpapers use `awww` (the renamed `swww`) over `~/.local/share/wallpapers`:
`Mod+Ctrl+W` picks one. The choice is remembered and
restored at login.

**Whose theme the machine follows** is `local.desktop.primaryUser`, which
defaults to `joshr`. Three things live outside any session and have to be
dressed from *someone's* choices: the SDDM greeter reads the theme and
wallpaper out of that user's `~/.local/state/niri-theme`, the limine boot menu
reads only the theme there, and plasmalogin copies Plasma's settings out of
their `~/.config`.

Each of those is a singleton — one login screen, one boot menu — so this
can't be generalised to "whoever is logged in" without the last person to
pick a theme deciding what the machine looks like at boot. Naming one owner
is the honest version. Pointing it at an account that never opens a niri
session isn't an error either: the sync services find no state file and leave
the greeter and boot menu on the default palette.

### Theme sync under noctalia

Everything above describes a palette that is **one of a finite list**. That is
true under the waybar stack, where a theme is a directory of rendered config
files built ahead of time and `theme-apply` moves a symlink between them.

It is not true under noctalia, and that mismatch is what this section is
about. Noctalia has four palette sources — the custom palettes generated from
`themes.nix`, its own ten builtins, a scheme derived from the current
wallpaper, and community schemes downloaded from `api.noctalia.dev` — and
only the first has a name a Nix derivation could have been built against. Pick
any of the other three and there is nothing prebuilt to point at.

**So the thing that travels is a palette, not a name.** Noctalia renders a
twenty-six line manifest of resolved colour roles to

```
~/.local/state/niri-theme/noctalia-resolved
```

on every colour-scheme change, and everything outside the session reads its
colours out of that file. It describes a wallpaper-derived scheme in exactly
the same lines it describes `gruvbox`.

| Follows | How |
|---|---|
| kitty, btop, cava, GTK, Qt, niri, starship | noctalia's own builtin templates |
| niri's inactive border | `noctalia-borders.kdl`, a user template overriding one line of the builtin niri one |
| Dolphin and every Qt app | `kdeglobals`, via the `active` symlink |
| VS Code | a generated one-theme extension, via the same symlink |
| wofi | `wofi.css` and `wofi-emoji.css`, via the same symlink |
| Vencord / Vesktop | a theme CSS written straight into their theme directories |
| Spotify | Noctalia CSS mounted over xpui's same-origin `colors.css` — see below |
| SDDM | `noctalia-resolved`, substituted into the greeter's config |
| limine | `noctalia-resolved`, rewritten into the boot menu's colour block; its NixOS wallpaper stays fixed |
| OBS, Discord, Papirus, PrismLauncher, zellij, Zen, Inkscape, Blender, fastfetch | community templates |

**Three of those were quietly broken**, all for the same reason, and the fix
is the reason this section exists.

`theme-apply` and home-manager's activation both used to write a palette name
into `~/.local/state/niri-theme/current` and repoint `active` at a prebuilt
directory. Under noctalia the shell writes `noctalia-live` there instead —
deliberately, because there is no name to write. Every `home-manager switch`
therefore ran that name through a `case` that could not match it and fell
through to the default: `active` came off the live directory, and `current`
was rewritten with a `themes.nix` name. The greeter, the boot menu and Spotify
were each keying off exactly that string, so all three went to the built-in
default while the desktop stayed on whatever noctalia was holding in memory.

What changed:

- Activation no longer touches `current` under noctalia, and points `active`
  at `noctalia-live` rather than at a prebuilt palette.
- The greeter is **one** `sddm-astronaut` package instead of one per palette,
  and its colours come from a runtime file. The `/etc/sddm.conf.d` drop-in
  that used to select between packages is gone (the sync still deletes it, so
  an already-deployed machine doesn't keep a stale one).
- The boot menu keeps a single build-time block as its fallback, and reads the
  manifest for everything else.
- Spotify is one Spicetify build instead of thirty. Its colours arrive at
  runtime: noctalia renders `--spice-*` custom properties to a file, and the
  launcher bind-mounts it over Spicetify's own `xpui/colors.css` inside a
  private mount namespace. Spotify therefore loads it from its existing
  same-origin stylesheet link. See "Spotify" below — the mount and
  Spicetify's two colour families are the non-obvious parts.
- `noctalia-builtin-themes.nix` — a 500-line hand transcription of noctalia's
  own builtin palettes, kept so the greeter and boot menu could be given a
  prebuilt match — is deleted. Nothing could ever select it.

**Two things had been leaning on that clobbering** without anyone noticing,
because it kept `active` pointing at a directory that had *every* rendered
file in it. Both are fixed by making noctalia write what it needs rather than
by putting the clobbering back:

- **niri's theme include.** See "`optional=true` on the niri include" above:
  `config.kdl` now emits one include, chosen by shell, instead of two.
- **wofi's stylesheets.** wofi is no longer the launcher under noctalia, but
  `theme-menu`, `wallpaper-menu` and `session-menu` still drive it as a plain
  `--dmenu` and the emoji picker passes it a second sheet with bigger rows.
  Both are named under `active`, so two user templates now render `wofi.css`
  and `wofi-emoji.css` into the live directory. They are the same stylesheets
  `theming.nix` produces, with one improvement the move made free: the text on
  a selected row is `on_primary` rather than the palette's background colour,
  which is the same light-palette assumption `noctalia-palettes.nix` already
  stopped making.

**Community templates** are on, listed by catalog id in
`home/joshr/niri/noctalia.nix`. They come from `noctalia-dev/community-templates`,
are fetched from `api.noctalia.dev` on first use and cached under
`~/.cache/noctalia`. That is a runtime fetch in a config that otherwise pins
every input in `flake.lock`, and the tradeoff is taken on purpose: these are
apps whose theming would otherwise have to be reimplemented here one renderer
at a time, against config formats upstream already tracks. Nothing in the
session depends on them — the shell, the terminal, GTK, Qt and the greeter are
all builtin or user templates — so a failed fetch costs those apps their
colours and nothing else.

Three of them need something on this side to work at all, and each is a
seed-if-missing activation step rather than a store symlink, because the
template's hook edits the file in place:

- **OBS** uses the community `matugen.obt`, selected by id
  (`com.obsproject.matugen`) in `~/.config/obs-studio/user.ini`. This replaces
  a local `.ovt` child theme that extended OBS's bundled `System` theme and
  inferred its colours from `kdeglobals` — three indirections to arrive at a
  palette OBS was only ever guessing at, plus an icon override to undo one
  consequence of the guess.
- **fastfetch** refuses to apply without `~/.config/fastfetch/config.jsonc`,
  and then refuses again if it is JSONC rather than strict JSON. A strict-JSON
  seed is installed if that file is absent. This is deliberately *not* the
  fish greeting's config — that one is `~/.smallfetch.jsonc`, is shared with
  root and the servers, and has comments in it.
- **Papirus** recolours folder icons in place, and looks for a writable copy at
  `~/.local/share/icons/Papirus` — failing over to `/usr/share/icons/Papirus`,
  which does not exist on NixOS. Papirus, Papirus-Dark and Papirus-Light are
  copied there once, which is a hundred megabytes or so of home directory and
  the price of that template working.

The community `spicetify` template is deliberately not enabled. Its Comfy and
Colorful `color.ini` files are inputs to the Spicetify CLI, and its hook runs
`spicetify apply` against a mutable Spotify tree. Neither exists at runtime
here: `mkSpicetify` already applied the Text theme inside the read-only Nix
store, and the CLI is only a build input. `~/.config/spicetify` is therefore not
state this profile needs or regenerates. Spotify's live colours use the route
described next instead.

#### Spotify

A Spicetify build is immutable — `mkSpicetify` patches Spotify's xpui bundle
inside a derivation — so the palette cannot be baked in. What makes it follow
anyway is that the Text theme's stylesheet is written entirely in
`var(--spice-*)` custom properties, with no hardcoded colours at all: redefine
those on `:root` at runtime and the whole UI moves.

The chain is four links:

1. noctalia's `spotify` user template renders the properties to
   `~/.local/state/noctalia-spotify/colors.css` on every colour-scheme change
2. Spicetify generates `share/spotify/Apps/xpui/colors.css` and adds a relative
   `<link rel="stylesheet" href="colors.css">` to `xpui/index.html`
3. the `spotify` launcher gives the process a private mount namespace and
   mounts noctalia's file over that generated stylesheet
4. Spicetify's `inject_theme_js` copies the theme's `theme.js` to
   `xpui/extensions/theme.js` and adds `<script defer>` for it to `index.html`

The old design put a Python server on `127.0.0.1:38471` and fetched its CSS
from the xpui renderer. That crossed from Spotify's public HTTPS origin into
the loopback address space, so it depended on the embedded Chromium build's
Private Network Access and Local Network Access behaviour. Adding preflight
headers and then a Chromium feature flag still left Spotify on Nord — the
build-time fallback — which is direct evidence that the live stylesheet was
not becoming effective. There is no reason for palette transport to cross a
browser security boundary at all.

The launcher now uses bubblewrap only as a **mount namespace**, not as an
application sandbox: `--bind / /` preserves the host filesystem and its
permissions, and a second read-only bind replaces only xpui's `colors.css` in
Spotify's view. The Nix store is not modified. No loopback service, CORS/PNA
response, LNA permission or Chromium exception is involved.

**The colour variables also have two families.** Spicetify defines every
scheme colour *twice* — `--spice-<name>` as a hex literal and
`--spice-rgb-<name>` as a bare `r,g,b` triple, so a theme can write
`rgba(var(--spice-rgb-main), 0.5)` and vary the alpha. The Text theme uses
fifteen of the rgb variants; the template overrode none of them. Even with the
transport fixed, that would have re-themed the opaque surfaces and left every
translucent one — backgrounds, hovers, shadows — on the palette the Nix build
was made with, which reads worse than not following at all. Both families are
emitted now, from the same colour role.

The existing `<link rel="stylesheet" href="colors.css">` gets the mounted
palette in place as the window starts. The injected script polls
`/colors.css` with `cache: "no-store"` so an *already open* Spotify follows a
later palette change; because that URL is same-origin, the fetch needs no
special browser permission. Noctalia rewrites the mounted source file in
place, so the namespace continues to see each update.

`~/.config/spicetify` is not runtime state for this profile and deleting it is
safe. It is intentionally **not regenerated**: `mkSpicetify` performs the CLI
work during the Nix build. The live input is
`~/.local/state/noctalia-spotify/colors.css`; restart the noctalia user service
to render it again, rebuild to replace the immutable Spotify package, and
restart Spotify so the new launcher supplies the mount.

### Keys

| Key | Action |
|---|---|
| `Mod+Return` / `Mod+D` / `Mod+E` / `Mod+B` | terminal, launcher, Dolphin, browser |
| `Mod+Ctrl+E` | ranger, in a terminal |
| `Mod+Ctrl+V` | clipboard history |
| `Mod+.` | emoji picker |
| `Mod+Q` / `Mod+O` | close window, overview |
| `Mod+H/J/K` | focus (arrows also work; `Mod+L` is lock, so use `Mod+Right`) |
| `Mod+1..5` | named workspaces |
| `Mod+R` / `Mod+F` / `Mod+V` | preset widths, maximize, float |
| `Mod+W` | tab the focused column — its windows stack, one shown at a time |
| `Print` / `Mod+Shift+S` | region screenshot on a frozen screen, annotated in satty |
| `Shift+Print` / `Mod+Ctrl+S` | same overlay, opened on last time's region — Enter takes it |
| `Ctrl+Print` / `Alt+Print` | screen / window (window is niri's built-in) |
| `Mod+L` / `Mod+Shift+Escape` | lock, session menu |
| `Mod+Shift+L` | lock **and** blank the monitors, in one key |
| `Mod+Escape` | blank the monitors — works on the lock screen too |
| `Mod+Shift+I` | stay awake — toggle the idle inhibitor |
| `Mod+G` | GameMode — animations, blur, transparency and monitoring off |
| `Mod+Ctrl+T` | pick a theme |
| `Mod+Ctrl+W` | pick a wallpaper |
| volume / brightness keys | change it and show an OSD — see "The on-screen display" |
| `Mod+P` / `Mod+Ctrl+P` | next / previous power profile — the OSD follows the daemon |
| `Mod`+scroll / `Mod+Shift`+scroll | walk windows / workspaces (wheel and touchpad) |

`Mod+W` is the one that isn't guessable from the key. A column normally
divides its height between the windows stacked in it, so a column of four is
four short windows. Tabbed, they share one full-height slot and only the
focused one is drawn, with an indicator marking the rest — the column still
takes one slot on the strip, and `Mod+K`/`Mod+J` walk the tabs. `Mod+W` again
puts the stack back. Nothing moves in or out of the column either way; it's
purely how the column is drawn.

`Mod+Shift+Slash` shows niri's own **Important Hotkeys** overlay. That's a
shorter list than the table above: niri hardcodes the entries it considers
important, and anything else appears only if its bind carries a
`hotkey-overlay-title`. `Mod+W` is given one for exactly that reason — the
titled binds land after the hardcoded ones. Scroll binds can't appear there
at all, so `Mod`+scroll stays a table-only entry.

### Clipboard history

`Mod+Ctrl+V` opens the history in wofi; picking an entry puts it back on the
clipboard. `clipboard-wipe` empties it, and isn't bound to a key on purpose.

**Removing single entries**, two ways, because wofi has no way to put a button
on a row:

- **`Delete`** in the picker removes the entry under the cursor and reopens
  it, so several can go in a row.
- **`✕  Delete entries…`**, the first row of the list, switches the picker
  into a mode where Enter — or a mouse click — removes instead of copies.
  `←  Back to copying` returns. This is the discoverable version, and the
  only one reachable with a mouse.

`Backspace` is deliberately not bound. wofi's dmenu mode puts the cursor in a
search box and Backspace is how you correct what you typed there, so binding
it would make the history impossible to search. `Delete` is free, which is
why it's the one. Adding another (`Shift-BackSpace`, say) is one more
`--define=key_custom_1=…` in `clipboard.nix` plus its exit code in the case
at the bottom of the loop.

The bind is passed with wofi's `--define`, not set in `programs.wofi.settings`
— that config is shared with the launcher and the theme, wallpaper and session
menus, and binding `Delete` globally would arm a delete exit code in all of
them. One caveat from wofi(5): a custom key *"will not cause wofi to exit, it
will only set its exit code for when it does"*, so on wofi 1.5.3 `Delete` takes
effect when the picker is next dismissed. Either way it's the entry under the
cursor that goes, and the script handles both behaviours.

Wayland has no clipboard manager in the compositor — a copied selection lives
in the process that copied it and vanishes when that process exits, which is
why closing a browser tab loses what you just copied out of it. `cliphist`
plugs that hole: home-manager runs it as two `wl-paste --watch` user services,
one for text and one for images, and it keeps the last 300 entries.

Images are stored too. They show in the picker as `[[ binary data … ]]`;
choosing one puts the real image back on the clipboard, so pasting into an
image-aware app still works.

`Mod+V` and `Mod+Shift+V` were already float and float/tile focus, hence the
third spelling.

See `home/joshr/niri/clipboard.nix`.

### Emoji picker

`Mod+.`, because that's the key Windows uses and that reflex is the whole
reason it exists. Type to search by name, `Enter` to pick, `Escape` to
cancel — and what you use most floats to the top of the list next time.

The emoji is **typed into the focused window and put on the clipboard**, both.
Typing alone would be the closer copy of Windows, but it depends on the window
accepting synthetic keystrokes, and when one doesn't there'd be nothing to
show for the keypress. The clipboard is the fallback that's already in place
by the time typing is attempted. `cliphist` keeps whatever selection it
displaced, so nothing is lost either way.

It's [`bemoji`](https://github.com/marty-oehme/bemoji) driving wofi, with two
things changed:

- **The list is built at build time**, not downloaded. bemoji normally curls
  `unicode.org/Public/emoji/latest/emoji-test.txt` into `~/.local/share/bemoji`
  on first run. That puts a keybind behind the network, behind a `latest` URL
  that moves, and behind mutable state no rebuild reproduces — so the same
  transformation runs in a derivation instead, against the pinned copy in
  `pkgs.unicode-emoji`, and `BEMOJI_DB_LOCATION` points at the store path.
  Pointing it there also settles the download question permanently: bemoji only
  fetches when that directory comes back empty, and a store path never is. The
  derivation fails the build if the parse yields fewer than a thousand entries,
  so a format change upstream stops the rebuild rather than shipping an empty
  picker.
- **Typing goes through a wrapper** that sleeps 150 ms first. `wtype` starts
  the moment wofi exits, and niri needs a beat to hand focus back to the
  window underneath; without the pause the keystrokes can land while nothing
  is focused yet.

Only the picker's own history at `~/.local/state/bemoji` is mutable. Adding
another list — symbols, kaomoji — means adding a file to the derivation in
`emoji.nix`, not dropping one in a directory.

`Mod+.` used to be `expel-window-from-column`, which moved to
`Mod+Shift+Period`. `Mod+BracketLeft` / `Mod+BracketRight` already consume and
expel, and they're the pair that reads as a direction, so nothing is really
lost.

The picker gets its own stylesheet, `wofi-emoji.css`, generated from the same
palette as `wofi.css` with rows at 20px — big enough to tell 😀 from 😃 at a
glance, with the search box left at the normal size. It follows theme
switches like everything else.

**The font is Microsoft's Fluent Emoji**, which is what makes this look like
the thing `Win+.` opens rather than like Android. nixpkgs has no Fluent Emoji
font — Microsoft publishes `fluentui-emoji` as loose SVG and PNG assets and
the packaging request ([nixpkgs#347889](https://github.com/NixOS/nixpkgs/issues/347889))
was closed as not planned — so `modules/nixos/emoji.nix` packages
[tetunori/fluent-emoji-webfont](https://github.com/tetunori/fluent-emoji-webfont),
a build of those assets into a real font, pinned to its v0.8.5 commit. It's
set as `fonts.fontconfig.defaultFonts.emoji`, so it's what Firefox, kitty,
Discord and everything else draw too, with `noto-fonts-color-emoji` left
behind it to cover anything Unicode has added since the Fluent set was last
built.

It is an 87 MB font, which is most of what this costs. The build carries three
colour formats for the same 33k glyphs — CBDT bitmaps, COLRv1 vectors and
OT-SVG — because it's meant for browsers, where which one gets used depends on
the engine. FreeType needs one of them. It ships whole anyway: stripping tables
means a fonttools pass whose output would have to be trusted sight-unseen, and
a silently broken emoji font is worse than a large one.

See `home/joshr/niri/emoji.nix` and `modules/nixos/emoji.nix`.

On the Plasma hosts the font applies just the same, and `Meta+.` is already
KDE's own emoji picker (`plasma-emojier`). That default is restated explicitly
in `home/joshr/plasma.nix` — the one place that file states a stock KDE
default on purpose — so the same key can't quietly mean different things
depending on which session booted.

### Staying awake

`Mod+Shift+I`, or the coffee-cup icon in the bar, holds the machine awake.
The icon is dim when idling is normal and lit when the inhibitor is on — it's
a mode that's easy to leave running by accident, so it's meant to be obvious.
Clicking and keying run the same script, and the state lives in
`idle-inhibit.service`, so the two can't disagree.

It holds off two unrelated mechanisms, which is why it isn't a one-liner:

- **swayidle** dims, locks and blanks. It takes its cue from the compositor's
  idle-notify protocol, not from logind, so a logind inhibitor does nothing to
  it — the timer is stopped outright and restarted on the way back.
- **logind** handles the idle action, sleep, and the lid switch.
  `systemd-inhibit` holds a block lock on all three for as long as the unit
  runs.

This isn't waybar's built-in `idle_inhibitor` module. That one takes a Wayland
idle-inhibit lock on waybar's own surface — a perfectly good mechanism, but it
can only be toggled by clicking, with no IPC for a keybind to use, and it
wouldn't stop logind suspending the machine.

The inhibitor is per session, and half of what it holds is not. Your own dim,
lock and blank stop, and *the machine* stops sleeping — that half is logind's
and applies to everyone — but another logged-in user's timers keep running in
their own session, where they can lock that session and nothing more. See
[Idle actions stop at the session
boundary](#idle-actions-stop-at-the-session-boundary).

### GameMode

`Mod+G` strips the desktop back: no animations, no blur, no transparency, no
shadows, and the shell stops sampling the machine. It stays on until it is
turned off, and the bar's controller pad is lit the whole time it is.

`gamemoderun` puts the session into it at the start of a game and takes it
back out at the end, so most of the time the key is not the way in. It is
there for everything else you might want the frames for — a recording, a
stream, a compile, a game that doesn't go through gamemode at all.

`programs.gamemode` already does the *system* half of this — governor,
scheduler, the card's power profile, and taking video memory back off the
model server (see ["The card is also the model
server"](#the-card-is-also-the-model-server)). None of that touches the
desktop, and the desktop on this session is not free:

- **niri blurs the bar.** It implements `ext-background-effect-v1`, noctalia
  asks for a blur region covering the whole bar, and the answer is a
  three-pass dual-Kawase blur run whenever that region is redrawn. It is asked
  for unconditionally, so making the bar opaque does not stop it — only
  turning blur off does.
- **noctalia animates everything it draws**, through one motion service:
  widgets, panels, OSDs, toasts.
- **Both composite translucent surfaces.** A translucent surface has to be
  blended against what is behind it rather than written over it.
- **The audio visualisers repaint from a live stream.** The bar's and the lock
  screen's both read a PipeWire spectrum and redraw every frame while anything
  is playing — and the lock screen's covers a whole output.
- **noctalia samples the machine on a timer** whether or not anything is
  displaying the numbers. `[system.monitor]` reads `/proc` every two seconds
  and `dlopen`s `libnvidia-ml` to ask the card for its temperature and VRAM
  every five — a second NVML client on the card the game is using.

So GameMode turns off exactly those: `animations` and `blur` in niri;
`shell.animation`, the bar/panel/notification/OSD opacities,
`shell.panel.transparency_mode`, both shadows, both audio visualisers and
`system.monitor` in noctalia.

#### How it changes two read-only config files

Both config files are symlinks into the store, so nothing can edit them.
Both readers merge more than one file, and both notice a new one arriving —
that is the whole mechanism. Turning GameMode on writes two files; turning it
off deletes them.

| | file | why it wins |
|---|---|---|
| niri | `~/.config/niri/gamemode.kdl` | `include`d as the **last line** of `config.kdl`; niri merges duplicate sections in document order and the later definition wins |
| noctalia | `~/.config/noctalia/gamemode.toml` | every `*.toml` directly in the config directory is deep-merged in sorted filename order, and `gamemode` sorts after `config` |

The include line being last is load-bearing, and silent if it is wrong. Move
it up alongside the theme includes at the top of `config.kdl` and the
`animations { slowdown 0.7 }` further down wins again — GameMode would animate
exactly as before, with nothing anywhere to say why.

Both readers pick the change up themselves, but not symmetrically. niri's
watcher polls the *include* paths as well as `config.kdl` every 500 ms and
records a missing one as absent, so the file appearing and the file being
deleted are both changes it reloads on. noctalia's inotify mask is
`IN_MODIFY | IN_CLOSE_WRITE | IN_CREATE | IN_MOVED_TO` — **no `IN_DELETE`** —
so it hears the overlay arrive and never hears it leave. `noctalia msg
config-reload` closes that gap, and is sent in both directions so there is one
code path rather than two.

#### Who turned it on, and what turns it off

The state is `~/.local/state/niri-gamemode/owner`, and the word in it is why
the file exists rather than just the two overlays:

- **`Mod+G` always toggles**, and takes ownership. It has to visibly work
  even mid-game.
- **A game starting** engages the mode if nothing already has, and leaves an
  existing owner alone — so it does not quietly downgrade a manual hold.
- **A game ending** disengages only if the owner is the game.

Which means: turn it on by hand, play something, quit — and it is still on,
because you turned it on. Play something with GameMode off and quit, and it
goes away with the game.

It is deliberately not runtime state, so the mode survives a relogin. The cost
is that a machine which hard-locked mid-game comes back still in GameMode;
what makes that survivable is that the bar says so, and `Mod+G` clears it.

`niri-gamemode` is on `PATH` for the times the key isn't to hand:

```
niri-gamemode status     # game | manual | daemon | off
niri-gamemode off
```

#### How gamemoderun reaches a home-manager script

`modules/nixos/gaming.nix` is a NixOS module, so it cannot name a store path
home-manager built, and it cannot find one by name either — gamemoded's own
`PATH` is nearly empty, which is why every other command in those hooks is
written as an absolute store path.

A *unit name* crosses that gap where a path cannot. gamemoded runs under the
user's own systemd manager — `systemd.user.services.gamemoded` in nixpkgs'
`programs.gamemode` module, D-Bus activated on the session bus, which is also
why the hooks can call `notify-send` — so `systemctl --user` is always
reachable from a hook. `home/joshr/niri/gamemode.nix` declares
`niri-gamemode-start.service` and `niri-gamemode-stop.service`; the hooks ask
whether the unit exists and, if it does, start it with `--no-block`. On a
Plasma login, on root, on any account without the niri profile, it simply does
not exist and nothing happens — no session has to be identified. A unit that
*does* exist and fails gets a line in `journalctl --user -u gamemoded`.

**The two unit names are written in two files and nothing checks that they
agree**, the same standing arrangement as `SIGRTMIN+9` next door.

#### Why both hooks are single store paths

This bit is a trap, and it caught this repo once. **gamemoded will not accept a
`custom.start` or `custom.end` longer than 255 bytes, and it drops the whole
value rather than truncating it.** `append_value_to_list` in
`daemon/gamemode-config.c` copies into a `CONFIG_VALUE_MAX` buffer, notices the
result came out unterminated, logs

```
Config: Could not add [...] to [start], exceeds length limit of 256
```

and blanks the entry. The hook does not run in a reduced form — it does not run
at all, and the only evidence is that line in gamemoded's journal.

255 bytes is not much for a config written in Nix, where every command is an
absolute store path costing seventy-odd bytes before its arguments. The hooks
here were a pair of shell one-liners at about 200 bytes; adding the
`systemctl --user` hand-off took them to about 335, and both silently stopped
running — no session GameMode, no bar poke, and no "GameMode started"
notification either.

So each hook is now exactly one store path — `gamemode-start-hook` and
`gamemode-end-hook`, both `writeShellApplication`s — which is about 87 bytes
whatever the script grows into. `hookScript` in `gaming.nix` asserts the length
anyway, so the next thing appended there fails the build with the reason
instead of disappearing.

`gamemoderun` still runs each value through `/bin/sh -c`, so a shell line would
work; and a bare store path works with no `PATH` to find it on because nixpkgs'
module `mkForce`s gamemoded's `PATH` to a link farm holding `pkexec` and
nothing else.

#### The two audio visualisers, and where the overlay is written

The visualisers are the only things in the session drawn from a live audio
stream — a PipeWire spectrum read and a repaint every frame for as long as
something is playing — so GameMode switches both off. They need two different
mechanisms, because noctalia models them differently:

- **The bar's** (`local.waybar.cavaInBar`) is a lane entry. A bar widget has no
  `enabled` of its own — `WidgetConfig` is a type and a settings map, nothing
  else — and a deep merge replaces an array wholesale, so the only way to drop
  one entry is to restate `bar.main.end` without it.
- **The lock screen's** (`local.niri.cavaInLockscreen`) is a placed object, and
  `DesktopWidgetState` *does* carry an `enabled` the host checks before it
  builds anything. So that one is switched off by name, and `widget_order` is
  left completely alone — which matters, because `widget_order` is the
  definitive membership list and an overlay that restated it would be one stale
  entry away from dropping the login box.

Restating the bar lane is the reason **the noctalia half of the overlay is
generated in `noctalia.nix`, not in `gamemode.nix`**. A second copy of the lane
kept in another file would drift from the real one the first time the bar is
reordered; generated next to the lane, it is `lib.filter` over the same list
and cannot. The lock visualisers are found the same way — by widget *type*
rather than by rebuilding `audio_visualizer_<connector>`, so nothing has to
know a second time how those ids are made.

`noctalia.nix` writes the result to
`~/.local/share/niri-gamemode/noctalia.toml` and `niri-gamemode` copies it into
place. A path rather than a module argument, because `noctalia.nix` already
consumes what `gamemode.nix` publishes (the bar plugin's command) and an
argument back the other way would be a cycle. It is deliberately not installed
in `~/.config/noctalia`: everything named `*.toml` there is loaded, so a file
kept in that directory would be a GameMode that is always on.

The split leaves each file owning what it already describes — `gamemode.nix`
the mode, the state and the niri overlay; `noctalia.nix` everything about the
shell, including what the shell looks like in GameMode.

### No automatic sleep on mains power

Separate from the toggle above, and always on: while the machine is plugged
in, it never suspends on an idle timer. `modules/nixos/power.nix`, option
`local.power.noAutoSleepOnAC`, imported by `base.nix` so every host has it.

There is no single "auto-sleep" switch to flip, because automatic suspend can
come from more than one place and they don't know about each other. So this
holds a logind **idle** inhibitor for as long as a mains supply reports
`online`, and anything that asks logind — Plasma's powerdevil included — then
treats the session as busy. `ExecCondition` re-checks the power source each
time the unit starts, and a udev rule restarts it on any `power_supply` event,
so plugging and unplugging just re-evaluate the one condition. That check
follows systemd's own `on_ac_power()` rule — any supply that isn't a battery
and reports `online` non-zero — which is what makes a USB-C-charged laptop
(supply type `USB`, `online` 2) count as plugged in. A machine with no battery
at all counts as permanently on mains, so on the desk and the server the
inhibitor just stays up.

`--what=idle`, not `idle:sleep`, and that distinction is the whole point: a
*sleep* inhibitor blocks every suspend including a deliberate one, so
`systemctl suspend`, the session menu's "Suspend" and the lid switch would
all stop working. An *idle* inhibitor blocks only the timer-driven path.

Locking, dimming and blanking are untouched — those are swayidle under niri
and powerdevil under Plasma, and "don't fall asleep" is not "don't lock the
screen". On battery, nothing changes at all. The Plasma hosts also set
`powerdevil.AC.autoSuspend.action = "nothing"` directly, so the behaviour
doesn't rest on one daemon asking another the right question.

### The lid

Three cases:

| Lid closed… | What happens |
| --- | --- |
| on battery | suspend |
| on mains, nothing else attached | lock the session |
| docked | nothing |

**"Docked" is logind's own definition, and it's broader than a dock**: an ACPI
dock station reporting docked, *or* at least one external display connected.
Shutting a laptop that's driving a monitor is the case that wants nothing to
happen — the session stays up on the external screen rather than locking
behind a lid nobody was looking at.

The order those are tested in is what makes that hold, and it's logind's
rather than ours: docked first, then external power, then the plain case. A
dock supplies power, so the other order would never reach the docked rule and
a docked laptop would lock.

`modules/nixos/laptop.nix` owns the logind half — the three
`services.logind.settings.Login` keys. `HandleLidSwitchExternalPower` is
ignored entirely unless it's set, for backwards compatibility, so leaving it
out doesn't mean "do nothing on mains", it means mains falls through to
`HandleLidSwitch` and suspends. `lock` doesn't suspend: it asks every session
to lock, which under niri is swayidle's `lock` event running `lock-now`,
the same path `loginctl lock-session` takes. On battery the lock still happens
one step later, from swayidle's `before-sleep`, so the machine never resumes
unlocked either way.

`lock` and `suspend` differ in one place, and that's logind's doing rather than
a setting: while the lid stays shut logind keeps re-evaluating which of the
three cases applies, but the lock is only ever sent on the closing edge — a
no-op on those rechecks, or it would re-lock on every wakeup. So pulling the
monitor out of an already-closed laptop suspends it if that leaves it on
battery, and leaves the session as it was if it's still plugged in. Opening
and shutting the lid locks it.

The mains inhibitor from the section above doesn't get in the way, even
though "on mains" is exactly when it's held: `LidSwitchIgnoreInhibited`
defaults to yes, so lid handling ignores the high-level idle and sleep locks.
The low-level `handle-lid-switch` lock is always honoured, which is why
`Mod+Shift+I` still stops the lid doing anything at all.

What happens to the *panel* is niri's business rather than logind's, and it
lines up with the table: with an external monitor connected niri turns the
built-in one off when the lid shuts, so the docked case leaves a working
desktop on the monitor. With no external monitor it leaves the panel on —
disabling the only output would leave the session with nowhere to draw — so
the lock screen sits behind a closed lid until swayidle blanks it on its own
timer.

**Under Plasma, none of those keys fire.** powerdevil takes a block inhibitor
on `handle-lid-switch` at session start ("KDE handles power events") and
handles the lid itself, so the same three cases are restated for it in
`home/joshr/laptop.nix`: `lockScreen` on AC, `sleep` on battery, and
`inhibitLidActionWhenExternalMonitorConnected` for the docked case — powerdevil
has no docked profile, it has a per-profile "don't act when an external
monitor is connected", which is the same rule written from the other side.
The logind half still covers the greeter and a bare TTY there, which is why
both are set. Sleeping locks on the way back either way: that's
`kscreenlocker.lockOnResume` in `home/joshr/plasma.nix`.

It didn't always live in one place per session. `modules/nixos/niri.nix` set
the same three logind keys and disagreed with `laptop.nix`, and two modules
setting one option to different values is a conflict NixOS refuses to merge —
`laptop-niri` imports both, so that host could not evaluate at all. A lid is
hardware rather than a desktop session, which is why `laptop.nix` is where it
lives; `niri.nix` also runs on `gamestation-niri`, which has no lid.

### Coming back from suspend

Two things on the desk don't survive a sleep on their own, and neither is the
session's fault — both are fixed at the system level.

**The NVIDIA card.** By default the driver throws video memory away when the
machine suspends. Nothing warns you: the suspend works, the machine wakes, the
fans spin, and the session never comes back — niri's framebuffers, textures
and every GL/Vulkan context lived in memory the driver no longer has, so it
can't take the GPU back and you get a black screen on a machine that is
otherwise running. SSH answering while the monitors stay dark is the quickest
way to prove that's what happened.

`hardware.nvidia.powerManagement.enable` (`modules/nixos/nvidia.nix`) is the
fix, and it's three things at once: `NVreg_PreserveVideoMemoryAllocations=1`
on the nvidia module, `nvidia-suspend.service` and `nvidia-hibernate.service`
ordered *before* the systemd unit that does the sleeping so the save happens
while there's still a machine to save from, and `nvidia-resume.service`
ordered *after* both to put the memory back. All three are `nvidia-sleep.sh`;
nixpkgs generates the units. After a rebuild:

```bash
systemctl list-unit-files 'nvidia-*'
grep PreserveVideoMemoryAllocations /proc/driver/nvidia/params
```

`powerManagement.kernelSuspendNotifier` is pinned off there, and that line
looks redundant but isn't. The driver has a second mechanism — it hooks the
kernel's own PM notifier chain and does the save and restore itself, no
systemd units involved — and nixpkgs turns that on **by default** for the open
kernel modules on a driver this new. When it's on, none of the three services
are generated, so a rebuild leaves `systemctl list-unit-files 'nvidia-*'` just
as empty as it was and it looks like nothing changed. False keeps the systemd
path, which is the older and far more travelled of the two; deleting the line
is how to try the newer one, and it's worth trying if resume is still
unreliable with the services in place.

The saved video memory goes to a file under `/tmp`
(`NVreg_TemporaryFilePath`), which on this machine is a directory on the root
btrfs subvolume — real disk, which is what it needs to be. If `boot.tmp.useTmpfs`
is ever switched on here, point that parameter somewhere on disk in the same
breath, or the "save" becomes a copy from RAM to RAM: double the memory for a
suspend, and hibernation stops working entirely.

```nix
hardware.nvidia.moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
```

**The RGB lighting.** Suspend cuts power to the controllers, and they only
hold what was last written to them — USB ones are re-enumerated on the way
back up and the ones on the board return to their firmware default, which is
usually the rainbow. Nothing re-applies the profile, so the lighting is right
until the first suspend and wrong from then until the next login.
`modules/nixos/openrgb.nix` adds `openrgb-resume.service`, which re-applies
`local.openrgb.profile` after every sleep (`local.openrgb.applyOnResume` to
turn it off).

It runs as `local.desktop.primaryUser` rather than root, because profiles are
runtime state living in that account's `~/.config/OpenRGB` — root would find
nothing there and say so. It waits five seconds first, because systemd calls
the resume finished as soon as the kernel is back, which is well before USB
has re-enumerated; a run started at that instant simply doesn't see the
keyboard yet.

The unit is shaped the way `systemd.special(7)` recommends for "run something
on resume", and the way nixpkgs' own `powerManagement.resumeCommands` is: it's
`WantedBy` and `Before` `sleep.target` — one target that covers suspend,
hibernate, hybrid-sleep and suspend-then-hibernate — with the work in
`ExecStop`, since systemd stops units in the reverse of the order it started
them and "after `sleep.target` stops" is another way of saying "after the
machine wakes up". So `systemctl status openrgb-resume` reads `active
(exited)` whenever the machine is awake: that's the unit armed, not the unit
run. What it did last time is in the journal.

```bash
journalctl -u openrgb-resume -b
```

**The monitors' brightness** is the third, and it's the session's rather than
the system's — swayidle's `after-resume` (`lock.nix`) runs `brightness sync`
alongside the Dunst restart. Same shape of problem as the lighting, milder:
the displays lost power, a DDC/CI write sent while they had none went nowhere,
and nothing in the kernel noticed. `sync` asks each monitor what it is
actually at and re-asserts the level if the answer disagrees. See
[Brightness](#brightness).

### Displays

One file per host under `home/joshr/displays/`, kept separate so a monitor
change doesn't mean editing the session config. Empty means niri
auto-detects, which is what the laptop does.

```nix
# home/joshr/displays/gamestation.nix
local.niri.outputs = [
  { name = "DP-3"; mode = "2560x1440@180.000";
    position = { x = 0;    y = 0; }; focusAtStartup = true;
    variableRefreshRate = "on-demand"; }
  { name = "DP-2"; mode = "1920x1080@100.000";
    position = { x = 2560; y = 0; }; }
];
```

Get connector names and the modes each display actually reports with:

```bash
niri msg outputs
```

Three things worth knowing:

- **State the refresh rate.** A display's *preferred* mode is often not its
  fastest, so omitting it can silently leave a 180Hz panel at 60. The string
  has to match a mode the display reports or niri falls back and warns.
- **Positions are logical pixels**, so a scaled display occupies
  `width / scale`. Lay the next one out from there, not from its physical
  width. Above, DP-2 starts at x=2560 because DP-3 is unscaled.
- **niri has no "primary" display.** `focusAtStartup` decides where the
  session begins. To pin workspaces to a display, give them an
  `open-on-output` in the `workspace` declarations in `niri.nix`.

Also available per output: `scale`, `transform` (rotation),
`variableRefreshRate`, and `off`.

`variableRefreshRate` takes three values rather than a bool: `false`, `true`
(VRR held on), and `"on-demand"` (VRR only while a game is on that display).
The desk's 1440p panel is set to the third — see
[VRR, and the judder that isn't the game](#vrr-and-the-judder-that-isnt-the-game)
for what it is for and why the on-demand form is the one to want.

**Fractional scaling is off, and it is enforced in two places.** `scale`
takes an integer — the option's type rejects `1.5` at evaluation rather than
letting it reach the compositor — and every declared output is written out
with an explicit `scale 1` when the field is omitted. The second half is the
one that does the work: without it niri guesses a scale from the display's
physical size and resolution, and that guess is free to be fractional, so
"don't set a scale" is not the same as "don't get a fractional scale".

The reason is how a fractional scale reaches a client that can't ask for
one. A client speaking `wp-fractional-scale-v1` is told the real factor and
renders to it; everything else — most of XWayland, and a fair number of
toolkits running under it — is handed the next integer up and then
bilinearly downscaled by the compositor, which is resampling text that was
already rasterised and hinted. The result is soft in a way no font setting
corrects. At an integer scale that path doesn't exist: every client is
either scaled exactly or left alone.

What it costs is the middle of the range. A dense panel is either 1
(everything small, everything sharp) or 2 (everything large), with font
sizes covering what's left, and there is no 1.5 in between. That is the
trade being made deliberately. A host that wants it back changes the
option's type in `home/common/options.nix` and the unconditional `scale`
line in `renderOutput` in `home/joshr/niri/niri.nix` — both, or the type
change alone will do nothing.

**The greeter does not follow the display config, deliberately.** Several
attempts to make it do so are gone; see "The login screen" below for why. The
greeter auto-detects, which lights up every connected display at kwin's choice
of mode and arrangement.


**Workspaces follow a display** via `local.niri.workspaceOutput` in the same
file. niri creates a workspace on whichever output is focused at the time, so
without it the numbered workspaces scatter across displays depending on where
you were when you first used each one. The desk pins them to `DP-3`.

### Brightness

The brightness keys worked on the laptop and did nothing on the desk for a
while, with the same package installed and the same binding on both. The
difference is hardware, not config.

`/sys/class/backlight` only ever contains **internal** panels — a display
whose backlight PWM the GPU driver owns. A monitor on DisplayPort or HDMI
never appears there, because its backlight is inside the monitor. So on a
desktop that directory is empty, and everything pointed at it silently does
nothing: the keys, and the pre-lock dim in `lock.nix` as well.

An external monitor is reached over **DDC/CI** instead, a small command set it
answers on the i2c bus alongside the video link. `modules/nixos/ddcci.nix`
loads `ddcci-backlight`, which speaks that in the kernel and registers each
monitor as an ordinary backlight device — so the existing keys and timers work
unchanged rather than needing a second code path.

```nix
# hosts/gamestation-niri/configuration.nix
local.backlight.ddcci.enable = true;
```

It needs a **reboot**, not just a switch — it's a kernel module. Then:

```bash
ls /sys/class/backlight/    # expect a ddcci* per monitor
ddcutil detect              # what DDC/CI itself can see
```

If a monitor is missing, check DDC/CI is enabled in its OSD — some vendors
ship it off, and call it "MCCS". If it's still missing, compare the adapter
names against `local.backlight.ddcci.busNameMatch`:

```bash
cat /sys/bus/i2c/devices/i2c-*/name
```

Buses are matched by name rather than probed blindly on purpose: most i2c
buses on a desktop are SMBus segments carrying RAM and RGB hardware, not
displays, and this machine already runs `acpi_enforce_resources=lax` so
OpenRGB can reach some of them.

Two things worth knowing:

- **DDC/CI is slow** — a write is a round trip on the order of 100ms per
  display, where a laptop panel is instant. The `brightness` helper
  (`scripts.nix`) drops overlapping presses rather than queueing them, so a
  held key doesn't keep climbing after you let go.
- **The keys drive every display**, which is why they call that helper and
  not `brightnessctl` directly. `brightnessctl` with no `--device` adjusts
  the *first* device it finds — invisible with one internal panel, wrong
  with one device per monitor. The bar's brightness module scrolls through
  the same helper for the same reason, so the keys and the scroll can't
  drift apart. See "The bar".

Not enabled on the Plasma variant of the desk. It would work, but it would
also hand powerdevil's idle timer real dimming on displays it currently can't
touch.

#### A monitor is a thing that can refuse

Everything below is one consequence: on a desk, writing a brightness is not
setting a register, it is sending a request to another computer that may not
be listening. A laptop panel never refuses. A monitor does — while it is
asleep behind DPMS, while it is bringing its link back up, or because its
firmware felt like it.

**The driver does not check.** `ddcci-backlight`'s update path sends the
command and reports success whether or not anything took it, so
`/sys/class/backlight/<dev>/brightness` is only ever *the last value written*.
There is a second attribute that is honest: reading `actual_brightness` makes
the driver go and ask the monitor, a live VCP 0x10 read over i2c.

Those two files are the whole of it, because different things were reading
different ones. waybar's `backlight` module reads `actual_brightness` — the
truth. The `brightness` helper used to read `brightness` — the intent. So
after a single write a monitor missed, the bar said one thing, the pop-up said
another, and the panel in front of you agreed with neither.

It got worse from there, because `brightnessctl`'s relative steps are computed
from `brightness` too. Once sysfs believed the display was at 100% and it was
actually at 20%, every press of the up key asked for 105%, got clamped to 100%,
and changed nothing. **The keys appeared dead**, and stayed that way until you
pressed *down* enough times to come back under 20.

The fixes, all in `brightness` (`scripts.nix`):

- **Everything reads `actual_brightness`**, falling back to `brightness` only
  when the monitor won't answer. The bar and the OSD now quote the same
  attribute of the same display, and a key press steps from where the screen
  really is — so a display that has drifted is corrected by the next press
  rather than becoming permanently unreachable. Computing the target here is
  also why the clamping is now the script's; `brightnessctl` is handed an
  absolute value.
- **`brightness sync`** re-asserts every display's intended level and waits
  for it to take: write, ask the monitor, write again if the answer disagrees,
  up to six attempts a second apart. This is the repair for a write that
  landed on something asleep. It gives up quietly rather than hanging, and
  when everything already agrees it is one read per display and no writes.
- It drops the lock between attempts, so a brightness key pressed during a
  sync isn't thrown away by `flock -n` — and because the next attempt
  re-asserts whatever is in sysfs *then*, the person at the keyboard wins.

#### Which display the number is about

`local.niri.brightness.device` names the backlight device that speaks for the
rest. The keys still drive every display; this only decides which one gets
quoted by the bar and the OSD.

Nothing picks that consistently on its own. waybar, given no device, takes the
one with the highest `max_brightness` and breaks ties in udev enumeration
order; the helper took whichever came first out of `brightnessctl --list`,
which is readdir order and so is whatever the kernel's directory hashing gave
that boot. On a laptop both rules find the same single panel. On the desk they
are two rules over two `ddcci*` devices and no reason to agree — with each
other, or with the monitor you happen to be looking at.

Setting it is one line, and it feeds both:

```nix
local.niri.brightness.device = "ddcci5";
```

Find the name by asking each device which monitor it is. `idModel` and
`idSerial` come from the `ddcci` device the backlight sits on:

```bash
for d in /sys/class/backlight/*; do
  printf '%s\t%s\t%s\n' "${d##*/}" \
    "$(cat "$d/device/idModel" 2>/dev/null)" \
    "$(cat "$d/device/idSerial" 2>/dev/null)"
done
```

A `ddcci*` name is its i2c adapter number, so it follows the *bus* rather than
the monitor — moving a cable to another port can renumber it. Left `null`,
both sides keep their old guess and a name matching nothing falls back there
too, with a warning on stderr from the helper.

They can still each be right about a *different* number if the monitors have
genuinely drifted — one refused a write, one was adjusted from its own buttons
— but it is at least always the same screen being reported.

#### Why the bar polls slowly

`interval` on the backlight module is 30, against waybar's default of 2.

The module's udev thread runs an `epoll_wait` with that as its timeout, and
re-reads every tracked device's `actual_brightness` whenever it expires. On a
`ddcci` device that attribute is a DDC/CI read. At the default, **both
monitors are interrogated over i2c every two seconds forever** — including all
through the ten minutes the screen is blanked.

Thirty costs nothing that matters. The poll is only the safety net for changes
that emit no uevent, which means someone pressing the buttons on the monitor
itself; everything that goes through sysfs emits one, and a uevent wakes the
`epoll` immediately. The keys, the scroll and the idle dim are all as
instantaneous as they were.

### The login screen

**SDDM uses its own built-in greeter**, not a theme of ours. That is
`local.sddm.theme = "stock"`, and it is the default after the themed one left
the primary display black.

The evidence for blaming the theme is that the failure did not move. It was
identical under kwin_wayland, under weston and under X11, and SDDM logged no
error at any point in the process:

```
sddm[1734]: Greeter starting...
sddm-helper[1766]: [PAM] Starting... / Authenticating... / returning.
sddm[1734]: Greeter session started successfully
sddm[1734]: Message received from greeter: Connect
```

The greeter started, authenticated and connected. Three different display
servers failing the same way, with the stack reporting success, points away
from all three and at the one component they share.

Things ruled out along the way, so they are not tried again:

- **A generated `kwinoutputconfig.json`** from `local.niri.outputs`. Removed.
  Writing a mode can black-screen a display outright, because kwin hands it
  straight to a modeset and a rate that doesn't match exactly — DRM reporting
  179998 mHz where the config says 180000 — simply fails. Dropping the mode
  didn't help either: with no config, kwin still picks the preferred mode,
  which for a 1440p180 panel is 180Hz.
- **Copying KWin's own file** from the Plasma session. That dragged a whole
  arrangement across including its enabled/disabled state.
- **The greeter's compositor.** weston made no difference, and neither did
  X11.

The stock greeter confirmed the diagnosis: it comes up fine on both displays,
so the theme was indeed the thing at fault.

**`local.sddm.theme = "astronaut"`** brings the themed greeter back — one
`sddm-astronaut` build, following the desktop's palette and wallpaper — with
the leading suspect now fixed.

**Where the greeter's colours actually come from**, because getting this wrong
is what kept the login screen off the desktop's palette for the whole of the
noctalia migration. SDDM reads a theme's config in two halves:
`ThemeConfig::setTo` opens the file named by `ConfigFile=` in
`metadata.desktop`, then opens *that same path with `.user` appended* and lets
every non-empty value there win. nixpkgs' `sddm-astronaut` is built on that —
its `themeConfig` argument is written to `Themes/<embeddedTheme>.conf.user`.

The runtime override was being written to `theme.conf` in the theme's root
directory instead. Nothing reads that file; `metadata.desktop` points at
`Themes/black_hole.conf`. So the symlink to `/var/lib` was inert and the
greeter went on rendering the store `.conf.user` that nixpkgs had written from
the build-time palette. Every other part of the path worked — the sync ran,
the manifest was read, the colours were substituted — and delivered to a file
SDDM never opened.

Now `Themes/black_hole.conf.user` *is* the symlink, to
`/var/lib/sddm-theme/theme.conf`, and `sddm-theme-sync` writes that file: it
copies a build-time seed carrying everything that isn't a colour (background
path, form position, clock formats, font) and substitutes the palette from
`noctalia-resolved`. A dangling symlink is a valid state — QSettings on a path
that doesn't resolve simply contributes nothing, and the greeter falls back to
upstream's own colours rather than failing to start.

That suspect is the background. The theme config points `Background` at a
fixed runtime path, `/var/lib/sddm-theme/wallpaper.png`, and that file only
appears once the wallpaper switcher has run. Before a wallpaper has ever been
picked, it isn't there. sddm-astronaut then feeds a missing image into a blur
shader — `PartialBlur` is on — and a QML scene graph that fails while building
an effect chain renders *nothing*, rather than falling back to
`BackgroundColor`. That matches every symptom: no error from SDDM, which had
already logged the greeter as started and connected, and identical behaviour
on every display server, because none of them were involved.

The fix is that the sync service now guarantees the file exists, seeding a
solid image in the seed palette's background colour when there's no wallpaper
to convert. A few KB.

This is unproven — the greeter's own QML warnings were never captured — but it
was the only path in the theme referencing a file that might not exist. If the
themed greeter is still black, go back to `"stock"`.

One thing that happens under **both** greeters: the sync service deletes
`/etc/sddm.conf.d/99-niri-active-theme.conf`. That drop-in used to carry
`[Theme] Current=niri-<palette>`, selecting between the per-palette theme
packages. There is one package now and `services.displayManager.sddm.theme`
names it declaratively, so the drop-in has nothing left to say — but it lives
in `/etc`, where NixOS only removes what it declares, and left behind on an
already-deployed machine it would point SDDM at a theme directory that is no
longer in the store. That is a black login screen rather than a stale one, so
the deletion is unconditional and permanent. The service is ordered before
`display-manager.service` so it lands before the greeter reads its config,
rather than one boot late.

**The greeter's cursor** comes from `settings.Theme.CursorTheme`. SDDM ships
no cursor of its own — it exports `XCURSOR_THEME`/`XCURSOR_SIZE` into the
greeter, which looks the name up on the *system* icon path. Without them the
greeter inherits whatever the compositor defaults to, which on a bare login
screen is often nothing, and the pointer is invisible.

It's set to `Bibata-Modern-Ice` at size 24, matching `home.pointerCursor` in
`home/joshr/home.nix` so the pointer doesn't change shape at login. The two
have to be stated separately: the greeter runs as the `sddm` user before
anyone has logged in and cannot see home-manager's config. `bibata-cursors` is
in `environment.systemPackages` (`modules/nixos/base.nix`), which is what puts
it on the system icon path — a cursor theme only in the user profile would not
be found.

If the login screen is ever black again, a TTY still works (`Ctrl+Alt+F2`), as
does booting the previous generation.


### Screenshots

**Under noctalia the shell captures.** `Print` runs `noctalia msg
screenshot-region` and `Ctrl+Print` runs `noctalia msg screenshot-fullscreen`;
noctalia freezes the screen, dims it, takes the selection, and pulls the pixels
through `wlr-screencopy` itself. `Alt+Print` is still niri's own
`screenshot-window` action, because noctalia captures outputs and regions and
has no per-window capture, and the compositor is the only thing that knows
where a window's edges are.

What a capture *becomes* has not changed: noctalia is told to neither save nor
copy, and to pipe each PNG into `screenshot-annotate`
(`home/joshr/niri/scripts.nix`), which is the tail of the old script — satty
for annotation (arrows, boxes, blur, text), `--early-exit`, `wl-copy` on save,
and a notification carrying the shot as its icon. Saving in noctalia *as well*
would write the unannotated frame and then have satty write over it, or beside
it when the editor is cancelled; copying there would put the unannotated image
on the clipboard for as long as the editor stayed open. Note that
`pipe_command` does nothing on its own — noctalia gates it behind
`pipe_to_command`, so the two are set together.

**One notification per saved capture**, and it takes saying so in two places
because both halves of the pipeline want to announce a save. satty posts its
own — *"File saved to '<path>'."*, with a thumbnail — so it is run with
`--disable-notifications` and the `notify-send` in `screenshot-annotate` is the
one that survives: app-named `screenshot` rather than `Satty`, carrying the
shot itself as the icon, and identical to what the spectacle path sends, so the
two editors don't announce the same thing differently. Noctalia is not the
other half of that pair — its screenshot service notifies only for the
deliveries it performs itself, and it is told to neither save nor copy, so a
capture that is only piped passes through it silently. Turning `save_to_file`
back on would bring a second notification with it, on top of the second file.

`local.niri.screenshotEditor` picks the editor: `"satty"` by default, or
`"spectacle"` on a host that already runs Plasma and knows KDE's. Spectacle is
a different shape — it can't read stdin and can't be told to exit — so that
path writes the capture to its destination first, copies it, notifies, and then
opens spectacle on the file, meaning the unannotated shot is saved either way
and spectacle's own Save is what overwrites it. It also pulls a good deal of
the Plasma runtime into the session's closure, which is why it isn't the
default.

**The freeze is what Spectacle and Flameshot do**, and it is there because
selecting and capturing are two different moments. Everything a region is
usually drawn around has moved on by the time the capture runs a second or two
later: the video is three frames further in, the animation has finished, the
menu closed when it lost focus. Set `local.niri.screenshotFreeze = false` to go
back to selecting over the live screen. Under noctalia this is one setting
(`shell.screenshot.freeze_screen`) and the still frame *is* the selection
overlay, which is the part that got simpler in the move — see the waybar
section below for what it replaced.

**Selections are confirmed with Enter**, not captured on mouse-up
(`confirm_region`). It costs a keypress per shot and buys the nudge: the box
stays live after the drag, so an edge that landed a few pixels off is dragged
back into place rather than being a shot to throw away and redo.

**`Shift+Print` (or `Mod+Ctrl+S`) re-shoots the last region.** It runs the same
`screenshot-region` command as `Print`, and that is the point rather than an
oversight: `remember_last_region` makes the overlay open with the previous
region already selected and waiting on its Enter. So `Shift+Print` is the key
and Enter, `Print` is the key and a drag, and the remembered box can be nudged
before it is taken instead of only accepted whole. It's for shooting the same
frame repeatedly — a panel, a window, a chart being tweaked — where redrawing
the box by hand is both the tedious part and the reason successive shots don't
line up. The separate bind stays because the finger knows it.

#### The waybar session's screenshot

Setting `local.niri.shell = "waybar"` leaves screen capture where it was:
`wayfreeze` → `slurp` → `grim` → `satty`, in the `screenshot` script in
`scripts.nix`, with `screenshot last` as a second mode. That script is off a
noctalia system's PATH entirely, which is what keeps wayfreeze, slurp and grim
out of its closure.

It is worth reading once for what noctalia now absorbs. `wayfreeze` screencopies
every output and paints the copies back as overlay layer surfaces, `slurp`
selects on top of that, and `grim` captures the still. `--hide-cursor` keeps the
pointer out of the still frame, which otherwise gets the frozen cursor painted
in and the live one drawn over the top, so a capture across that spot shows two.
`--enable-keyboard` reads backwards and isn't: it means *let the keyboard
through to other surfaces*, and without it `wayfreeze` claims exclusive keyboard
focus for itself. niri hands exclusive focus to the lowest layer surface that
asks for it — the freeze, which mapped first, not `slurp` — so `Escape` would
dismiss the freeze and leave you selecting over a live screen instead of
cancelling the screenshot.

The order the two map in is the load-bearing part: niri stacks layer surfaces
in the order they map and gives the click to the top one, so `slurp` has to
come second or the drag lands on the freeze. `wayfreeze --after-freeze-cmd`
runs only once every output's surface is configured, so the script waits on
that signal (bounded to a second and a half, and abandoned early if `wayfreeze`
dies) rather than guessing with a `sleep`. A freeze that never arrives costs a
selection over the live screen and nothing else.

`screenshot last` re-shoots without a selection at all. Every region capture
writes its geometry to `~/.local/state/niri-screenshot/region` and that mode
reads it straight back, falling back to a normal selection if there's no
remembered region yet or if the region no longer captures — a monitor
unplugged, or the layout rearranged under it. The geometry is only remembered
once `grim` has accepted it, so a region that can't be captured never becomes
the one it comes back to. Nothing freezes in that mode, there being no
selection to draw over.

It has to be a separate keybind there rather than "reopen slurp with last
time's box ready to adjust", because slurp can't pre-fill a selection: its `-r`
reads boxes on stdin and *restricts* selection to them, so handing it the saved
region would let you click that box to accept it but never drag its edges — a
worse version of the same thing, with an extra click. That limitation is
exactly the one noctalia's overlay doesn't have, which is why the two keys
collapse into one command above.

satty is run with `--disable-notifications` here too, for the same reason and
with the same result: the script's own `notify-send` is the single notification
a saved capture produces, under either shell.

### Lock screen

Hyprlock, with a clock, a greeting, one wide password field and — when
something is playing — the album cover, blurred across the whole screen and
again as a small card above the track name, with previous, play/pause and next
in a row beneath it. Nothing playing puts the current wallpaper back. On a
machine with a battery, the charge sits in the bottom-right corner; on one
without, nothing is drawn there at all. Colours come from the active theme, so
it follows a theme switch. `swaylock-effects` is still installed and is the
fallback the lock script drops to if Hyprlock fails to start — a locker
regression must not leave the session sitting unlocked.

`swayidle` dims at 4 minutes, locks at 5, blanks at 10, and locks before
suspend.

#### The dim is undone before the screen goes dark

The 10-minute blank puts the brightness back *first*, and then powers the
monitors off. That reads like a wasted write — nobody is going to see it — and
it is the fix for the desk coming back at the wrong brightness.

Left to the dim's own resume command, the write that undoes the dim goes out
at the moment input returns. That is the same moment niri is turning the
outputs back on, so it lands on a monitor still re-establishing its link and
in no state to answer, and the driver doesn't notice it was ignored (see
[Brightness](#brightness)). Sysfs then said 100%, the panel sat at 20%, and
the keys stepped from 100 and appeared dead. Restoring five minutes earlier
means the monitor takes the write while it is still awake and nothing is owed
across the DPMS off.

The resume command is `brightness sync` instead, which checks rather than
assumes — a monitor that came back on its own stored level is put right, and
if everything already agrees it reads each display once and stops. Coming back
from suspend runs the same thing, for the same reason and one step harder: the
displays lost power, not just signal.

Both are detached through `systemd-run --user` rather than run inline, because
swayidle runs with `-w` and waits for each command. `sync` deliberately keeps
trying for a few seconds while a monitor wakes up, and blocking swayidle's
event loop for that long is the exact mistake [`lock-now`](#everything-locks-through-lock-now)
exists to avoid.

#### The background is the album cover

One cover becomes two pictures. `lock-album-art-fetch` renders a 2560x1440
backdrop — the sleeve blown up to fill the screen and blurred to a wash of its
own colours, which is what the lock screen uses in place of the wallpaper —
and a 200px card with soft corners, a hairline edge and a shadow, which sits
above the track name. Both are keyed by the cover's URL and cached under
`~/.cache/niri/album-art`, thirty of each, so locking twice during the same
song does no work at all.

Hyprlock asks for both every three seconds through `reload_cmd`, which is what
makes the lock screen follow the music while it sits there locked: skip a
track and the card changes and the background crossfades behind it; stop the
music and it fades back to the wallpaper.

**`lock-album-art` — the command Hyprlock actually runs — never fetches and
never renders.** That is the constraint the whole design is built around.
Hyprlock runs a `reload_cmd` through `spawnSync` from a timer callback on its
main thread, so a cover downloaded inline would freeze the clock and the
password field for as long as curl felt like taking. `lock-album-art` answers
out of the cache, and when a track has no render yet it hands the URL to
`lock-album-art-fetch` in a detached process and answers with what is true
right now instead. The cost is that the first lock during a never-seen track
comes up on the wallpaper and crossfades into the cover a beat later, which is
the right way round for that trade.

Two of the details are downstream of one Hyprlock behaviour: an empty answer
from a `reload_cmd` means *keep what you have*, not *show nothing*. That is
what you want while a cover is still rendering — the previous one stays up
rather than blinking through a gap — and it means "the music stopped" has to
be said with a picture. So there is a transparent PNG in the store for the
card to point at, and the corners, edge and shadow are baked into the rendered
image rather than left to Hyprlock's `rounding` and `border_size`, because a
Hyprlock border would draw a neat empty box around the transparent one.

The backdrop is also exposed rather than simply copied. Hyprlock's own
`brightness` is a fixed multiplier set for the wallpapers, which are chosen
and mostly dark; album covers are neither, and a sleeve that is mostly white
leaves every label on the screen sitting on a pale wash. So each cover is
dimmed *to* a target lightness instead of by a constant — never brightened,
and never dimmed by more than two thirds, which is the point past which a
cover stops being visible at all rather than merely dim.

The cover is fetched with the same care as anything else that comes off the
network. Only `http`, `https` and `file` URLs are followed, `--proto-redir`
keeps a redirect from walking into `file://` and handing a local file of its
choosing to ImageMagick, the download is bounded on size and time, and what
arrives has to *be* an image by its magic bytes — the MPRIS metadata was a
claim, not a check. A per-track `flock` keeps two renders of the same cover
from racing, and both files are renamed into place only once they are whole,
so a reload can never catch a half-written JPEG.

Which player all of this is about is decided once, in a shell fragment shared
with the now-playing label: a player that is actually playing, or else the
first paused one. Sharing it is not tidiness — the cover and the title are
resolved separately, and two copies of that loop would eventually put one
track's sleeve under another track's name. Every `playerctl` call in it is
wrapped in `timeout 1`, because these are D-Bus calls into other applications
and a wedged one (a hung browser tab, usually) blocks its caller for D-Bus's
own 25-second default. Two of the three callers cannot afford that: one runs
on Hyprlock's main thread, and one runs on the path that has to have the
screen locked before the machine suspends.

#### And the colours come off the cover too

The password field's outline, the clock, the greeting, the track name and the
session controls all take their colour from the sleeve, so the whole screen
belongs to the record rather than to the picture alone — and they follow it
from track to track, which is its own piece of work; see below.

The cover decides exactly one thing: a hue. Everything else is fixed in
`home/joshr/niri/album-palette.awk`, which reads the same twelve-colour
histogram the exposure comes from, takes the hue of the colour the sleeve is
*mostly* made of — skipping greys, and skipping anything so dark or so light
that the eye reads it as black or white regardless of what its saturation
claims — and rebuilds the theme's five lock-screen colours at that hue with
fixed lightnesses and a bounded amount of the cover's own saturation. A neon
sleeve and a washed-out one land in the same place, which is the point: this
is a screen that has to stay readable over a picture nobody chose.

`LOCK_ERR` and `LOCK_WARN` keep the theme's values. An error is red and a
caps-lock warning is yellow whatever is playing.

A cover with no colour confident enough to build on — a black-and-white
photograph, a plain white sleeve — produces no palette at all, and the lock
screen keeps the theme's own colours. Only the exposure comes out of that
pass, which every cover needs.

The palette file is read rather than sourced, one known key at a time and only
when the value is six hex digits. It is our own file and holds nothing else,
but it lives in a cache directory rather than in the store, and `lock-session`
is the script standing between a locked session and the desktop.

#### …and they change with the track, which took some doing

Skip a track on a locked screen and the colours go with it, a tick behind the
background. That is not something Hyprlock supports: `reload_cmd` re-reads a
**path**, and there is no equivalent for a colour anywhere in its config, so
neither the labels nor the password field can be told to become a different
colour once they have been parsed. Both of them get there by another road.

**The labels smuggle the colour in through their own text.** Hyprlock renders
label text through `pango_parse_markup` (hyprgraphics, `TextResource.cpp`), so
a `<span foreground=...>` in what a label *prints* does what a `color =` in
its config cannot. Every label is therefore a `cmd[update:N]` calling
`lock-label`, which wraps the text in the colour of the moment. Three details
make that work:

- Hyprlock re-runs a `cmd[]` label on every tick whether or not its command
  line changed — `alwaysUpdate` is set for all of them (`IWidget.cpp`) — so a
  label with fixed text still picks up a new colour.
- `$TIME12` is substituted *into the command line* before the `cmd[` prefix is
  stripped, so the clock is still Hyprlock's own clock; `lock-label` only
  paints it.
- Label commands run on the resource gatherer's thread, not the main one, so
  a clock ticking once a second per monitor costs the renderer nothing. This
  is the opposite of `reload_cmd`, which is `spawnSync` on the main thread —
  the reason `lock-album-art` is forbidden from doing any work.

If the markup is ever malformed, pango falls back to rendering it as plain
text, and the label's own `color =` draws it in the theme's colour. The
failure mode is the lock screen as it looked before any of this.

**The password field is a picture of a password field.** Its frame is an
`image` widget — the one thing that *can* be swapped by path — drawn under a
field whose own outline and fill are transparent. `lockFieldFrame` in
`theming.nix` renders it, at 624x62 with corner radii of 20 and 18, because
that is exactly the box Hyprlock draws its own outline in: the field is 620x58
and `PasswordInputField.cpp` puts the border *outside* that, with
`roundingForBorderBox` adding the thickness to the radius. The same function
draws the frame for a theme at build time and for an album at lock time, so
the two cannot drift.

The field keeps its `outline_thickness`, and its `check_color`, `fail_color`
and `capslock_color`. Those are the colours Hyprlock animates the outline
*to*, and they are why this is a transparent outline rather than no outline at
all: a wrong password still flashes the frame red, over the album's one.

What is left static is the `font_color` — the dots, the typed text and the
placeholder — which no image can stand in for and no markup can reach. It is
set from the palette at lock time and stays there for that lock.

One writer, many readers. `lock-album-art` already runs on Hyprlock's timer
and already knows what is playing, so it writes the current colours to
`$XDG_RUNTIME_DIR/hyprlock-colors` on every tick, and the labels read that
file instead of asking MPRIS. A clock, a greeting, a track name, three
transport buttons and two session controls, times three monitors, would
otherwise be a D-Bus round trip each, several times a second — and any two of
them could disagree in the middle of a track change. A file is a few
microseconds and one answer.

#### Three buttons under the track name

Previous, play/pause and next, in a row between the track name and the
password field, and only while there is something for them to control. The
keyboard's media keys already work on a locked screen — that is what
`allow-when-locked` on the `XF86Audio` binds in `niri.nix` is for — but a
keyboard without them left a locked screen with no way to pause the music
short of unlocking it.

They are three labels rather than one row of controls, because a Hyprlock
label carries a single `onclick` and the area that catches it is the label's
own text. That second half does more work than it looks like doing:
`lock-media-button` prints nothing when there is no media session, and a label
with no text draws nothing and has no box for a click to land in, so the row
is not there at all on a lock screen with no music — the same mechanism the
track name above it already runs on. The cover and the name sit 36px higher
than they otherwise would to leave room for the row, which costs nothing when
nothing is playing, because that space is empty then anyway.

The play/pause glyph says what a click will do — a pause bar while the player
is playing, a play triangle while it isn't. That is the opposite of the marker
in the track name beside it, where a pause glyph means the player *is* paused;
both are conventional and neither reads as the other in the place it sits.

A click goes to a **named** player. `lock-media-control` takes the same MPRIS
snapshot as everything else on the screen and hands the player it names to
`playerctl --player`, because left to playerctl's own "first available"
default, a button sitting under Spotify's sleeve could skip a paused browser
tab's queue instead. The name goes in as a two-entry priority list — the exact
instance, `firefox.instance123`, and then the bare application name — since
`--player` acts on the first entry that matches: preferring the instance costs
nothing and cannot fire the action twice the way a fallback chain of two calls
could.

The buttons tick at the same 1500 ms as the track name, which is the shortest
interval the shared MPRIS cache is built to serve, and which keeps the
play/pause glyph and the pause marker beside it turning over together rather
than a beat apart. The click itself is immediate — only the glyph waits for a
tick, and the click drops the cached snapshot on its way out, so that tick
asks MPRIS rather than serving what was true before the click.

#### The battery, on the machines that have one

The charge sits in the bottom-right corner, on the same 18px baseline as the
session controls so the bottom of the screen still reads as one row, and as far
from them as the screen allows: it is the only thing on a lock screen that is
purely read, and it has no business sharing an edge with two labels you click.
The glyph, the five-icon ramp and the thresholds are the bar's — warning at
30%, critical at 15%, neither of them while it is charging — because it is the
same battery, and a machine reading 󰁼 25% in the bar and something else once it
locked would be saying two things about one number. Warning and critical wear
the theme's yellow and red rather than the album's, for the same reason
`LOCK_WARN` and `LOCK_ERR` sit out the palette: a battery about to die is red
whatever is playing.

**Nothing is drawn on a machine without a battery, and that is decided per
lock rather than per host.** `lock-session` looks for one while it writes the
config — the first `/sys/class/power_supply` entry whose `type` is Battery,
whose `scope` isn't Device, and whose bay isn't empty — and appends the widget
only if it finds one. So `local.niri.lockBatteryIndicator` can default to true
and be left alone: the desk draws nothing because there is nothing to draw, the
laptop draws its charge, and the USB stick draws whichever is true of the
machine it was plugged into that morning. Setting it to `false` is for a laptop
whose corner you would rather have empty.

The `scope` test is the one worth spelling out. `/sys/class/power_supply` is
every power source the kernel knows about, and most of them are not the
answer: the mains adapter is in there with a `type` of Mains, and so is
anything with a battery the machine merely *talks* to — a wireless mouse, a
controller, a headset — which the kernel marks with a `scope` of Device.
Without that test a desk with a Logitech mouse would grow a battery indicator
on its lock screen showing the mouse's charge, in the place the laptop's own
would be, on a screen with nothing to click to find out which it meant.

A two-pack laptop would show the first pack rather than the sum. Adding them
honestly needs `energy_full` from each — the capacities are percentages of
different sizes, so averaging them is wrong — and the drivers that report
`charge_*` in µAh instead cannot be added at all across packs at different
voltages. Nothing here has a second battery; that is the work it would take if
something ever did.

The widget ticks at the same 3000 ms as the greeting and the session controls.
A charge level is slow enough that anything faster would be for nothing, but
its *colour* is not — the labels pick the album's palette up on their own next
tick, and a battery three seconds behind the rest of the screen is one nobody
notices catching up. It costs a handful of sysfs reads through bash's own
`read` and no processes at all, on the resource gatherer's thread rather than
the renderer's, which is the same bargain every other label on the screen
makes; see below.

#### What all of that costs while the screen is locked

Nothing at all while it isn't: every script here runs only under Hyprlock.

While it is, the number that matters is how much of it lands on Hyprlock's
**render thread**, because a `reload_cmd` runs through `spawnSync` from a timer
callback on it — a millisecond spent in one is a millisecond the lock screen
is not drawing. Label commands are the opposite: they go through the resource
gatherer's own thread, so a clock ticking once a second per monitor is free as
far as the renderer is concerned.

The multiplier is the monitor count. A widget with no `monitor` is built once
per output (`getOrCreateWidgetsFor`), so the desk runs three backgrounds,
three cover cards, three field frames, three track labels and nine transport
buttons, each with its own timer, all asking the same question within a few
hundred milliseconds of each other.

Two things keep that cheap:

- **One MPRIS round trip, shared.** `playerctl --all-players metadata` with a
  format string returns every player's name, status and metadata in a single
  call — playerctl's format context carries `playerName` and `status` next to
  the metadata fields — where this used to take four to six calls per script.
  The answer then goes in `$XDG_RUNTIME_DIR/hyprlock-track` with a timestamp,
  and whoever finds it older than a second fetches a new one. The window is
  deliberately shorter than every interval that asks, so a tick never serves
  the previous tick's answer; it only ever covers the burst.
- **No processes in the steady state.** The paths a cover is filed under are
  built by assignment rather than by a function that prints, and the track
  label's sanitising is bash string work rather than a `tr | sed | cut`
  pipeline. On a cache hit the whole of `lock-album-art` forks nothing.

Simulated at three monitors over twelve seconds of locked screen, that took
`playerctl` from **312 spawns to 5**, and a single `lock-album-art` call —
the one the renderer waits on — from about **31 ms to 7.5 ms**. Both figures
are against a stubbed `playerctl`, which is far cheaper than the real one, so
the difference on the machine is larger than that.

The remaining cost is a rendering job per *new* track: a download and three
ImageMagick runs, about a third of a second of CPU, in a detached process that
nothing waits for.

#### Everything locks through `lock-now`

`lock-session` is the script that actually draws the lock screen, and it
blocks until you unlock. Nothing calls it directly. The keybinds, the bar's
lock button, the session menu, switch-user and swayidle all go through
`lock-now`, which starts it, waits until it is up, and returns — a few hundred
milliseconds rather than however long you are away.

That indirection is not tidiness — it is the fix for the idle timer stopping
dead at the moment it locked. home-manager runs swayidle with `-w`
(`services.swayidle.extraArgs` defaults to it), and with `-w` swayidle's
`cmd_exec` forks the command **once** and then `waitpid()`s it from inside its
own Wayland event loop, instead of double-forking and returning. A timeout
pointed straight at `lock-session` therefore froze every later timer for as
long as the screen was locked: the 10-minute blank never fired, so the display
stayed lit behind the lock screen indefinitely. `before-sleep` and the `lock`
event — the lid closing on mains, `loginctl lock-session` — wedged the timer
the same way.

Dropping `-w` would have been the wrong fix. It is what makes swayidle hold
logind's sleep delay lock until `before-sleep` has returned, which is the
guarantee that the machine never suspends before the locker is on screen. So
the command has to return quickly *and* not until the lock is really up, which
is what `lock-now` does.

`lock-now` is also idempotent, which is why every route can share it.
`lock-session` holds an `flock` on a file under `$XDG_RUNTIME_DIR` for as long
as it lives — an open descriptor rather than a PID file, so the kernel drops
it however the process dies and there is no stale state to clean up — and a
second lock request sees the lock held and returns success instead of starting
a second locker on top of the first. That matters beyond tidiness, because
`lock-session` falls back to swaylock when Hyprlock exits non-zero: without the
guard, a duplicate lock request started a second Hyprlock, which cannot take an
already-held session lock and exits non-zero, and the fallback then layered a
swaylock over the perfectly good lock screen already on screen.

The one thing `lock-now` cannot do is wait for a *rendered* lock screen. The
file lock proves `lock-session` is running, which is a fraction of a second
ahead of Hyprlock claiming the session lock and drawing, and there is no
readiness signal to wait on instead — Hyprlock has no IPC, and a Wayland
session lock is not visible to logind. So it ends on a 300 ms settle, which is
an honest guess, generous for what it covers, and only matters to the two
callers that touch the screen immediately afterwards: `lock-blank` powering the
monitors off and `switch-user` handing the seat to the greeter.

#### Only the idle lock has a grace period

A grace period is a window, counted from the moment the lock screen appears,
during which any input dismisses it with no password. Hyprlock and swaylock
both take one as `--grace`, and `lock-session` passes its own `--grace` through
to whichever it ends up running.

`lock-session` defaults to `--grace 0`, so every route to the lock demands a
password immediately: `Mod+L`, `Mod+Shift+L`, the bar's lock button, the
session menu, `switch-user`, `before-sleep`, and the `lock` event that
`loginctl lock-session` triggers. All of those are locks somebody asked for,
and on those a grace window is a hole rather than a convenience — waking the
screen to confirm that it actually locked is itself input, so the check that
you locked would unlock it.

The 5-minute idle timeout in `lock.nix` is the single exception, and it passes
`--grace 2`. Nobody asked for that lock; it fired on its own while you were
away, and the case worth covering is the timer going off just as you sit back
down. Two seconds covers that and nothing longer. It is also the one lock
where the grace window costs nothing you had: the machine was already sitting
unlocked and unattended for the five minutes leading up to it.

Note that `before-sleep` deliberately sits on the strict side of that line even
though a suspend can itself be idle-triggered. Resuming from suspend is exactly
the moment a free keypress would get spent, and the lid closing is usually a
deliberate act.

The lock script passes `--color` as well as `--screenshots`, and that is
load-bearing rather than decorative. `--color` is the flat colour swaylock
paints underneath the screenshot, so it is what you see when there is no
screenshot to draw over it — and its default is **white**. Locking with a
monitor already blanked is exactly that case: `--screenshots` grabs each
output through wlr-screencopy, and a capture of a powered-off output fails.
The packaged fork then clears the screenshot flag on its shared state instead
of on the surface that failed, so one blanked monitor drops the screenshot
background on *every* display and the whole lock screen comes up white.
Pointing `--color` at the theme background makes that fallback a themed solid
colour. It is easy to hit because blanking and locking are independent —
`Mod+Escape` blanks on demand, `Mod+Shift+L` does both at once, and swayidle
blanks at 600s and locks before sleep.

niri's `layout { background-color }` does not help here: that is the backdrop
behind windows, and swaylock's own surface covers it.

**swaylock is patched** (`home/joshr/niri/swaylock-date-fit.patch`) so the date
stacks onto two lines — weekday over month and day — and can't overhang the
ring.

Upstream draws the date as one row sized at a hardcoded `arc_radius / 6`, so it
grows in exact proportion to the circle: a long date like "Wednesday, September
24" hangs over by the same fraction at *every* radius, and widening
`--indicator-radius` buys nothing. No flag reaches it either — `--font-size`
sets the clock above it, and the date's divisor isn't exposed. Without the patch
the only fixes available in configuration are to shorten the date or narrow the
font, and the installed fonts are FiraCode and Poppins with nothing condensed.

The patch splits `--datestr` on a newline (strftime `%n`, hence
`--datestr "%A%n%B %d"`) and stacks the halves. Two short lines fit at full size
where one long one didn't: at radius 130 "Wednesday" and "September 24" measure
117px and 156px against chords of 246px and 231px, where the single row was
299px against 240px. It also scales a line down if it still wouldn't fit,
bounded by the ring's inner chord at that line's own baseline rather than the
diameter — with stacking that never triggers here, it's the backstop that makes
an overhang impossible for any format or locale.

It costs a source build of swaylock-effects, which is a small C project and
quick. If a nixpkgs bump moves those lines the patch will fail to apply — the
fallback is a one-line `--datestr` short enough to fit.

**`Mod+Escape` blanks the monitors on demand**, from the lock screen as well
as from the desktop — for when you're walking away now and don't want to wait
out the idle timer. Any input wakes them; on the lock screen that leaves
swaylock exactly where it was, so it's a screen-off, not an unlock.

It works through the lock without an `allow-when-locked` on it because niri
keeps a whitelist of actions that survive the lock screen —
`power-off-monitors` is on it, which is the same reason the 10-minute blank
above fires while locked. That check lives in `do_action`, so it covers
`niri msg action power-off-monitors` over IPC as well as the keybind, which is
how swayidle's blank reaches it. Setting that property here would actually be
a config *error*: niri only accepts it on `spawn` binds.

**`Mod+Shift+L` locks and blanks together**, which is the "I'm walking away"
version of pressing `Mod+L` and then `Mod+Escape`. Like `Mod+L`, it locks with
no grace period at all — see [Only the idle lock has a grace
period](#only-the-idle-lock-has-a-grace-period).

It's `Mod+Escape` and not bare `Escape` because niri intercepts a bound key
unconditionally — it matches binds before it looks at the lock state, and
only then drops the action if the session is locked. A bare `Escape` bind
would therefore swallow Escape in every application all the time, and there
is no "only while locked" flag to scope it with.

The system module adds `security.pam.services.swaylock` — without that PAM
entry swaylock accepts your password and then rejects it, which locks you out
of your own session.

#### Idle actions stop at the session boundary

More than one person can be logged in at once. `switch-user` hands the seat to
the greeter and deliberately leaves the session it came from running, so every
account that has logged in since boot still has a niri, a swayidle and a full
set of idle timers of its own, ticking.

niri does not stop that clock for a session that has been switched away from.
Pausing a session suspends its libinput and DRM devices and nothing else, so
the compositor simply stops seeing input, concludes after four minutes that you
are idle, and runs the timers in `lock.nix` in a session nobody is looking at.
Locking there is correct — nobody is sitting in front of it. Dimming and
blanking are not, because neither one stays inside the session that asked for
it: the dim is a DDC/CI write to the monitor itself
([`modules/nixos/ddcci.nix`](modules/nixos/ddcci.nix)), which is one piece of
hardware shared by the whole seat. The symptom is the screen going dark on
whoever is actually using the machine, four minutes after they sat down, driven
by the timers of somebody who walked away an hour ago.

So the timers that touch the screen run through `when-active`, and the one that
touches only its own session does not:

| timeout | action | gated |
| --- | --- | --- |
| 240s | dim to 20%, restore on activity | yes |
| 300s | lock | **no** — it locks its own session and reaches nothing else |
| 600s | blank the outputs | yes |

`when-active` asks logind whether this session is the one on the screen —
`loginctl show-session auto --property=Active` — and runs the command only if
it is. `auto` is how swayidle itself finds the session it listens to for Lock
and Unlock: logind resolves it as the caller's own session and falls back to
the user's display session, and that fallback is what makes the question
answerable from a `systemd --user` service, where there is no
`XDG_SESSION_ID` and the unit's cgroup sits outside every login session.

A question that can't be answered runs the command anyway. A session on no seat
at all — a VM, a headless box — reports itself active, and a machine with no
logind to ask is one with nobody else to interrupt.

The blank is gated for a second reason on top of that one: a paused niri has
handed its DRM devices back and cannot power an output off while it is in the
background, so all an ungated blank could do is queue the monitors up to come
back dark on the way in.

One consequence worth knowing: while the greeter is on screen with no session
behind it, nothing dims or blanks the monitors, because there is no active
session to do it. That screen belongs to SDDM at that point, not to us.

#### Coming back through the greeter only asks once

`switch-user` locks the session and hands the seat to SDDM. Logging back in as
yourself used to cost two passwords: one at the greeter, and one at the lock
screen still standing in the session you left.

It now costs one. SDDM looks for a session of its own for that user in state
`online` — exactly what `switch-user` leaves behind — and answers a successful
authentication with logind's `UnlockSession` followed by `ActivateSession`,
instead of starting a second session beside the first. That is
`Users.ReuseSession`, set explicitly in
[`modules/nixos/niri.nix`](modules/nixos/niri.nix): it is SDDM's own default,
but this configuration now depends on the behaviour rather than inheriting it.
swayidle turns the `Unlock` half into `unlock-session`, which sends hyprlock
`SIGUSR1`.

Three things make that a shortcut rather than a hole in the lock:

- logind accepts `Unlock` only from the session's own user or from root — the
  polkit check names the session owner as the user who may skip it. So the
  senders are code already running as you, and SDDM's daemon, which sends it
  having just put you through PAM.
- `SIGUSR1` is hyprlock's own unlock path (`enqueueUnlock`), the same one a
  correct password takes, so the Wayland session lock is released properly.
  Killing the locker would not unlock anything: under `ext-session-lock`, a
  locker that dies without releasing the lock leaves the compositor locked with
  nothing left to type into. That is the protocol working as designed.
- Nothing else here sends `Unlock`. `loginctl unlock-session` by hand does the
  same thing, which is rather the point of hanging this off logind's signal
  instead of inventing a private one.

The swaylock fallback has no unlock signal, so a session that came up on it —
which only happens when hyprlock failed to start — still asks for the password
at the lock screen. That is the right direction for a fallback to fail in.

The listener is swayidle, so it is also gone while the idle inhibitor is on:
that stops swayidle outright (see [Staying awake](#staying-awake)), and
switching away and back with `Mod+Shift+I` held on asks for the password again.
Old behaviour rather than a new failure, and not worth a second long-running
D-Bus listener to close.

Without `ReuseSession` the second login would start a *new* session instead:
two niris, two swayidles and two of everything the session launches, for one
person, with the first one still locked behind them.

### RGB lighting

`modules/nixos/openrgb.nix`, imported by `gaming.nix`, so it lands on the two
`gamestation` hosts and not the laptop. It runs the OpenRGB daemon, the niri
session starts the tray applet at login, and both apply one profile:

```nix
local.openrgb.profile = "Main";   # ~/.config/OpenRGB/Main.orp
```

That name is a filename and is case-sensitive — `Main` and `main` are two
different profiles. Profiles are made from OpenRGB's own UI ("Save Profile")
and are runtime state, not something this repo writes, so naming one that
doesn't exist yet is harmless: the applet says "Profile failed to load" and
carries on, and the resume service checks for the file and does nothing.

The applet is launched with `--startminimized`, which is load-bearing twice
over: OpenRGB drops to CLI mode and *exits* as soon as it's given any option,
so `--profile` on its own would set the lighting and quit with no tray icon.
`--startminimized` implies `--gui` and keeps the window out of the way. (The
resume service is the case that *wants* that CLI behaviour, and gets it by
leaving the flag out.)

Each argument is its own string in the config —
`spawn-at-startup "…/openrgb" "--startminimized" "--profile" "Main"`. This is
the one thing to get right here: `spawn-at-startup` is not a shell, niri execs
the first string and hands it the rest, so the whole command line packed into
one string is a program name with spaces in it. It fails with `ENOENT`,
quietly, into niri's log — which is exactly what it did for a while, and why
the lighting was only ever whatever the last thing to touch it had left.

`local.openrgb.autostart` decides whether the applet starts at all, and
defaults to whether the daemon is enabled: on at the desk, off on the laptop,
where it would cost a tray icon, a Qt process and a failed profile load every
session for nothing to talk to. The laptop has no `openrgb` on PATH either —
the package comes with the daemon's module — so on that host it's
`nix run nixpkgs#openrgb` for a one-off, or importing `gaming.nix` to have it
properly.

#### Two applets at login

Counting two `openrgb` processes is normal. One is the daemon —
`openrgb --server`, running as root since boot — and the other is the tray
applet in your session. The applet does not fight the daemon for the
hardware: given a server already listening on localhost it connects to it as
a client rather than detecting anything itself, which is what
`--noautoconnect` exists to switch off.

Two *tray icons* is the bug, and it is almost always OpenRGB's own "Start At
Login" checkbox (Settings → General). That writes
`~/.config/autostart/OpenRGB.desktop`, and niri's session runs XDG autostart
entries — `niri.service` pulls in `xdg-desktop-autostart.target` — so the
applet starts once from `niri/config.kdl` and once from that entry. OpenRGB
has no singleton lock and will happily run both; the first to finish
detection takes the hardware and the second comes up with an empty device
list, so the giveaway is one tray icon that controls nothing rather than
lighting that flickers.

That box is easy to have ticked, because it is the only way to autostart the
applet in the Plasma session on the same machine and the same `$HOME`, and it
was the only thing that worked in the niri session too for as long as
`spawn-at-startup` was packed into a single string and failing with `ENOENT`.
Repairing the spawn is what turned one applet into two.

`home/joshr/niri/niri.nix` now masks the entry with a `Hidden=true` stub — the
same treatment `niri/default.nix` gives blueman — gated on
`local.openrgb.autostart`, so it only claims the file where the repo is what
starts the applet. Plasma and the laptop are left alone. The side effect is
that OpenRGB's checkbox reads "on" forever, since it only asks whether the
file exists; unticking it deletes the stub and the next home-manager
activation writes it back.

To confirm which of the two you have before changing anything:

```bash
ls -l ~/.config/autostart/OpenRGB.desktop   # the duplicate, if it exists
pgrep -af openrgb                           # daemon + applet is expected
```

The lighting does not survive a suspend on its own; see "Coming back from
suspend" above for the service that puts it back.

### Installing applications: Flatpak and Discover

Flatpak is enabled on both desktops (`modules/nixos/niri.nix`,
`modules/nixos/plasmalogin.nix`) and is the way to install an application that
this configuration does not carry — anything you want to try without editing
`configuration.nix` and rebuilding, and anything that ships as a flatpak and
nothing else. It is not a replacement for the package lists: a program that
belongs on these machines belongs in Nix, where a rebuild puts it back.

**KDE Discover is the front end** on the niri hosts. Plasma already brings its
own copy; niri brings no software centre at all, so `kdePackages.discover` is
in `environment.systemPackages` there. Discover rather than GNOME Software
because it is the one that ends up looking like the rest of the session — it
reads `~/.config/kdeglobals`, which the noctalia templates generate, so it
follows a theme switch exactly the way Dolphin does, where libadwaita has no
equivalent hook. It is also not a fresh runtime on the machine: polkit-kde-agent
is already in the session, and a host on `local.niri.screenshotEditor =
"spectacle"` has most of the rest of it.

**Only its Flatpak half means anything here.** Discover's other backend is
PackageKit, for distribution packages, and on NixOS those are this repository —
not something an application can be handed write access to. So its updates page
speaks for the flatpaks and nothing else, and system updates stay
`sudo nixos-rebuild switch --flake .#<host>`.

**Flathub is registered by a one-shot unit**, `flathub-remote`, because
`services.flatpak` configures no remotes and a store with none is an empty
window that reads as broken. It runs `flatpak remote-add --if-not-exists`, which
returns without fetching anything once the remote exists — so only the first
boot after this landed actually talks to `dl.flathub.org`, and a first boot with
no network simply leaves it for the next one. Nothing is ordered after it. To
check, or to do it by hand:

```bash
flatpak remotes
systemctl status flathub-remote
```

## Wallpapers

`~/.local/share/wallpapers` has two halves. The collection out of the
dotfiles repo is the permanent one. Beside it, `WallhavenFlake/` holds
[wallhaven.cc](https://wallhaven.cc)'s current top 20 — and only those
twenty, so as the toplist moves on, the folder moves with it.

Both desktops pick the new files up for free: niri's `Mod+Ctrl+W` picker globs
the whole tree, and Plasma's slideshow is pointed at the same directory.

### The default

`nixos.png`, out of the dotfiles collection. That is what a session which has
never picked a wallpaper shows, on both desktops and at every stage of
starting one.

It is named in three places, because three different programs read it at three
different times and none of them can see the others' configuration:

| Where | What it dresses | Form |
|---|---|---|
| `home/joshr/plasma.nix` (`defaultWallpaper`) | the Plasma desktop and its lock screen | store path |
| `modules/nixos/plasmalogin.nix` | the Plasma login greeter | store path |
| `home/joshr/niri/scripts.nix` (`defaultWallpaper`) | what `wallpaper-restore` falls back to under niri | `~/.local/share/wallpapers/nixos.png` |

Changing the default means changing all three. That is deliberate rather than
an oversight waiting to be tidied into one option: the greeter runs as its own
system user before anyone has logged in and can't read a path under
`/home`, which is why the first two are store paths — and the third has to
*not* be, because it is written into a state file that outlives a `nix flake
update dotfiles`, and a store path there would be a wallpaper that had since
been garbage collected.

Under niri the default is a fallback, not an override. `wallpaper-restore`
runs at login and tries three things in order: the wallpaper last chosen from
`Mod+Ctrl+W` (`~/.local/state/niri-theme/wallpaper`), then the default, then a
random one out of the collection. So a fresh account lands on the same image
every time instead of on whatever `shuf` reached for, and anything picked
afterwards wins on every login after that. The random step is only reached if
the dotfiles ever stop carrying `nixos.png`.

### Which twenty, and who decides

A flake input:

```nix
wallhaven-toplist = {
  url = "file+https://wallhaven.cc/api/v1/search?categories=111&purity=100&sorting=toplist&topRange=1M&order=desc&atleast=1920x1080&ratios=16x9%2C16x10";
  flake = false;
};
```

That's the API's JSON search response — the **list**, not the images. Nix
fetches and hashes it like any other input, which is the whole point of doing
it this way: the twenty are pinned in `flake.lock`, the desk and the laptop
show the same twenty, and they change when you run `nix flake update` rather
than whenever wallhaven's front page does.

```bash
nix flake update --refresh wallhaven-toplist
```

`--refresh` because Nix caches fetched files for an hour and will otherwise
hand back the copy it already has. That's for re-locking the *same* URL —
editing the query is a different input entirely, and the next evaluation
re-locks it on its own. Commit the resulting `flake.lock` alongside the edit.
`file+https` rather than plain `https` because the plain form is the *tarball*
fetcher, which would try to unpack a JSON document.

The query is the website's Toplist view: all three categories (`111`), SFW
only (`100`), ranked over the last month, nothing below 1080p, and — via
`ratios` — widescreen only. Edit it and re-lock to change what "top 20"
means: drop `atleast` for the unfiltered list, `topRange=1d` for today's.
How many to keep is separate, and is `local.wallhaven.count` (1–24, the size
of one API page).

**`ratios=16x9,16x10`** is the widescreen filter. Both displays on the desk
are 16:9 — 2560x1440 and 1920x1080 — so 16:10 is the widest miss worth
taking, losing a sliver off the top and bottom when it scales. Anything
squarer arrives pillarboxed or cropped hard by whichever of awww or Plasma is
drawing it. The laptop panel isn't pinned in this repo at all
(`home/joshr/displays/laptop.nix` is deliberately empty), so it isn't what
the filter is measured against — `16x10` covers it if it happens to be one.

Two things about that parameter are easy to get wrong. It takes a
comma-separated list, but wallhaven's `landscape` supergroup is *not* the
same request — that's every non-portrait ratio it knows, `4x3` and `5x4`
included, which means "not portrait" rather than "wide". And the ultrawide
ratios (`21x9`, `32x9`) are left out deliberately: there's no display here to
put them on, and on a 16:9 panel they letterbox to a strip.

The comma is written `%2C` in `flake.nix`. Nix parses the query into
parameters rather than passing the URL through verbatim — you can see it
re-emit them alphabetically in `flake.lock` — so encoding the separator keeps
it unambiguously part of the value. wallhaven decodes it back on receipt.

A narrower query is drawn from a smaller pool, so a month with an unusually
vertical toplist can return fewer than `local.wallhaven.count` images.
Nothing breaks — the sync script takes what's there — the folder is just
occasionally short.

### Why the images aren't in the store

A flake input is one URL locked by one hash. The twenty image URLs aren't
known until that JSON has been fetched and read, by which point evaluation is
already under way — and wallhaven publishes no checksum for the files
anywhere in its API, so there is nothing for `pkgs.fetchurl` to verify even
if the URLs were known in time.

So the list is declarative and the files are not. `home/joshr/wallhaven.nix`
builds a `wallhaven-sync` script around the locked JSON; home-manager runs it
at activation and again at login (`wallhaven-wallpapers.service`), and you can
run it by hand. It downloads what the list names, deletes everything it
doesn't, and is careful in the two ways that matter:

- **It won't prune after a failed download.** Deleting yesterday's twenty
  because the network dropped halfway through would leave the picker emptier
  than it started. A run with any failure keeps everything and exits non-zero;
  the next one finishes the job.
- **It checks the JSON is a search response before believing it.** `nix flake
  update` will pin an error page as happily as a result set, and an error page
  parses as "zero wallpapers".

Files are named for wallhaven's id, so a wallpaper that merely slides from 3rd
to 5th place isn't downloaded again. A run with nothing to fetch touches the
network zero times — the list is a local store path by then.

The practical consequence of all this: a machine that hasn't had network since
the last `nix flake update` still shows the previous twenty. It isn't broken,
it just hasn't caught up. `wallhaven-sync` when it's back online.

### The one-off directory change

`~/.local/share/wallpapers` used to be a single symlink to the dotfiles'
wallpaper directory in the store. It's now a real directory of per-file links
(`recursive = true` in `home/joshr/home.nix`), because a read-only store path
has nowhere to put `WallhavenFlake/`.

Switching between those two shapes is not something home-manager handles on
its own — with the old symlink still there, every wallpaper's target resolves
*through* it into the store, and the linker spends the switch trying to back
up files it cannot move. So `wallhaven.nix` removes the stale link first, once,
before the linking phase. It only does this for a symlink pointing into the
store; one you made yourself, to another disk say, is left alone with a
warning.

### What the first rebuild will do

`flake.lock` has no `wallhaven-toplist` entry yet — wallhaven.cc was not
reachable from where this was written, so there was nothing to hash. Nix adds
the entry itself on the first evaluation that has network; commit the result
like any other lock change.

That also means the response shape was matched against wallhaven's documented
API (`data[].path`, one page of 24) rather than a live call. The sync was
exercised end to end against a stand-in server — fresh sync, toplist rotation,
mid-run download failure, an error page in place of a listing — but not
against wallhaven itself. If a field has moved since, the failure is the loud
kind: `wallhaven-sync` says "not a wallhaven search response", exits non-zero
and changes nothing.

## Dates and times

12-hour clock, month before day, everywhere. There is no single setting for
this — every clock either carries its own format string or asks the locale —
so it is set in each of them, and they're listed here because that's the only
way to find them all again:

| where | file | format |
|---|---|---|
| locale (`date`, `ls -l`, anything that asks) | `modules/nixos/base.nix` | `LC_TIME = en_US.UTF-8` |
| waybar clock | `home/joshr/niri/waybar.nix` | `%I:%M %p   %a, %b %d` |
| swaylock | `home/joshr/niri/scripts.nix` | `%I:%M %p`, `%A, %B %d` |
| SDDM greeter | `modules/nixos/niri.nix` | `h:mm AP`, `dddd, MMMM d` |
| Plasma panel clocks | `home/joshr/plasma.nix` | `time.format = "12h"` |
| screenshot filenames | `niri.nix`, `noctalia.nix`, `scripts.nix` | `%m-%d-%Y %I-%M-%S %p` |

Two things worth knowing before editing any of them:

- **waybar is not strftime.** It formats through libfmt/date.h, so glibc's
  `%-I` "no padding" extension doesn't exist there — it comes out as a
  literal `-I` or throws the whole format away. Hence `07:30 PM` rather than
  `7:30 PM` in the bar. SDDM is Qt format, which is different again: `h`
  means 12-hour as soon as an `AP` field is present.
- **Screenshot filenames no longer sort chronologically.** `%m-%d-%Y` puts
  every January together. That's the cost of matching the rest of the system;
  if you'd rather have sortable names back, `%Y-%m-%d %H-%M-%S` is the string
  to restore, in both `niri.nix` and `scripts.nix`.

## The browser

**Vivaldi**, on every host. `home/joshr/browser.nix` installs it, sets
`$BROWSER`, and is the one place that decides which browser is *the* browser.

Firefox is still installed and still themed (`home/joshr/firefox.nix`) — it
held the default for a while, and the notes below are what it is still good
for. It simply isn't what links open in any more.

One detail that bites: nixpkgs copies Vivaldi's upstream `.deb` desktop entry
across **without renaming it**, so the entry ID is `vivaldi-stable.desktop`,
not `vivaldi.desktop`. Naming the wrong one fails silently — `mimeapps.list`
keeps whatever string you give it and `xdg-open` just finds nothing. Both
spellings are listed wherever the format takes a fallback list.

Both sessions get it the same way now: **`modules/nixos/default-apps.nix`**,
which writes `/etc/xdg/mimeapps.list`. `kdeglobals.General.BrowserApplication`
in `home/joshr/plasma.nix` is still set and still agrees.

### File associations, and why they're in /etc

This used to be home-manager's `xdg.mimeApps`, which owns
`~/.config/mimeapps.list` and writes it as a read-only symlink into the store.
That is the same file every interactive "make this the default" writes to —
Dolphin's "Open With… → Remember application association for this type of
file", KDE's File Associations panel, Plasma's Default Applications page, "set
as default" inside a browser. With home-manager holding it, **all of them
appear to work and none of them persist.** Images kept reverting; the checkbox
looked like it worked and the association was gone by the next launch.

It was also why the Plasma hosts were deliberately kept away from
`xdg.mimeApps` — under a running Plasma it breaks the settings page outright.

So the declarations moved down a level. The XDG mime-apps spec reads, in order
of decreasing precedence:

```
$XDG_CONFIG_HOME/$desktop-mimeapps.list
$XDG_CONFIG_HOME/mimeapps.list      <- the user's; nothing manages it now
$XDG_CONFIG_DIRS/$desktop-mimeapps.list
$XDG_CONFIG_DIRS/mimeapps.list      <- modules/nixos/default-apps.nix
```

`$XDG_CONFIG_DIRS` is `/etc/xdg`, so the declared defaults apply on a fresh
install and on every rebuild, while anything picked in a GUI lands in the
user's own file and outranks them. Declarative defaults *and* a settings panel
that works, rather than one at the cost of the other. It also removed the
reason the two sessions were configured differently.

`[Default Applications]` is honoured there specifically because `/etc/xdg` is a
*config* directory — the spec only reads that group from `$XDG_CONFIG_HOME` and
`$XDG_CONFIG_DIRS`, which is why this isn't in a data dir.

Note that **System Settings alone would not have fixed any of this.** It ships
no KCMs; it's the shell they load into. The File Associations panel
(`kcm_filetypes`, plus the standalone `keditfiletype` that Dolphin's properties
dialog opens) is in `kde-cli-tools`, which the niri profile now installs.
Default Applications (`kcm_componentchooser`) is in `plasma-desktop`, which is
deliberately not pulled in — it's a large chunk of Plasma, and that panel only
covers the browser/email/terminal/file-manager four rather than file types.

### The media handlers, and why they replace KDE's own entries

Images, video and audio are the one set of associations that isn't handled in
`/etc`. `home/joshr/desktop-apps.nix` — the niri profile, and the only place
Gwenview, Haruna and Elisa are installed — declares them through
home-manager's `xdg.mimeApps`, and writes its own desktop entries for the
three applications to point them at.

Those entries exist because of *how* the app gets started, not which one.
Upstream's files are `DBusActivatable=true` and name a bare command, so an
open from Dolphin goes through D-Bus activation into a service with none of
the session's niri/Wayland environment. The entries here name an absolute
store path and set `DBusActivatable=false`, so KDE starts the process directly
and it inherits the environment that works.

**They use KDE's own ids** — `org.kde.gwenview`, `org.kde.haruna`,
`org.kde.elisa` — rather than a private spelling. That matters more than it
looks. A desktop entry is identified by its file name, and the first match in
the XDG data path wins, so an entry written to `~/.local/share/applications`
under an upstream id *replaces* the package's copy in
`~/.nix-profile/share/applications` instead of sitting next to it. Written
under any other name, both files survive and every launcher shows the
application twice — which is exactly what an earlier `<username>-gwenview`
spelling did, two Gwenviews, two Harunas and two Elisas in the menu.
`home/joshr/obs.nix` overrides `com.obsproject.Studio` the same way and for
the same reason.

Two things follow from shadowing an upstream entry:

- **It is a replacement, not a merge.** What that file says is the whole
  entry. The MIME lists in `desktop-apps.nix` are therefore the complete set
  of types these applications are offered for, and upstream's translated names
  and search keywords are not inherited. Adding a format means adding it to
  the list there.
- **`WM_CLASS` lines up again.** Qt applications set their window class from
  their own desktop-file name, which for these three is the `org.kde.*` id;
  while the entries were called `<name>-haruna` nothing could match a running
  window back to the entry that launched it.

Ranger is unaffected either way — `home/joshr/ranger.nix` binds image, video
and audio to the same three store paths in `rifle.conf` directly, without
going through desktop entries at all.

The system baseline in `modules/nixos/default-apps.nix` still has these three
types commented out. That is deliberate: it reaches every graphical host, and
the Plasma ones don't install these applications, so naming them there would
resolve to nothing. The profile that does install them declares them itself.

### Why Firefox is still here

The requirement when it took over was cloud sync, a Chromium or Firefox base,
and colours that follow the desktop theme. Firefox is the only candidate that
does all three without a workaround:

- **Sync** is Firefox Sync over a Mozilla account — first-party, end-to-end
  encrypted, carrying bookmarks, history, open tabs, logins, add-ons and
  preferences between the desk and the laptop with no server of your own.
  Sign in from the toolbar's account button; nothing about it is configured
  here beyond leaving `identity.fxaccounts.enabled` alone.
- **Theming** is the part that ruled the others out. A Chromium UI takes its
  colours from a signed theme extension or from GTK, and neither reads a file
  you generate. Vivaldi *can* take arbitrary colours, but only through its own
  settings UI, into a preferences blob that isn't declarative and can't be
  repointed at a symlink. Firefox reads `chrome/userChrome.css` out of the
  profile directory at startup, so it plugs straight into the mechanism
  already in place for everything else.

### How it follows the theme

`themes.nix` grows two more generated files per palette,
`firefox-userChrome.css` and `firefox-userContent.css`, and
`home/joshr/niri/firefox.nix` symlinks the profile's `chrome/userChrome.css`
and `chrome/userContent.css` at the active theme — the same out-of-store
symlink trick as `kdeglobals`. Tab strip, toolbars, address bar, menus,
sidebar, findbar and the `about:` pages all end up on the palette's ten
colour roles, with the accent on the selected tab and the focused address
bar, exactly like niri's focus ring and waybar's active workspace.

Two honest caveats:

- Firefox reads those stylesheets **once, while it starts**. There's no
  supported way to make a running Firefox re-read them, so a theme switch
  lands at the next launch — same as Dolphin, unlike kitty and waybar which
  the switcher can nudge.
- `userChrome.css` works against Firefox's internal CSS variables, not a
  documented config format. The names have been stable since the Proton
  redesign, but they aren't API. If an update renames one, that surface falls
  back to the built-in dark theme rather than breaking; the fix is to diff
  against `browser.css` in the new version.

All of that is niri-only, for the same reason the kitty `include` is: the
Plasma hosts have no theme state for the symlinks to point at, so there
Firefox wears its own dark theme and takes its accent from Plasma like any
other GTK app.

Note `home/joshr/niri/firefox.nix` is currently not imported by
`home/joshr/niri/default.nix`, so the stylesheet symlinks aren't in place.
Uncomment it there to turn Firefox's theming back on; the `xdg.mimeApps`
block that used to live in it has moved to `./browser.nix`, so the two won't
collide.

### What Nix owns and what Sync owns

Nix owns the *shape* of the browser — which prefs are set, that custom
stylesheets are on, that it handles `http(s)`. Sync owns the *contents* —
bookmarks, history, tabs, logins, add-ons.

That split is deliberate. Declaring add-ons here would need the NUR or the
firefox-addons flake, and would then fight Sync every time the two disagreed:
Nix would reinstall on the desk what you removed on the laptop. The prefs in
`firefox.nix` are written to `user.js`, which Firefox re-applies on **every**
start, so where the two overlap the declared value always wins. The practical
rule: anything you want to change from inside the browser and have stick must
not be listed in `firefox.nix`.

## Bootloader

`local.boot.loader` picks one of three, in `modules/nixos/boot.nix`:

| | themed | finds other OSes by |
|---|---|---|
| `limine` (default) | fixed NixOS wallpaper + full palette; colours follow runtime switches | scanning every ESP on the machine for other loaders |
| `grub` | palette + fixed splash, build time only | `os-prober` |
| `systemd-boot` | not at all | itself, no setting needed |

limine is the default because it's the only one that can put the configured
wallpaper and the desktop's live colours on the boot menu. grub is the fallback
for anything it can't handle — BIOS/MBR, odd partition layouts, firmware that
dislikes limine's EFI binary — and it still detects *more*, since os-prober looks
inside other partitions rather than only at EFI System Partitions.
systemd-boot is the escape hatch and what this repo used before the module
existed:

```nix
local.boot.loader = "systemd-boot";
```

**Changing this rewrites how the machine boots.** Do it on a rebuild you can
watch, with install media to hand. The previous generation stays in the *old*
loader's menu — but only while that loader is still installed and still the
one your firmware runs.

### Dual boot: finding the other operating systems

**On by default.** `local.boot.detectOtherSystems = true` is the setting, and
under limine the scan runs in two passes:

1. **This machine's own ESP.** That is the whole story for a dual boot where
   both systems share one EFI System Partition, which is what you get when
   they're installed onto the same disk.
2. **Every other ESP attached to the machine**, behind
   `local.boot.scanAllEsps` (also on by default). NixOS mounts exactly one
   ESP, so an OS installed onto a disk of its own is otherwise invisible.
   Each is located by GPT partition type, mounted read-only, read, and
   unmounted. Nothing is written, and the service runs with `PrivateMounts`
   so a mount can't outlive the scan even if it's killed mid-way.

Whatever it finds appears under an **"Other operating systems"** branch in the
boot menu — one chainload entry per vendor directory that carries a
recognised loader (`bootmgfw.efi` for Windows, `shimx64.efi` or `grubx64.efi`
for a distro, rEFInd, elilo). Entries on this machine's ESP are addressed as
`boot():/…`; entries on any other are addressed by filesystem UUID, since
`boot()` only ever means the volume limine itself was loaded from.

To see what it found without rebooting:

```bash
sudo systemctl start limine-theme-sync
grep -A100 'detected systems' /boot/limine/limine.conf
```

Nothing found? The scan only reads EFI System Partitions. An OS whose loader
isn't on one — an old BIOS/MBR install, or a distro on an LVM or LUKS volume
with no ESP of its own — needs grub, whose `os-prober` inspects partitions
rather than boot partitions:

```nix
local.boot.loader = "grub";   # detects more, but no runtime theming
```

To turn detection off entirely, or to leave other disks alone:

```nix
local.boot.detectOtherSystems = false;   # no other-OS entries at all
local.boot.scanAllEsps = false;          # this machine's ESP only
```

### How the boot menu ends up wearing the desktop's colours

The menu is drawn before any of the desktop exists, from a text file on the
EFI System Partition. So the palette is *pushed* there ahead of time, the same
way the SDDM greeter is fed, and for the same reason: the thing being themed
can't read your home directory.

What gets pushed is noctalia's resolved palette manifest, not the name of a
theme — see "Theme sync under noctalia". A name only ever described one of
noctalia's four palette sources, and this module used to carry a whole
directory of prebuilt colour blocks indexed by it, which under noctalia could
never match. One build-time block remains as the fallback for the first boot
and for the Plasma hosts, which write no manifest at all.

The NixOS limine module regenerates `<esp>/limine/limine.conf` on every
rebuild, so a runtime edit can't just go anywhere in it. What makes it work is
that the module emits two verbatim blocks at known ends of the file —
`extraConfig` first, `extraEntries` last. Each gets a sentinel-delimited
region, filled at build time with the default palette and no detected systems.
`limine-theme-sync` then rewrites the *inside* of each region, running at
boot, whenever the session's palette changes, and at the end of every
bootloader install. That last one matters: the install rewrites `limine.conf`
from `extraConfig`, so without it every rebuild would put the menu back on the
build-time palette until something else woke the sync. If it never runs, the
menu is still valid and still themed, just with the default palette.

The regions sit where they do because limine's config has no separator between
global options and menu entries: an entry is opened by a line starting with
`/` and swallows every option after it. Theming keys are global and must go
above the first entry; detected-OS entries must go below the NixOS ones.

Three things keep this from being a way to brick the machine, and all three
are enforced in the module:

- **`enrollConfig` stays off.** Enrolling hashes the config into the limine
  binary; a rewritten file then fails its own integrity check and you stop at
  the bootloader. This is the one setting that turns a cosmetic feature into
  an unbootable system.
- **The wallpaper lives outside `<esp>/limine/`.** The installer walks that
  directory and deletes every file it didn't itself write, so an image parked
  there survives exactly until the next rebuild.
- **The config never names a wallpaper that isn't there.** Both the build-time
  block and the sync emit the `wallpaper:` line only alongside a file that
  exists.

The session's wallpaper is **not** mirrored to the ESP. When
`local.boot.wallpaper` is null, limine uses the familiar `nixos.png` from the
dotfiles input; setting it replaces that fixed image. The sync keeps naming the
build-time copy, and a rebuild replaces any old session wallpaper that an
earlier generation left at the same ESP path. Writing a fresh 1080p PNG to a
FAT partition shared with the firmware on every wallpaper change was a lot of
churn for a screen that is up for two seconds.

`style.wallpapers` and the `style.graphicalTerminal.*` options are deliberately
left alone — they'd write the same keys from build-time values, duplicating
every line, and `style.wallpapers` additionally appends a BLAKE2b hash of the
image to the path, which is exactly what stops a file being swapped underneath
it at runtime.

Detection is ESP-only under limine: an OS on a disk that isn't mounted here
won't be seen, and a distro shipping both shim and grub is listed once (shim
wins — it's what boots under Secure Boot and hands over to grub itself).

```nix
local.boot.detectOtherSystems = false;   # skip the scan entirely
local.boot.wallpaper = ./some.png;       # replace the default NixOS menu image
local.boot.branding = "gamestation";     # text above the menu
local.boot.menuTransparency = "50";      # TT of limine's TTRRGGBB
```

### The boot splash

What covers everything *after* the menu: an animated NixOS logo with a progress
bar under it, paced like a Mac's boot animation, instead of the kernel's
scrolling messages. `modules/nixos/plymouth.nix`, imported by `boot.nix` so the
option exists wherever the bootloader module does.

```nix
local.boot.plymouth.enable = true;    # on for the four fixed graphical hosts
local.boot.plymouth.quiet = true;     # the default: turn the messages down too
```

**Off unless a host asks for it**, and the four that ask are the desk and the
laptop in both their Plasma and niri configurations. The two servers don't: a
splash needs an audience, and the console output it replaces is the only thing
to look at when a headless machine doesn't come back. Neither does the stick,
which is the one machine that boots on hardware it has never seen — the boot
most likely to need explaining is the worst one to have covered up.

**The theme's name is a trap.** The flake input is
`github:SergioRibera/s4rchiso-plymouth-theme` and the theme it installs is
called `mac-style`. That repository began as an Arch theme — an animated Arch
logo, still on its `archlinux` branch — and its default branch is now a flake
carrying a NixOS-logo theme under that name. The input, the overlay
(`overlays.default`) and the package (`pkgs.mac-style-plymouth`) are all named
the way that branch's README names them, and what boots is the NixOS
animation.

The overlay is applied inside the module rather than in `flake.nix`, the same
arrangement as nvidia-patch's: named at the top it would reach every host, and
this one should only reach hosts that draw a splash. The README's snippet puts
it at the `import nixpkgs` because that is the shape of a README, not a
requirement of the overlay.

`quiet` is the half people usually mean by "splash". Plymouth owns the
framebuffer from the initrd onwards, but the kernel writes to the console
directly and outranks it — one printk at the wrong level and the animation
spends the rest of the boot underneath a driver message. So the option turns
the sources down rather than covering them up: `quiet` and `loglevel=0` for the
kernel, `udev.log_level=3` (and the `rd.` copy of it) for the loudest thing in
the initrd, and `boot.initrd.verbose = false` for NixOS's own stage-1 chatter.
Turn it off to keep the messages and the animation both — worth doing on a
machine misbehaving early in boot. `journalctl -b` has all of it either way.

Nothing here hides a failure. A stage-1 that panics drops to the emergency
shell with its messages intact, and **Escape** at any point during the boot
switches to the console. Because this theme is built on plymouth's `two-step`
module it can also draw a password dialog, so a machine with an encrypted root
still gets somewhere to type — which the Arch theme on the other branch, with
no password function at all, would not have.

## Shells

Fish is the login shell for both `joshr` and `root`, but zsh, bash and
nushell are all installed and configured too, and **all four get the same
starship prompt** from `home/common/files/starship.toml`.

Two things are needed for that, both in `home/common/shell.nix`. starship's
`enable*Integration` options already default to `true`, but all they do is
set the corresponding `programs.<shell>` options — and home-manager only
writes a shell's rc file when that shell's own module is enabled. So the
shells are enabled explicitly alongside the integrations; with only one half,
the prompt silently doesn't appear.

Note that only fish carries the eza aliases (`ls`, `ll`, `la`, `lt`, `lg`) —
those came from the dotfiles' `config.fish.tmpl` and haven't been mirrored
into the other shells.

### `nix-clean`

Also fish-only, and also in `home/common/shell.nix`, so `joshr` and `root`
both get it. It's the on-demand version of the weekly garbage collection in
`modules/nixos/base.nix`, for when you want the space back now:

```fish
nix-clean          # generations older than 7d, matching the weekly timer
nix-clean 30d      # any age nix-collect-garbage accepts
nix-clean all      # every generation but the current one
```

It runs `nix-collect-garbage` **twice**, and that's the point of it. The tool
only walks the profiles it can see, and which profiles those are follows
`$HOME`. The `sudo` run gets the system profile — old kernels, initrds and
system closures, which is where the space actually is — but root's `$HOME` is
`/root`, so it never reaches `~/.local/state/nix/profiles`, where
home-manager keeps joshr's generations. Sweep only the system half and those
stay pinned as live GC roots, holding their whole closures down with them.
The second run is skipped when you're already root, where it would just
repeat the first.

The current generation always survives, both here and under `all`. What you
spend is rollback: picking a previous generation from the boot menu is the
recovery path for a bad switch, which is why `all` has to be asked for by
name. Deleted generations also stay *listed* in the menu until the bootloader
config is regenerated, so the function ends by reminding you to
`sudo nixos-rebuild boot --flake /etc/nixos#<host>` — and `<host>` there is
the flake attribute, not the hostname. On this machine those differ:
`gamestation` and `gamestation-niri` both run on a box called `dialga`.

### `nix-delete-gens`

`nix-clean`'s sibling, in the same file and also fish-only. Same job, counted
rather than dated: keep the newest N generations and delete everything below
them, for when "I want to be back to ten generations" is the actual thought
and working out which date that is would be a detour.

```fish
nix-delete-gens        # keep the newest 10
nix-delete-gens 3      # keep the newest 3
```

It prints the generation numbers it is about to delete and waits for a `y`
before touching anything — the one place it differs from `nix-clean`, which
just goes. Anything other than `y`/`yes` aborts, as does an empty answer.

The deletion itself is `nix-env --delete-generations +N`, whose rule is worth
knowing because it is deliberately more careful than "keep the newest N": it
counts N back from the **current** generation, and never deletes the current
one or anything above it. On a machine sitting on a rollback — booted into
generation 8 with 15 present — the seven above you are what you'd roll
forward to, and they stay. The preview does the same arithmetic so that the
list it shows is the list that goes.

Both profiles are trimmed, then swept, for the reason spelled out under
`nix-clean` above: the `sudo` half reaches the system profile, the plain half
reaches home-manager's, and the second is skipped when you already are root.
Deleting a generation only unlinks it, so garbage collection is what turns it
back into free space — hence the sweep at the end rather than a separate
`nix-clean` run afterwards. The boot-menu caveat is the same one, and the
function closes with the same reminder.

## Development environments

Both machines are set up so that **no language toolchain is installed
globally**. Python, node, a Rust compiler, JDKs, `gcc`, database clients —
none of it lives in the user profile. Each project declares what it needs in
its own `flake.nix`, and direnv puts those tools on `PATH` when you `cd` in
and takes them away again when you leave.

That's not asceticism. Two projects wanting different Python minor versions
is the normal case, and the moment toolchains are global, the second one is a
problem to be worked around. Per-project shells make it a non-event, and the
declaration travels with the repo, so the laptop and the desk agree without
either being configured for that project at all.

### One import, and it's off by default

All of it lives in **`modules/nixos/development.nix`**, and the import line is
**commented out in every desktop host**. Uncomment it on the machines you
actually develop on:

```nix
# hosts/gamestation/configuration.nix
    # ../../modules/nixos/development.nix     <- delete the #
```

`server` is the exception — it imports the module for real, since a headless
box is where containers and a remote `nix develop` are the point.

Note what that costs when it's off: **Docker goes with it.** The old
`modules/nixos/virtualisation.nix` had nothing in it but Docker and
docker-compose, so it was folded in here rather than left as a second thing to
remember. There's no finer granularity on purpose — one switch, one mental
model. `joshr`'s membership of the `docker` and `libvirtd` groups follows the
daemons automatically (`modules/nixos/users.nix`), so a host with the module
off doesn't fail activation naming groups that don't exist.

**VMs are a separate import.** QEMU/KVM and virt-manager used to be in here
too, and are now `modules/nixos/virtualization.nix`, added per host the same
way:

```nix
# hosts/gamestation-niri/configuration.nix
    ../../modules/nixos/virtualization.nix
```

Both are "virtualisation" in the NixOS option tree, which is how they ended up
in one file, but they aren't one decision: libvirtd is a daemon, a bridge
interface, swtpm and a GUI app, and wanting containers on a box is a poor
reason to be handed all of that. The group membership works the same way —
`users.nix` keys off `config.virtualisation.libvirtd.enable`, so importing one
module and not the other is fine.

What that one turns on: **libvirtd** with `qemu_kvm` and `runAsRoot = false`
(the failure mode of the other setting is a guest escape being a root escape);
**swtpm**, the software TPM a Windows 11 guest insists on; **virt-manager** as
the GUI, via `programs.virt-manager` rather than the bare package because the
module also enables the dconf settings it keeps its connection list in; **SPICE
USB redirection**, so a passed-through YubiKey or flash drive reaches the
guest; and `virtiofsd` + `spice-gtk` for host directory sharing and the console
client.

What the module turns on:

- **direnv** with **nix-direnv**, hooked into bash, zsh and fish. Plain direnv
  re-evaluates `use flake` from scratch on every `cd`, which for a flake means
  seconds each time; nix-direnv caches the built profile and only
  re-evaluates when `flake.nix` or `flake.lock` change. It also plants a GC
  root in `.direnv/`, so the weekly `nix-collect-garbage` in `base.nix` can't
  delete a shell you're still using.
  - This is the NixOS module, not home-manager's, so the whole story is one
    import. The one gap is **nushell** — the NixOS module doesn't hook it.
  - Per-user tuning (`hide_env_diff`, `warn_timeout`) is a
    `~/.config/direnv/direnv.toml` thing that no system module can set.
- **Docker** + docker-compose.
- **`dev-init`**, the one-command path below.
- The nix settings the rest depends on, all of which need root: `keep-outputs`
  and `keep-derivations`, without which garbage collection deletes the *build*
  inputs of a dev shell (a shell isn't a package, so nothing points at its
  output); `trusted-users = [ "root" "@wheel" ]`, without which `cachix use`
  can't write a substituter; and `log-lines = 25`, because ten lines of a
  failed builder's output usually isn't the part that says what went wrong.
- **A pinned `nixpkgs` in the flake registry**, set to the rev this system is
  built from. Every template says `inputs.nixpkgs.url = "nixpkgs"` rather than
  naming a URL, so a new project's shell resolves to store paths the machine
  already has. It's what `nix run nixpkgs#...` means here too. See [Why a
  project shell is instant](#why-a-project-shell-is-instant).
- Language-agnostic tools: `nil`, `nixfmt`, `nix-output-monitor`,
  `nix-tree`, `cachix`, `just`, `jq`, `yq-go`, `ripgrep`, `fd`, `lazygit`,
  `gnumake`. Nothing language-specific — a compiler or an interpreter goes in
  the project's own devShell.

### The one-command path

In the project directory:

```bash
dev-init            # generic skeleton
dev-init python     # or: node, rust, go
```

That copies a template's `flake.nix`, `.envrc` and `.gitignore` in and marks
the `.envrc` trusted, so the shell is built and entered at the prompt you get
back. Commit all three files — the whole point is that the next machine gets
the same environment by cloning.

`dev-init` refuses to run where a `flake.nix` already exists rather than
overwrite one.

### The manual path

Two files. `flake.nix`:

```nix
{
  # Resolved through the flake registry — see below.
  inputs.nixpkgs.url = "nixpkgs";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ python313 postgresql ];

        # Exported on entry, gone on exit.
        env.DATABASE_URL = "postgres://localhost/dev";

        shellHook = ''
          echo "ready"
        '';
      };
    };
}
```

and `.envrc`:

```
use flake
```

Then `direnv allow`. direnv refuses to run an `.envrc` it hasn't been told to
trust — that message on first entry, and after every edit, is the safety
check working, not a failure.

### Day to day

| | |
|---|---|
| add a tool | put it in `packages`, save; direnv rebuilds on the next prompt |
| find the attribute name | `nix search nixpkgs ripgrep`, or search.nixos.org |
| pin the exact versions | commit `flake.lock` — it's what makes the shell reproducible |
| update them | `nix flake update`, or `nix flake update nixpkgs` for one input |
| force a rebuild | `direnv reload` |
| run one command without entering | `nix develop -c pytest` |
| a second shell (e.g. CI) | `devShells.${system}.ci = ...`, entered with `use flake .#ci` |

Anything the project writes at runtime — a venv, `node_modules`, `GOPATH` —
stays inside the project directory. The templates set that up and ignore the
paths in `.gitignore`, because the Nix store is read-only and the alternative
is a tool failing halfway through an install with a confusing error.

### Why a project shell is instant

Two things keep `direnv allow` down to a couple of seconds, and both are easy
to undo by accident.

**The shell resolves to a nixpkgs the machine already has.** The templates say
`inputs.nixpkgs.url = "nixpkgs"` — an indirect ref, which `development.nix`
pins in the flake registry to the rev this system is built from. Name a URL
there instead and the project locks against whatever `nixos-unstable` was that
afternoon: nothing is *wrong* with the result, but every path the shell needs
becomes a fresh download of a bit-for-bit alternative to something already in
`/nix/store`. Pinned, `nix flake update` in a project re-resolves against the
system's current lock, so the shells move when the machines do — which is the
reason the templates live in this repo at all.

**Python libraries come from a package set nixpkgs actually builds.** This is
the one that bites. nixpkgs exposes a package set per interpreter but only
marks some of them `recurseIntoAttrs` in `all-packages.nix`:

```nix
python311Packages = python311.pkgs;                   # evaluated, never built
python312Packages = python312.pkgs;                   # evaluated, never built
python313Packages = recurseIntoAttrs python313.pkgs;  # built by Hydra
python314Packages = recurseIntoAttrs python314.pkgs;  # built by Hydra
python3Packages   = dontRecurseIntoAttrs python314Packages;
```

Hydra enumerates the recursed sets and builds them, and cache.nixos.org holds
what Hydra builds. The others evaluate perfectly well and are simply never
built, so every derivation in them is compiled locally — test suites included
— each time the lock moves. The list changes: 3.11 fell off in December 2024,
3.12 in November 2025.

The **interpreters** are all built regardless. `pkgs.python312` is a
substituted binary like anything else, so choosing a minor version is free.
It's asking an unbuilt *set* for a library that isn't.

Which is exactly what the python template used to do. It read
`python312.pkgs.python-lsp-server` from the moment 3.12 stopped being built,
and python-lsp-server's check inputs are numpy, pandas and matplotlib plus its
whole optional-linter set — so a first `cd` into a project compiled all of
that before returning a prompt, and did it again after every `nix flake
update`. It now takes pylsp from `python3Packages`, which is always the
default and always built, and leaves the project's interpreter a free choice:
jedi resolves completions from `$VIRTUAL_ENV`, so a language server running on
3.14 reads a 3.12 venv correctly.

When a shell is unexpectedly slow, this says what it's about to do:

```bash
nix build --dry-run .#devShells.x86_64-linux.default
```

Paths under "will be fetched" are a download. Anything under "will be built"
that isn't your own package is a set that nobody cached.

### Secrets

Don't put them in `flake.nix` — it goes in the store, world-readable. Use a
gitignored `.env` and read it from `.envrc`, which direnv evaluates on your
machine and never copies anywhere:

```bash
# .envrc
use flake
dotenv_if_exists .env
```

### A project that isn't yours

Most repos don't ship a flake. Add one anyway — `dev-init` in a clone works
fine, and `flake.nix`, `.envrc` and `.direnv/` can stay out of the repo's
history via `.git/info/exclude` if you'd rather not commit them upstream.

If a project has a `shell.nix` or `default.nix` already, skip the flake
entirely and let direnv use it:

```
# .envrc
use nix
```

And when the dependency really is a whole service rather than a binary —
Postgres, Redis, a message queue — reach for Docker Compose instead; both
hosts have it via `modules/nixos/virtualisation.nix`. A dev shell is for
tools, not daemons.

### VS Code

The editor has to be told about direnv, or it sees the bare system `PATH` and
reports every import in the project as unresolved. `mkhl.direnv` is in the
extension list in `home/joshr/vscode.nix` for that reason — it hands the
shell's environment to language servers, terminals and the debugger. If
something still looks wrong, launching `code .` from inside a directory
direnv has already loaded is the quick way to tell the two apart.

`jnoortheen.nix-ide` is in the list too, pointed at the `nil` and `nixfmt`
from `development.nix` rather than downloading its own — so on a host with
that module still commented out, neither name resolves and both settings are
inert.

## Gaming performance

The complaint this section exists for: a game that starts fine and is bad
later. Frames stutter, the card is not delivering anything like what it
should, and nothing in particular happened in between.

That shape — fine, then not — is worth taking seriously, because it rules
most things out. A machine that is simply misconfigured is slow from the first
frame. Something that degrades has to be *accumulating*, and on this box there
are only a few things that can accumulate: video memory that something else
took and did not give back, a shader cache that filled up and got thrown away,
heat, and pipelines being compiled over and over. They feel identical from the
chair and they are told apart by numbers, so the first thing here is a way to
get the numbers.

### `gaming-doctor`

`modules/nixos/gaming.nix` installs a `gaming-doctor` command on the two desk
hosts. Run it **while it is bad** — almost everything it prints is an
instantaneous reading, and a report taken after quitting the game says nothing:

```
gaming-doctor
```

It prints, in order: the driver version and whether this is the open kernel
module; the card's memory, temperature, power and current-versus-maximum
clocks; NVIDIA's own "Clocks Event Reasons" block; every process holding video
memory, graphics and compute alike; what the local model server has resident;
the size of the shader cache and whether the cleanup is switched off; the EGL
external platform files; system memory and swap; the CPU governor, the power
profile and gamemode's status; and the compositor's outputs.

Reading it:

- **Video memory at or near the card's total**, or a second process holding a
  large chunk of it, is the eviction case. Past that line the NVIDIA driver
  spills to system memory and the frame rate does not so much drop as fall
  over, and it does not recover on its own.
- **A graphics clock far below its maximum**, with something other than
  `GpuIdle` marked Active under Clocks Event Reasons, is throttling. That is a
  case, fans and paste answer; nothing in this repository will fix it.
- **`~/.cache/nv` near a gigabyte with `SKIP_CLEANUP` unset** is the next
  section.
- **An empty EGL external platform listing** is the one after that.

One finding also leaves the terminal. If the model server has anything resident
when the report is taken, `gaming-doctor` raises a notification saying which
models and how much video memory each has. That is deliberately the only one:
it is the finding with an action attached, and this is a command as likely to
be bound to a key and hit mid-game — where the terminal is behind a fullscreen
window — as it is to be typed at a prompt. Nothing is raised on a clean report,
and a run over ssh with no session bus behind it just prints, as before.

### The controller, and the second cursor

This one is not about frame rate, and it is here because it is the other thing
that makes a game unplayable on this machine.

The symptom: a Steam Controller moves *something*. Steam's own interface reacts
to it, buttons under it highlight, clicks land — and the cursor on screen never
moves. There are two pointers and only one of them is drawn.

**It is not niri, and it is not this configuration.** Steam is an X11 program,
and its desktop-level mouse emulation — the Desktop Layout, the Big Picture
cursor, the guide-button chord that turns the right pad into a mouse — is
written against the X11 XTEST extension. XTEST is a request to an X server to
*pretend* a device did something. In a Wayland session there is no X server
that owns the pointer: Steam is an Xwayland client, so the fake motion moves
Xwayland's private idea of where the cursor is, and the compositor — which
draws the cursor and decides which surface gets the click — is never told.
Other X11 windows follow the phantom, which is why Steam itself reacts.
Everything else, including the shell's own panels, ignores it.

Valve has had the report since 2023
([steam-for-linux#9318](https://github.com/ValveSoftware/steam-for-linux/issues/9318),
closed as not planned), it happens on the Steam Deck's own desktop, it happens
under Plasma Wayland, and it happens under Hyprland
([steam-for-linux#13185](https://github.com/ValveSoftware/steam-for-linux/issues/13185)).
Changing compositor does not change it. See
[Would Hyprland be better?](#would-hyprland-be-better).

What does change it is giving those XTEST calls somewhere real to land:

```nix
local.gaming.steamInputOnWayland = true;   # the default
```

That switches on `programs.steam.extest.enable`, which preloads
[extest](https://github.com/Supreeeme/extest) into Steam. extest replaces the
XTEST entry points at load time and, instead of asking an X server for a fake
event, opens `/dev/uinput` and creates a virtual input device — which the
kernel, and therefore the compositor, treats as an actual mouse plugged into
the machine. The pointer it moves is the one on screen, over every window, X11
or Wayland or the bar. nixpkgs sets the `LD_PRELOAD` in Steam's own
environment, so it reaches Steam and the games Steam starts and nothing else on
the system.

Two prerequisites are already met here and are worth knowing because they are
what breaks first. `/dev/uinput` has to exist and be writable:
`hardware.steam-hardware.enable` (which `programs.steam.enable` turns on for
us) loads the uinput module and installs Valve's udev rules, one of which tags
the node `uaccess` so whoever is logged in at the seat gets an ACL on it. And
every interactive account here is in the `input` group, which is the second
route to the same permission.

The cost is a line of noise. extest is a 32-bit library because Steam is a
32-bit program, so every 64-bit process Steam starts — which is most games —
gets an `ERROR: ld.so: object 'libextest.so' ... cannot be preloaded ...:
ignored` on stderr and carries on. It is ugly and it is harmless.

**Checking it, in order.** `gaming-doctor` ends with two sections for this, and
they are meant to be read top to bottom because each one only means something
if the one above it is fine:

```
== controllers ==
  Valve Software Steam Controller        mouse1 event6
  Valve Software Steam Controller Puck   mouse2 event8
  extest fake device                     mouse3 event11

  node     product driver       open by
  hidraw2  1102    hid-steam    steam(4711)
           Valve Software Steam Controller
  hidraw4  1304    hid-generic  steam(4711)
           Valve Software Steam Controller Puck

== steam input on wayland ==
programs.steam.extest.enable = true
crw-------+ 1 root root 10, 223 Aug 15 09:12 /dev/uinput
  writable by joshr
steam pid 4711: LD_PRELOAD=/nix/store/…-extest-…/lib/libextest.so
extest fake device: present — XTEST is reaching the real pointer
```

An empty first section is a cable, a battery or a dongle and nothing below it
applies. On the `/dev/uinput` line the mode bits are not the interesting part
— the node is root-owned and the `+` is the ACL udev's `uaccess` tag added for
whoever is logged in — so the `writable by` line under it is the answer. Not
writable is a permissions problem, and extest cannot even create its device.
A running Steam with no `LD_PRELOAD` is a Steam that did not come through the
wrapper — a Flatpak, a stale desktop entry, or a shell that predates the
rebuild. And `extest fake device: absent` with everything above it healthy
just means nothing has asked XTEST for pointer motion yet: open the Desktop
Layout, move the pad, look again.

**Two pads, and the table that tells them apart.** The product column is the
identity: `1102` is the wired 2015 Steam Controller, `1142` its wireless
dongle, `1205` a Steam Deck, and `1304` the 2026 controller, which enumerates
as "Steam Controller Puck". `steam` in the last column is Steam having claimed
that pad over hidraw, which is both correct and the moment lizard mode ends —
it is what Steam Input's layouts require, and it is why the section under it
has to work.

The driver column is where the two generations genuinely differ, and it is not
a configuration choice. `hid-steam`'s device table is those first three
product ids and nothing else (`steam_controllers[]` in
`drivers/hid/hid-steam.c`), so a 2015 pad gets a kernel driver that owns its
lizard mode — the firmware's mouse-and-keyboard emulation, switched off when a
hidraw client opens the device and switched back on when the last one closes.
The 2026 pad falls through to `hid-generic`. Its lizard mode is the firmware's
own decision, nothing in the kernel is managing it, and there is no kernel-side
path that puts it back.

**The 2026 pad, and the case extest might not cover.** There is a second,
Valve-side bug filed against that controller
([steam-for-linux#13185](https://github.com/ValveSoftware/steam-for-linux/issues/13185)):
Steam misidentifies it as Steam Deck hardware and its registration fails
(`BYieldingCompleteSteamControllerRegistration - Error ... Invalid Parameter`
in the Steam log). The reporter's symptom is the same phantom cursor described
above, which is XTEST and is what extest catches — so extest is the first thing
to try for that pad too, and the same `extest fake device: present` line is the
proof. Their diagnosis blames the registration failure, but the uinput device
Steam fails to create is not the one the desktop cursor comes from on Linux;
XTEST is.

What to do if it *is* the harder version — extest loaded, permissions fine,
and still no `extest fake device` after moving the pad, meaning Steam is
issuing no XTEST at all — is give the pad back to its firmware. Turning Steam
Input off for that controller (Steam → Settings → Controller) stops Steam
claiming it, at which point the `open by` column empties and the pad returns to
lizard mode: a plain USB mouse and keyboard as far as the machine is concerned,
with the trackpad moving the real cursor and nothing in the path that can
break.

That is a real trade rather than a free fallback, and the same table says why.
In lizard mode the 2026 pad emits keyboard and mouse events and *no gamepad* —
and with no `hid-steam` behind it there is nothing to synthesise one, so it
stops being usable as a controller in games. Steam creates the virtual gamepad
(`28DE:11FF`) other software sees, which is exactly the thing being turned off.
The 2015 pad is not in the same position: it has the kernel driver, so it comes
back on its own whenever Steam lets go.

There is deliberately no option here for forcing that by taking the hidraw node
away from Steam in udev. It would work, and it would cost the pad's entire
purpose to fix its pointer, which is a decision to make in Steam's settings
where it can be undone in a second rather than in a rebuild.

### The desktop is also drawing

Everything else in this section is about the machine. This one is about the
session sitting on top of it, which on the niri hosts is not free: niri runs a
three-pass blur behind the bar every time that region is redrawn, noctalia
animates every widget and panel it owns, both of them composite translucent
surfaces, and noctalia's system monitor holds an NVML handle open and asks the
card for its temperature and VRAM every five seconds — while the game is on it.

`Mod+G` turns all of that off, and `gamemoderun` does it for you at the start
of a game and undoes it at the end. See [GameMode](#gamemode) for what
changes, what turns it back off, and why the mode outlives a game you started
it before.

It is not a substitute for anything below. A blurred bar does not cause the
sawtooth, and turning off animations will not un-evict video memory — this is
a few percent of frame time and some GPU contention, where the next three
sections are the difference between a game running and a game falling over.

### VRR, and the judder that isn't the game

There is a kind of stutter that no amount of frame rate fixes, because it is
not the game producing frames badly — it is the display refusing to show them
when they arrive.

A fixed 180Hz panel puts a new image up every 5.6ms and at no other time. A
frame that took 7ms to render therefore waits until 11.2ms, a frame that took
4ms waits until 5.6, and a game whose frame times wander a little around the
refresh interval — which is every game — is shown in a stuttering pattern of
one interval, two intervals, one, two. The frame rate counter says 150 and it
does not look like 150.

Variable refresh rate inverts that: the panel waits for the frame instead of
the frame waiting for the panel. `home/joshr/displays/gamestation.nix` turns it
on for the 1440p display:

```nix
variableRefreshRate = "on-demand";
```

**`"on-demand"` is not a weaker `true`.** It leaves the output at its fixed
rate for the desktop and switches to VRR only while a window carrying niri's
`variable-refresh-rate` window rule is displayed on it. The only rule here that
sets it matches games:

```kdl
window-rule {
    match app-id=r#"^steam_app_"#
    match app-id=r#"^gamescope$"#
    variable-refresh-rate true
}
```

Both halves are required and each does nothing alone — the output declaration
without the window rule leaves VRR permanently off, and the window rule without
an on-demand output has nothing to switch.

Two reasons to want it that way round rather than holding VRR on. A desktop
under VRR is a display whose refresh rate tracks how much the shell happens to
be animating, and on some panels that shows up as brightness flicker in dark
areas — a real complaint, and one you would notice while reading rather than
while playing. And it means this setting cannot make anything worse when nobody
is playing anything, which is the property that makes it safe to leave on by
default.

mpv is deliberately not in that rule even though upstream uses it as the
example. Video at 24fps is a genuinely good case for VRR, and it is also the
case where a panel that flickers would do it during a dark scene in a film.
Adding `^mpv$` to the match list is the whole change if that turns out to be
wanted.

`niri msg outputs` says what actually happened — it reports whether the display
supports adaptive sync and whether VRR is enabled on it. A panel that does not
support it takes this setting and stays fixed; niri logs it and carries on,
so there is no failure mode here worse than "no change". `false` takes it out
entirely and `true` holds it on for the desktop as well.

The second display (DP-2, 1080p at 100Hz) is left fixed. Nothing is played on
it, and a second panel switching refresh rate underneath a bar and a browser is
the flicker case with none of the benefit.

### The shader cache, and the sawtooth

The driver caches compiled shaders under `~/.cache/nv`, and left alone it caps
that directory at 1 GB — 128 MB before driver 460 — and *wipes* it when it goes
over. Not evicts the oldest entries: wipes. There is no prune-to-N behaviour to
fall back on.

One Proton game's DXVK and VKD3D pipelines run to a few hundred megabytes, so
three or four of them is enough to cross that line. What the wipe feels like is
not a warning, it is the next hour of play recompiling pipelines mid-frame. And
because the cache then refills and the whole thing happens again, the symptom
is a sawtooth: fine for a while, hitching later, fine again, hitching again.
That is very close to what "it gets worse after some time" describes.

`modules/nixos/nvidia.nix` now sets, for the whole session:

```nix
environment.sessionVariables = {
  __GL_SHADER_DISK_CACHE = "1";
  __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
};
```

The cost is honest: the directory now grows without a bound. It grows in steps
rather than continuously — an entry appears only when something compiles a
shader it has never compiled before — and it is a cache, so `rm -rf
~/.cache/nv` is safe at any time and costs one slow first launch per game.
`du -sh ~/.cache/nv` says what it has actually become. The alternative,
`__GL_SHADER_DISK_CACHE_SIZE`, only moves the same cliff further out.

**It has to be set for the session, not per game.** The limit is enforced by
whichever process happens to be writing, so one GL program started without it —
a browser, a screen recorder, anything — trims the cache back under the limit
behind the game's back. Putting this in one game's launch options achieves
nothing, which is why it lives in the driver module.

### The card is also the model server

This applies to `gamestation-niri` and not to `gamestation`: it is the host
that imports `modules/nixos/ai.nix`, so ollama, Open WebUI and the OpenClaw
gateway all run on the same card the games do. See [Local AI](#local-ai) for
what those are.

ollama holds a model in video memory for five minutes after the last request
and reloads it on the next one. `deepseek-r1:14b` is around nine gigabytes;
`deepseek-coder-v2` is not much smaller. A game started while one of those is
resident begins with a card that is already part full, and the eviction
described above follows.

The part that makes this look like degradation over time rather than a slow
machine is that **none of it is driven from the chair**. Open WebUI in a
background tab can load a model. The OpenClaw gateway lingers — `linger = true`
in `hosts/gamestation-niri/configuration.nix`, which is what lets it be
messaged with nobody logged in — so it can take nine gigabytes of the card
mid-match in response to something arriving from somewhere else entirely.

So gamemode's start hook now takes the card back:

```
local.gaming.releaseGpuOnGameMode = true;   # the default
```

It reads `/api/ps` for whatever is resident and sends each model a
`keep_alive: 0`, which is ollama's documented "drop this now". No CLI, no
privileges, one loopback request per model. There is deliberately no matching
end hook: ollama loads on demand, so the next question brings the weights
straight back — this takes the card, it does not keep it.

**And it says so.** The "GameMode started" notification gains a line naming
each model that was holding the card and how much of it it had:

```
GameMode started
released deepseek-r1:14b (8.9 GiB)
```

That is the point of the notification rather than a decoration on it. The
whole reason this problem is hard to see is that nothing about it is driven
from the chair — the notification is what turns "the machine was mysteriously
slower that evening" into "an agent had nine gigabytes of the card and gamemode
took them back at 21:14". A model that refuses to unload is reported the same
way (`… would not unload`), which is worth more still: it means the game is
starting on a card that is genuinely still part full.

Nothing is added when there was nothing resident, so an ordinary launch looks
exactly as it did before. The notification is not held up waiting for the
answer either: it is sent immediately and *rewritten in place* once the release
finishes, using the id the notification daemon hands back. Two reasons for
that — a model server mid-generation can take a few seconds to answer, and
gamemoded kills a custom script that runs longer than ten seconds, so a release
that hangs must not be able to take the confirmation down with it.

It is inert on a host that has no model server, so `gamestation` is unaffected,
and it is a `local.gaming.*` option rather than a fact of the module because
"my game should be able to interrupt my agent" is a preference and not
obviously true for everyone.

Two things it does not do. It does not stop Open WebUI, whose torch/onnx
embedding path can take a CUDA context of its own — that needs root, and the
GPU-passthrough hook is the mechanism for that sort of thing
(`local.virtualisation.singleGpuPassthrough.stopServices`). And it does not
prevent a *new* load during the game; it only clears what was there when the
game started. If that turns out to be the recurring case, the blunt answer is
`local.ai.openclaw.linger = false`, and the bluntest is `local.ai.enable =
false` for as long as the machine is being played on.

### Split locks

A split lock is an atomic instruction whose operand straddles two cache lines.
The CPU cannot do that with a normal cache lock, so it locks the entire memory
bus for the duration and every other core stalls behind it. Linux detects them,
and by default it punishes the thread that did one: the thread is forced to
sleep, and the check is serialised behind a global semaphore so only one such
thread anywhere on the machine runs at a time. Upstream calls that the misery
mode, which is not a nickname anyone here invented.

That is the right default for a machine running other people's code and the
wrong one for a desk. Plenty of Windows games do split locks in a hot path, and
under Proton the penalty lands on the render thread — the game does not fail,
it hitches, in bursts, in a way that looks exactly like a GPU problem and is
not one. It was hit widely enough that Linux 6.2 added a sysctl specifically so
it could be turned off ([Phoronix's
write-up](https://www.phoronix.com/news/Linux-Splitlock-Hurts-Gaming)).
`modules/nixos/gaming.nix` turns it off:

```nix
boot.kernel.sysctl."kernel.split_lock_mitigate" = 0;
```

The detector stays on and still logs to the kernel ring buffer; what is
switched off is the sleeping. What is given up is protection against a local
program deliberately degrading the machine for everything else by doing split
locks on purpose, which is a real consideration on a shared server and not one
here. `local.gaming.splitLockMitigate = true;` restores the kernel default.

Checking it, and whether it was ever the problem:

```
sysctl kernel.split_lock_mitigate      # 0 = off, 1 = kernel default
dmesg | grep -i 'split lock'           # which programs actually do them
```

On a CPU with neither split-lock nor bus-lock detection the sysctl does not
exist, systemd-sysctl logs that it skipped it, and nothing else happens.

### Launch options

Steam's per-game launch options are not in this repository — nothing here can
set them — but three of the usual ones are worth knowing about, because two of
them cause exactly the symptom they are usually added to fix.

**`dxvk.trackPipelineLifetime = True` makes stutter worse, not better.** Its
default is `Auto`, which means *32-bit applications only*: DXVK frees pipeline
libraries aggressively there because 32-bit address space is scarce, and does
not elsewhere because the pipelines then have to be compiled again. Forcing
`True` on a 64-bit game opts it into that trade for no benefit, and the cost is
recompilation that accumulates over a session. Drop it.

**`DXVK_ASYNC=1` does nothing.** It was a setting of the old async fork.
Upstream DXVK ignores the variable; what replaced it is
`VK_EXT_graphics_pipeline_library`, which DXVK uses by default when the driver
offers it — and which the setting above switches off the benefit of. It is
harmless, it is just not doing what it looks like it is doing.

**`DXVK_HUD=compiler` is worth keeping while diagnosing.** It shows pipeline
compilation as it happens, which is how to confirm or rule out the
recompilation case in a few minutes of play rather than by inference.

**`PROTON_ENABLE_WAYLAND=1` is worth trying per game and not worth setting for
the session.** Proton 10 ships Wine's native Wayland driver, which takes
Xwayland out of the path entirely — no `xwayland-satellite`, no X11 protocol
between the game and the compositor, and none of the scaling and pointer
oddities that come with it. It is also not feature complete, and the things
that break when it is wrong are input and presentation, which are the two
things you would least like to have break. Per-game launch options are the
right granularity for that; a session-wide variable would silently apply it to
a library.

On the wrappers: `mangohud gamescope -- %command%` puts MangoHud on
*gamescope*, so the numbers on screen are the compositor's rather than the
game's. The order that measures the game is `gamescope … -- mangohud
%command%`. And nested gamescope is not free on this card — it composites
again, and on NVIDIA the `gamescope-wsi` layer adds a frame copy on top of
that. It buys resolution and refresh-rate control; if neither is wanted for a
given game, the fastest configuration is not to nest at all.

### The XWayland regression

Every Proton game here is an XWayland client, reaching the compositor through
`xwayland-satellite`. There was a stretch where that path collapsed on NixOS:
the driver package stopped installing the EGL external platform JSON files, so
NVIDIA's EGL had no Wayland or X11 platform to load, and XWayland clients fell
back to a route that ran at a fraction of the speed with tearing on top.
[nixpkgs#524342](https://github.com/NixOS/nixpkgs/issues/524342) and [the sway
thread on Discourse](https://discourse.nixos.org/t/nvidia-severe-performance-regression-in-xwayland-on-sway/77861)
are the two write-ups; the workaround in the thread was to point
`__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS` at an older driver's copies by hand.

**This is fixed at the nixpkgs this flake is locked to**, and no workaround is
carried here. The NixOS module now pulls `egl-wayland`, `egl-gbm`,
`egl-wayland2` and `egl-x11` into `hardware.graphics.extraPackages` and points
`/etc/egl/egl_external_platform.d` at `/run/opengl-driver`. It is listed in
`gaming-doctor` anyway, because it is the sort of thing that comes back with a
`nix flake update` and because an empty directory there is unambiguous:

```
ls /run/opengl-driver/share/egl/egl_external_platform.d/
```

Files there, good. Nothing there, that is the bug and the environment variable
from the thread is the stopgap until nixpkgs moves again.

### The driver

`modules/nixos/nvidia.nix` pins `nvidiaPackages.latest`, which on the current
lock resolves to **610.43.03** — `latest` is the higher of the production and
new-feature branches, and the new-feature branch is ahead. That is deliberate
and it should stay: newer titles regularly need a driver newer than production,
and dropping back to `production` (595.84) to chase a performance report is a
trade that costs games.

`open = true` is set, so this is the open kernel module, which also means GSP
firmware is in use and cannot be turned off — the `NVreg_EnableGpuFirmware=0`
advice that turns up in stutter threads does not apply to a configuration built
this way. `gaming-doctor` prints which module is loaded so there is no need to
guess.

### The kernel

The two desk hosts boot the **CachyOS kernel, BORE variant**, instead of the
one nixpkgs would pick. Everything else here — the laptop, both servers, the
stick — stays on the nixpkgs default. `modules/nixos/kernel.nix` is the module,
`hosts/gamestation/kernel-params.nix` is where it is switched on (that file is
imported by both desk hosts, so the two sessions cannot drift onto different
kernels), and `local.kernel.cachyos.*` in `modules/nixos/options.nix` is the
knob.

BORE — Burst-Oriented Response Enhancer — is a patch on top of the fair
scheduler rather than a replacement for it. It keeps a per-task record of how
bursty that task has been and biases the pick accordingly, so short bursty work
gets chosen over a long-running batch job holding the same nice value. On this
box that is the render thread, the compositor and the audio thread against a
Docker build, a `nix build` or an ollama answering a question. The rest of the
CachyOS patch set and their kconfig come with it.

**It raises a floor; it does not find a bug.** If the desk was faster last
month and is slower now, something changed, and the things that change here are
the driver, the shader cache and whatever else is holding video memory —
the four sections above, and `gaming-doctor` prints all of them in one go. Run
that first. A scheduler swap will not undo a regression it had nothing to do
with, and "I changed the kernel and it is still slow" is a much harder position
to debug from than "the doctor says nine gigabytes of model weights are on the
card".

#### Never compiling it

Building a CachyOS kernel on the desk is the better part of an hour, and the
whole arrangement is shaped around never doing it. The kernel arrives prebuilt
from the flake input's own binary cache. Four things have to hold for that, and
all four are already set up — this is the list to check against when a rebuild
unexpectedly starts compiling one.

**The cache has to be configured before the build is planned, not by it.**
`modules/nixos/kernel.nix` adds the substituter to `nix.settings`, but that
lands in `/etc/nix/nix.conf` only *after* a switch has completed, and the
nix-daemon planning that switch is still on the old configuration. What covers
the gap is the `nixConfig` block at the top of `flake.nix`: nix reads it off the
flake it has been asked to build, before any of the module system exists. It
asks once, per user:

```
do you want to allow configuration setting 'extra-substituters' to be set to
'https://attic.xuyh0120.win/lantian' (y/N)?
```

Say yes — the answer is remembered in `~/.local/share/nix/trusted-settings.json`
— or skip the question outright:

```bash
sudo nixos-rebuild switch --flake .#gamestation --accept-flake-config
```

Two conditions apply and both are already met here: a `nixConfig` is only
honoured for the flake being *built*, never for one of its inputs (which is why
the kernel flake's own copy of those lines does nothing for us and `flake.nix`
carries a duplicate), and the user running the build has to be in
`nix.settings.trusted-users`, since the daemon discards substituters offered by
anyone else. That is root, and `@wheel` via `modules/nixos/development.nix`.
Setting `accept-flake-config = true` system-wide would retire the prompt for
good; it is deliberately not set, because it would apply to every flake this
machine ever builds and the prompt is the trust decision.

**The kernel has to be the exact derivation the cache holds.** Hence
`overlays.pinned` and no `follows` on the input — see [What follows the
kernel](#what-follows-the-kernel). Our `nixpkgs.config` cannot reach it either;
the kernel is not built from our `pkgs` at all.

**The input has to name a kernel that has actually been built** — the `release`
branch, which only moves once the flake's Hydra has pushed what it names.

**The variant has to be one they build** — what the enum on
`local.kernel.cachyos.variant` is for.

Check rather than hope, before committing an hour to a switch:

```bash
# succeeds only if the kernel can be fetched: --max-jobs 0 forbids building
# anything locally, so a cache miss is an immediate error, not a long wait
nix build --max-jobs 0 --no-link \
  .#nixosConfigurations.gamestation.config.boot.kernelPackages.kernel

# the whole system: what would be fetched, and what would be built
nixos-rebuild dry-build --flake .#gamestation
```

Two things still compile locally and both are expected. The DDC/CI module on
`gamestation-niri` is out-of-tree — well under a minute. And the NVIDIA kernel
module is only prebuilt for the six variants the kernel flake assembles a whole
test system for (`bore`, `latest`, `lts` and their `-lto` twins), so a
`-x86_64-v3` or `-zen4` kernel arrives cached while its driver module is built
here: ten minutes, not an hour.

If a rebuild starts building a kernel anyway, the input has moved ahead of what
the cache holds — `git checkout flake.lock`, and try the update again in a day.

That cache is a real trust decision and `local.kernel.cachyos.binaryCache.enable`
is the way to decline it: the key authorises that cache to supply *any* store
path this machine asks for, not only kernels. Declining means compiling the
kernel locally on every update; there is no third option.

#### Checking it took, and getting back

```bash
uname -r                              # the CachyOS version string
sysctl kernel.sched_bore              # BORE's own knob — 1 when it is on
ls /proc/sys/kernel | grep sched      # if that name has moved, the rest are here
```

A kernel change is a reboot. `nixos-rebuild test` is no help — it activates a
system without a boot entry, and the running kernel is not something activation
can replace — so the way back is the previous generation in the boot menu,
which is why `local.boot.maxGenerations` matters more once this is on. From a
working session, `local.kernel.cachyos.enable = false` and a rebuild returns to
the nixpkgs kernel. A kernel the NVIDIA driver refuses to build against fails
at build time, before anything is activated, which is the good failure.

#### Variants

`local.kernel.cachyos.variant` picks which CachyOS build to boot; the default
is `bore`, the plain GCC one.

| | |
|---|---|
| `bore` | BORE, built with GCC. The default here and the conservative half of the pair — every out-of-tree module on these hosts builds against it the ordinary way. |
| `bore-lto` | the same kernel built with Clang and ThinLTO, which is what upstream CachyOS ships by default. Worth trying once the plain build has proven itself; out-of-tree modules follow the kernel's compiler automatically. |
| `bore-x86_64-v3`, `-v4`, `bore-zen4` | compiled for a newer instruction set than the x86-64 baseline. A small real win, and an unbootable machine on a CPU without those instructions — `lscpu \| grep -oE 'avx2\|avx512f'` before reaching for one. Each also has an `-lto` twin. |
| `latest`, `lts` | the CachyOS patch set without BORE, on mainline's newest and on the long-term branch. `lts` is the fallback when a brand-new kernel and the NVIDIA driver disagree. |

The flake has more variants than the option lists — `bmq`, `deckify`, `eevdf`,
`hardened`, `rc`, `rt-bore`, `server`, and an `x86_64-v2` line. They are left
out because not all of them are cached, and an uncached kernel is an hour of
compiling rather than a slow download. Adding one is a line in the enum in
`modules/nixos/options.nix`.

#### What follows the kernel

The input is pinned to the kernel flake's `release` branch and applied through
its `overlays.pinned`, which builds the kernel package sets from *that flake's*
nixpkgs revision — the one its CI built and cached them at. Using our nixpkgs
instead would change the derivation hash of every kernel in the set, which is
the same thing as having no cache. It is also why the input deliberately does
not `follows` our nixpkgs, unlike every other input in `flake.nix`; the second
nixpkgs in `flake.lock` is what not compiling a kernel costs.

Anything reached through `config.boot.kernelPackages` comes out of that pinned
set too. In practice that is two things: the NVIDIA driver, since
`modules/nixos/nvidia.nix` asks for `kernelPackages.nvidiaPackages.latest` —
that exact combination, with `open = true`, is one the kernel flake builds in
its own CI, so it is a download rather than a build — and the DDC/CI module on
`gamestation-niri`, which is out-of-tree, small, and compiles locally in well
under a minute. Nothing else here reaches into `boot.kernelPackages`, and no
host here uses ZFS, which is the other thing that would need pointing at the
CachyOS build.

`nix flake update nix-cachyos-kernel` is what moves the kernel; like every
other input, commit the resulting `flake.lock` alongside whatever prompted it,
so a kernel that works is a kernel you can get back to.

### Would Hyprland be better?

The honest answer for this machine is no, and it is worth writing down because
the question comes back every time something goes wrong under niri.

**For the controller, it changes nothing.** The second-cursor problem is Steam
talking X11 in a session with no X server, and Hyprland is a Wayland compositor
with the same Xwayland underneath. The bug is filed against Steam by people
running Hyprland
([steam-for-linux#13185](https://github.com/ValveSoftware/steam-for-linux/issues/13185)),
the fix there is the same extest preload this configuration now carries, and
Plasma Wayland — which is what `gamestation` runs — has it too. Migrating
would move the problem, not solve it.

**For stutter, the two are close enough that the difference is not the reason
to move.** Both do direct scanout, so a fullscreen game's buffer goes to the
display controller without the compositor blending it. Both do VRR, and niri's
on-demand form — [above](#vrr-and-the-judder-that-isnt-the-game) — is the more
precise of the two. Both leave the real work to gamemode, the driver and the
kernel, which is where every section above this one lives.

There is one genuine gap, and it is about latency rather than stutter: niri
cannot tear yet. Hyprland's `allow_tearing` lets a game present a frame the
instant it is ready instead of at the next refresh, which shaves part of a
frame off input latency at the cost of a visible seam. niri's
[issue #844](https://github.com/YaLTeR/niri/issues/844) tracks it, and the
implementation is waiting on Smithay rather than on a decision; the plan is for
it to become a window rule, the same shape as on-demand VRR. If sub-frame input
latency in competitive games is the thing that matters most, that is a real
argument, and it is the only one on the list. On a VRR panel it is also
substantially the smaller half of the problem.

**Against that, what a migration actually costs here.** `home/joshr/niri/` is
around twelve thousand lines. Noctalia would survive — Hyprland is one of its
first-class compositor integrations, alongside niri — and its palette templates
render the same files either way, so the theming that reaches Dolphin, kitty,
VS Code, the boot menu and the greeter would carry over mostly untouched. What
would not survive is everything written against niri itself: `niri.nix` (900
lines generating KDL — every keybind, every window rule, the scrolling layout
the workspace model assumes), the display configuration, the screenshot path
that uses niri's own actions, and the GameMode mechanism, which works by
dropping a `gamemode.kdl` into place and relying on niri merging duplicate
config sections property by property with the last one winning. Hyprland has
`source =` and `hyprctl keyword`, so an equivalent is possible, but it is a
different design and not a translation.

So: fix Steam Input where the bug actually is, take the VRR win, and revisit
this if tearing turns out to be the thing that is missing. Nothing in this
repository makes that decision hard to change later — the niri hosts are
separate `nixosConfigurations` precisely so that a second session can exist
beside a working one rather than replacing it.

## Single GPU passthrough

Give the desk's graphics card to a virtual machine for as long as that machine
is running, and take it back when it shuts down. `gamestation-niri` has it on;
`modules/nixos/gpu-passthrough.nix` is the whole of it.

The usual sort of VFIO passthrough is a two-card arrangement: the host uses
one, the guest gets the other, and the guest's card is bound to `vfio-pci` in
the initrd before anything else can claim it. There is one card in this box.
The host is *using* it — greeter, compositor, framebuffer console — so before a
guest can have it, every one of those has to let go, and afterwards every one
of them has to come back. libvirt has no idea how to do that, which is why
there is a hook.

### What it costs

**Starting one of these guests logs you out.** The display manager is stopped,
the session goes with it, the screen is dark for a few seconds and then the
guest is driving the monitor. Shutting the guest down brings the greeter back
and you log in again.

That is not a rough edge to be filed off later. One card cannot be in two
operating systems at once, and every implementation of this — scripts, hooks,
someone typing `systemctl stop display-manager` by hand — ends at the same
place. What the module buys is that it happens in the right order, that it is
undone in the right order, and that a failure half way through puts the desktop
back rather than leaving a black screen.

Anything you want to keep running belongs on the *host's* other tty or on
another machine. An SSH session survives the whole thing; `base.nix` has sshd
on with password auth off, so put a key in place first if there isn't one.

### Turning it on

```nix
# hosts/gamestation-niri/configuration.nix
    ../../modules/nixos/virtualization.nix        # libvirtd, which the hook needs

  local.virtualisation.singleGpuPassthrough = {
    enable = true;
    vms = [ "win11" ];    # `virsh list --all` prints these names
  };
```

The module rides along with `virtualization.nix` rather than being a third
import to remember — it is a libvirt hook and nothing else, so it has no
meaning without libvirtd and costs nothing until `enable` is set.

`vms` is the list of libvirt domains allowed to take the card. Everything not
named there starts and stops as an ordinary VM, and the hook returns
immediately. It is a list rather than "any domain with a `<hostdev>`" because
being wrong is asymmetric: a guest treated as a passthrough guest when it isn't
takes the desktop down every time it boots, while a passthrough guest that
isn't listed merely comes up without a display, with the session still there to
fix it in. A name that matches no domain is inert, so renaming a VM makes
passthrough *stop* rather than start happening to something else.

An empty list is a warning at rebuild time, not an error. So is a kernel
command line with neither `amd_iommu=on` nor `intel_iommu=on` — VFIO needs an
IOMMU, and on this box `hosts/gamestation/kernel-params.nix` has had
`amd_iommu=on iommu=pt` for exactly this reason since before there was anything
to use it. It stays a warning because a recent kernel may have the IOMMU on
already, because the firmware does.

The other three options are for when the defaults don't fit:

| | |
|---|---|
| `pciDevices` | The card's PCI functions, `0000:0b:00.0` style. Empty — the default — reads them out of the guest's own `<hostdev>` entries on stdin, so the card is written down once, in the VM, rather than twice. Set it when the guest's device list mixes the GPU with something the hook should leave alone. |
| `hostDriverModules` | What to unload before the guest starts, most dependent module first; they go back in the reverse order. Defaults to the NVIDIA stack when `services.xserver.videoDrivers` says `nvidia`, otherwise `amdgpu`. |
| `stopServices` | Extra units holding the card — a local model runner, a transcoder, a container started with the GPU passed in. `display-manager.service` is always handled and doesn't belong here. Only units that were running get stopped, and only those get started again. |

### The guest itself

Nothing here creates a VM. Make it in virt-manager as usual, then **Add
Hardware → PCI Host Device** for every function of the card — the video one and
its HDMI/DP audio at least, and everything else in the same IOMMU group,
because a group travels together:

```bash
lspci -nnk                                   # addresses, and who has them now
find /sys/kernel/iommu_groups -type l        # what shares a group with what
```

virt-manager writes those as `<hostdev managed='yes'>`, which means libvirt
does the vfio-pci binding itself. That works: by the time libvirt gets there
the hook has already taken the host driver off the card. The hook binds them
too when it can name them, which is belt and braces rather than a requirement.

`virtualization.nix` already turns on the two things a Windows guest asks for
beyond this — OVMF for UEFI and swtpm for the TPM 2.0 device.

### What happens when the guest starts

libvirt runs every executable in `/var/lib/libvirt/hooks/qemu.d/` around a
domain's lifecycle, with the domain name, the operation and the domain XML on
stdin. The hook acts on two of them and ignores the rest. `prepare/begin` is
before libvirt has allocated anything for the guest — the last moment the host
can be told to drop the card cleanly — and in order it:

1. Stops `display-manager.service`, and anything in `stopServices`.
2. Unbinds the framebuffer console (`/sys/class/vtconsole/vtcon*`), which holds
   the card without being a service at all.
3. Unbinds whatever drew the boot splash — `efi-framebuffer` on the old path,
   `simple-framebuffer` on anything recent enough to be using simpledrm.
4. Unloads the GPU driver, retrying while it is busy. `systemctl stop` returns
   when the *unit* is gone, but a compositor's last processes can hold a
   `/dev/nvidia*` open for a moment after that, and the module won't come out
   while they do.
5. Loads `vfio-pci` and binds the card's functions to it through
   `driver_override`, so the re-probe can only land on vfio-pci and the host
   driver can't race for the card it has just let go of.

If any of that fails, the hook puts the host back and *then* reports the
failure. libvirt turns a non-zero hook into a refused domain start, which is
the right outcome once the desktop is back: a VM that won't start is a problem
you can look at, and a machine with no display manager and no GPU driver is
not.

### And when it stops

`release/end` fires after the domain is fully torn down and libvirt has already
reattached whatever it detached itself, so the card is genuinely free. The hook
unbinds it from vfio-pci, clears the driver override, unloads the vfio modules,
loads the GPU driver back in the reverse of the order it came out, rebinds the
console, and starts the display manager last — the greeter wants a card that is
already back.

It restores exactly what the other half stopped and unbound, which it wrote
down in `/run/single-gpu-passthrough.state`. That is deliberate: a unit that
was already off before the guest started stays off. `/run` is tmpfs, so a
reboot with a guest running leaves no stale file to act on, and if the file is
missing the hook falls back to restoring the console and the display manager —
the things whose absence leaves no way back in.

### When it goes wrong

```bash
journalctl -t single-gpu-passthrough -f    # what the hook did, step by step
journalctl -u libvirtd -f                  # what libvirt made of it
```

The hook is also on `PATH` as `single-gpu-passthrough`, taking the same
arguments libvirt gives it. That is the way out when a guest has died in a way
that never produced a `release/end` and the machine is sitting there with no
desktop — from a TTY, or over SSH from another machine:

```bash
sudo single-gpu-passthrough <domain> release end < /dev/null
```

Ctrl+Alt+F2 gets a TTY right up until step 2 above; after that, SSH is the way
in.

Two failures worth naming:

- **"could not unload the host GPU driver"**, and the desktop comes straight
  back. Something still has the card open. `sudo fuser -v /dev/nvidia*` or
  `lsof /dev/dri/*` names it; if it's a service, put it in `stopServices`.
- **The guest starts but has no display**, and the host is dark. The card went
  to vfio-pci but the guest didn't get it, or didn't drive it. Check that every
  function of the card — and everything else in its IOMMU group — is attached
  to the domain, then look at the guest's own console over SPICE.

A rebuild alone doesn't install a changed hook. The libvirtd module symlinks
the hooks into `/var/lib/libvirt/hooks/qemu.d/` from its `preStart`, so it
takes a `sudo systemctl restart libvirtd` (or a reboot) before the new one is
the one that runs.

## Local AI

Models that run on this machine's own card. `modules/nixos/ai.nix`, imported
by `gamestation-niri` and nowhere else — the laptop has no discrete GPU and
the server has neither a GPU nor anyone sitting at it.

Three programs, three jobs:

| | What it is | Where |
|---|---|---|
| **ollama** | the model server: holds the weights, answers HTTP | `127.0.0.1:11434` |
| **Open WebUI** | a browser chat window, pointed at ollama | `127.0.0.1:8080` |
| **OpenClaw** | an agent — sessions, tools, chat channels — with a control UI | `127.0.0.1:18789` |

All three are on loopback and **nothing here opens a firewall port**. Reaching
any of them from a phone is a `tailscale serve` decision to make on purpose;
`services.tailscale` is already up from `base.nix`, so the tailnet is there
when you want it, and none of these is on it until you say so.

### Turning it on

```nix
# hosts/gamestation-niri/configuration.nix
local.ai = {
  enable = true;

  ollama.models = [
    "qwen3"
    "nomic-embed-text"
  ];

  openclaw = {
    enable = true;
    model = "ollama/qwen3";
    linger = false;
  };
};
```

`local.ai.enable` brings up the model server and the chat window. It does
*not* bring up the agent — `local.ai.openclaw.enable` is separate, and the
reason is [further down](#openclaw-and-what-it-costs). Every option is in
`modules/nixos/options.nix` with its reasoning attached.

### The first rebuild is a long one

`local.ai.ollama.acceleration` defaults to `"auto"`, which reads
`services.xserver.videoDrivers`: nvidia here, so `ollama-cuda`.

**cache.nixos.org does not have that build.** Hydra doesn't build against
unfree CUDA, so the first rebuild after enabling this compiles ollama on the
machine. Tens of minutes, once, and again after a nixpkgs bump moves it.

That is the cost of the right default rather than a fault in it — on this
card, "cuda" versus "cpu" is roughly the difference between a conversation and
a progress bar. Two ways round it if the wait isn't acceptable today:

```nix
local.ai.ollama.acceleration = "cpu";   # builds from cache, small models are usable
```

or point the daemon at the cuda-maintainers cachix and let someone else have
done the build.

### Models

`local.ai.ollama.models` is a **download** list, not a build input. Names come
from [ollama.com/library](https://ollama.com/library); a bare name means that
model's default tag, `name:tag` picks a size.

```
ollama list                  # what's actually on disk
ollama pull deepseek-r1      # try one without editing the config
ollama run qwen3             # a terminal chat, straight against the server
```

`ollama-model-loader.service` fetches them in the background once the server
is up, so a rebuild never waits on gigabytes, and a machine that was offline
at the time retries with a backoff instead of failing activation. The weights
live under `/var/lib/ollama` and never enter the store — which also means the
weekly `nix-collect-garbage` has no opinion about them, and neither does a
rollback.

Pulling by hand and writing down the keepers afterwards is the intended
rhythm. `local.ai.ollama.pruneUndeclaredModels = true` reverses that and makes
the list authoritative, deleting anything not named in it.

**If the agent is going to use a model, it needs tool calling and at least a
16K context window.** OpenClaw checks for both and quietly won't offer a model
that lacks them, which reads as "the agent is broken" rather than "that model
can only chat". `qwen3` is in the list above for exactly this reason; several
otherwise excellent small models advertise no tools at all.
`nomic-embed-text` is a different kind of thing — it's what Open WebUI uses to
index documents you upload, not something you talk to.

### Open WebUI

`http://127.0.0.1:8080`. The first visit asks you to create an account; it is
local to this machine, lives in a SQLite file under `/var/lib/open-webui`, and
is what stops a stray browser tab talking to the models. If that ceremony
isn't wanted on a single-user desktop:

```nix
local.ai.webui.extraEnvironment.WEBUI_AUTH = "False";
```

The module turns telemetry off, points the UI at the local ollama, and sets
`ENABLE_OPENAI_API = "False"` — with no key on this box, leaving that on costs
a connection attempt to `api.openai.com` at every start and a spinner on the
model list. `extraEnvironment` merges over all of that and wins, so adding a
key later is two lines. Secrets don't go there —
`services.open-webui.environmentFile` takes a path for those.

### OpenClaw, and what it costs

OpenClaw is not a chat window. It's a gateway: sessions, tools, chat channels
(WhatsApp, Telegram, Discord and a dozen more), with a control UI on
`http://127.0.0.1:18789`.

That is also the problem, and it is worth stating plainly rather than in a
footnote. **nixpkgs ships this package with a `knownVulnerabilities` entry**,
so a plain rebuild refuses to install it:

```
error: Refusing to evaluate package 'openclaw-2026.6.33' … because it is marked as insecure
  - Project uses LLMs to parse untrusted content, making it vulnerable to
    prompt injection, while having full access to system by default.
```

That is accurate. An agent acts on text that arrived from somewhere else — a
message, a fetched web page, a document — and there is no reliable way to stop
instructions inside that text from being followed. `ai.nix` disarms the check
for this one package by name:

```nix
nixpkgs.config.allowInsecurePredicate = pkg: lib.getName pkg == "openclaw";
```

By name rather than by nixpkgs' suggested `permittedInsecurePackages = [
"openclaw-2026.6.33" ]`, so a `nix flake update` doesn't break the next
rebuild with an error about a version number nobody chose. It does replace
nixpkgs' default predicate, which is the one that reads
`permittedInsecurePackages` — nothing else here uses that list, but if
something ever does, that line is where it has to be taught about it.

So `local.ai.openclaw.enable` is deliberately not wired to `local.ai.enable`.
Turning it on is where the decision gets made, and what limits the blast
radius afterwards is the account boundary and nothing else:

- It runs as a **systemd user service** for one account —
  `local.ai.openclaw.user`, defaulting to `local.desktop.primaryUser`.
- It is **not sandboxed**, on purpose. `DynamicUser`, `ProtectHome` and the
  rest would each remove a capability the program exists to have. Assume
  anything that user can do, this can be talked into doing. On this machine
  that user isn't root.
- NixOS has one `systemd --user` generation for the whole box, so the unit is
  defined for every account and `ConditionUser=` selects the right one.
  Everyone else's user manager skips it with a journal line and no failure.
- `local.ai.openclaw.linger = false` means it's up while that account has a
  session and gone otherwise, which is the honest shape for something on a
  desk. Turn it on for a machine you message while nobody's sitting at it —
  and notice that this means an agent with a shell running unattended.

#### First start

Two things have to exist before the gateway will run, and neither can come out
of the Nix store, so the unit's `ExecStart` is a small wrapper that makes them:

1. **A token.** The gateway requires authentication. One is generated on first
   start into `~/.openclaw/gateway.env`, mode 600, and read back on every
   start after that. Nothing secret ends up in a world-readable store path.
2. **A config file.** Seeded at `~/.openclaw/openclaw.json` if it's missing —
   the token reference and, if `local.ai.openclaw.model` is set, the primary
   model. That's all: OpenClaw validates its config strictly, and an unknown
   key doesn't warn, it stops the gateway booting.

**The seed is written once and never again**, because OpenClaw owns that file
afterwards — its control UI writes to it, `openclaw config set` writes to it,
and the gateway hot-reloads it while running. Upstream explicitly says not to
make it a symlink, which rules out the usual Nix approach. The practical
consequence:

> Changing `local.ai.openclaw.model` after the machine has started once does
> **nothing**. Use `openclaw models set ollama/<model>`.

The port is the exception — it's passed on the command line, so
`local.ai.openclaw.port` stays authoritative and can't drift.

`~/.openclaw/gateway.env` is also the place to put provider credentials by
hand — `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` — for anything that isn't the
local server. It's sourced, so comments and bare `NAME=value` both work.
`local.ai.openclaw.environmentFile` is the other half of that: a path to a
file something *else* manages, outside the home directory. A missing file
there isn't an error, so it can be named before it exists.

#### Talking to the local models

The unit sets `OLLAMA_API_KEY=ollama-local`, which is upstream's marker for
"this host needs no real credential" and what opts the bundled Ollama provider
in. There is no account behind that string and it is not a secret.

```
openclaw models list          # what it can see
openclaw models set ollama/qwen3
openclaw onboard              # the interactive setup, if you'd rather
openclaw doctor               # what it thinks is wrong
```

Discovery only looks at the default `11434`. Moving `local.ai.ollama.port`
with the agent enabled makes a rebuild warn and hands you the two `openclaw
config set` lines that teach it the new address.

### Sharing the card with a VM

`gamestation-niri` also runs [single GPU passthrough](#single-gpu-passthrough),
and a loaded model pins the NVIDIA driver in memory. The hook can't unload a
driver something else is holding, so its five attempts fail and the guest
refuses to start.

`ai.nix` adds `ollama.service` and `open-webui.service` to that hook's
`stopServices` list itself, which is the case that option's `example` was
written for. Nothing to configure — start the VM, the model server stops with
the display manager, and both come back when the guest does. The two modules
are otherwise independent; either works without the other.

### When it goes wrong

```bash
systemctl status ollama open-webui        # the two system services
journalctl -u ollama -f

systemctl --user status openclaw          # the agent, as its own user
journalctl --user -u openclaw -f
openclaw doctor

curl http://127.0.0.1:11434/api/tags      # is the model server answering?
nvidia-smi                                # is anything on the card?
```

A few failures that look like something else:

- **The gateway won't start and only `openclaw doctor` works.** Config
  validation failed. OpenClaw refuses to boot on an unknown key or a bad
  value, and says which one.
- **`systemctl --user status openclaw` says the condition failed.** That's a
  different account than `local.ai.openclaw.user`. Working as intended — the
  unit exists for every user manager on the machine.
- **The agent sees no models.** Either ollama has none yet (`ollama list`), or
  the ones it has don't do tool calling, or the port was moved. The rebuild
  warns about the last of those.
- **A rebuild refuses to evaluate `openclaw`.** The predicate above is in the
  `local.ai.openclaw.enable` branch, so it only applies when the agent is on.
  Installing the package some other way needs its own answer.

## Scheduled jobs

`server` runs its recurring work as **actual cronjobs**. The section is in
`hosts/server/configuration.nix`, and the option behind it is
`modules/nixos/cron.nix`:

```nix
local.cron = {
  enable = true;

  jobs = [
    {
      name = "nix-gc";
      description = "Trim the store beyond what base.nix's weekly GC keeps";
      schedule = "30 3 * * 0";
      command = "nix-collect-garbage --delete-older-than 30d";
    }
  ];
};
```

Each entry becomes one line of the system crontab plus a comment, so
`/etc/crontab` stays readable. `user` defaults to `root`. `schedule` is
standard five-field crontab syntax, and the `@daily` / `@weekly` / `@reboot`
shorthands work too. Schedules are in the system timezone (`time.timeZone`),
not UTC.

Three things worth knowing:

- **Bare command names work here**, which is the opposite of the usual cron
  advice. nixpkgs' cron module writes `SHELL=…/bash` and
  `PATH=<system.path>/bin:<system.path>/sbin` above our jobs, so anything in
  `environment.systemPackages` resolves by name. `local.cron.path` exists for
  tools that *aren't* installed system-wide, and it extends that PATH rather
  than replacing it — replacing it is the easy mistake, since a second `PATH=`
  line in a crontab wins over the first.
- **`%` is a crontab metacharacter**, meaning "newline" — everything after the
  first one is fed to the job on stdin. `date +%F` has to be written
  `date +\%F`.
- **A job missed while the machine was off never runs.** Cron has no catch-up.

### When not to use it

Cron was chosen because crontab syntax is familiar and these jobs are the
boring kind. It is genuinely the weaker tool: output goes to a mail spool that
no MTA is reading, so a job that's been failing for a month is invisible;
`systemctl list-timers` has no equivalent; and there's the missed-job problem
above.

So if a job *matters* — skipping it silently is a problem, or you'll want to
know why it failed three days ago — write it as a systemd service plus a timer
with `Persistent = true` directly in the host config. Nothing stops the two
coexisting. For output you actually want to read from a cron job, redirect it
yourself: `... 2>&1 | systemd-cat -t backup`.

## The accounts

Three interactive ones and `root`, on the four desktop hosts. The three are
declared in `modules/nixos/users.nix` and each is given a home-manager profile
in `flake.nix`:

| Account | Description | Profile | `wheel` |
|---|---|---|---|
| `joshr` | Josh Randall | `home/joshr/<host>.nix` | yes |
| `amandak` | Amanda Kast | `home/amandak/<host>.nix` → joshr's | no |
| `sabom` | Michael Sabo | `home/sabom/<host>.nix` → joshr's | no |
| `root` | — | `home/root/home.nix` | — |

`home/raiden/` and `home/delta/` are the same shape and are wired to nothing:
both the `users.users.<name>` block in `users.nix` and the `<name> = …` lines
in `flake.nix` are commented out. Uncommenting both is the whole of bringing
one back.

The headless and portable hosts have their own, shorter account lists —
`modules/nixos/server-users.nix` and `modules/nixos/usb-users.nix`, both
`joshr` and nobody else. Those are separate files rather than an option
because a list of accounts merges by union: a host that imported `users.nix`
could add people but could never take one away.

**Both lists have to agree.** `users.nix` decides who can log in; the
`homeModules` attrset in `flake.nix` decides what they log in *to*, and
nothing checks one against the other. An account declared in the first and
missing from the second evaluates cleanly, builds cleanly, and appears at the
greeter — and the session it opens has no home-manager profile behind it at
all: under niri that is a bare compositor with no bar, no keybinds and no
shell, because nothing ever wrote that account a `~/.config`. `sabom` was in
exactly that state on `gamestation`, `gamestation-niri` and `laptop` until the
three missing lines were added.

All three get fish, `networkmanager`, `video` and `input`, plus
`docker` and `libvirtd` on the hosts whose imports enable those daemons. Only
`joshr` is in `wheel`, so `sudo nixos-rebuild` is joshr's; add `"wheel"` to
`extraGroups` in `users.nix` to change that. All are created with
`initialPassword = "changeme"` — which applies at first creation only, so
`passwd` after the first login is the whole of the fix.

`mkHost` in `flake.nix` takes its users as an attrset:

```nix
gamestation-niri = mkHost {
  hostModule = ./hosts/gamestation-niri/configuration.nix;
  homeModules = {
    joshr = ./home/joshr/gamestation-niri.nix;
    amandak = ./home/amandak/gamestation-niri.nix;
    sabom = ./home/sabom/gamestation-niri.nix;
  };
};
```

`root` is added to every host by `mkHost` itself rather than repeated in each
call — it gets the same shell everywhere and nothing graphical follows it in,
so there is nothing per-host to say about it.

### What "primary user" actually decides

`joshr` being the primary user is one option, `local.desktop.primaryUser`, and
it is about the surfaces that exist outside any session: the SDDM/plasmalogin
greeter takes its theme and wallpaper from that account's
`~/.local/state/niri-theme` and `~/.config`, the limine boot menu takes only its
colours from there, and the OpenRGB after-resume service runs as it.

Each of those is a singleton — one login screen, one boot menu, one set of
lights — so they follow one named account rather than whoever logged in last.
Everything else is per-account and per-session: `amandak` switching themes
restyles `amandak`'s niri, kitty, Noctalia, Firefox and Dolphin, and leaves the
greeter and the boot menu alone.

That holds under Noctalia specifically, which is worth saying because Noctalia
is what actually *writes* the machine-wide palette now (see
[Theme sync under noctalia](#theme-sync-under-noctalia)). The shell renders
`noctalia-resolved` into the home directory of whichever account is running
it, and the two syncs that carry a palette out of the session —
`sddm-theme-sync` in `modules/nixos/niri.nix` and the limine one in
`modules/nixos/boot.nix` — name
`/home/${config.local.desktop.primaryUser}/.local/state/niri-theme` outright,
both in the file they read and in the `systemd.paths` unit that watches for a
change. A non-primary account picking a wallpaper-derived scheme therefore
repaints its own session, its own kitty, its own Dolphin, and nothing on the
login screen or in the boot menu.

### One profile, several accounts

`home/amandak/` and `home/sabom/` contain no configuration. Each entrypoint
imports joshr's for the same host and `./home.nix`, which sets one thing:

```nix
# home/amandak/gamestation-niri.nix
{
  imports = [
    ./home.nix
    ../joshr/gamestation-niri.nix
  ];
}
```

So anything added to joshr's profile arrives in the others' on the next
rebuild, which is the point of importing rather than copying. **The desktop
shell is one of those things**: `local.niri.shell = "noctalia"` is set in
joshr's two `*-niri.nix` entrypoints, so importing one is what puts an account
on Noctalia — the same bar, launcher, notifications, OSD, lock screen, idle
timers and wallpaper handling, from the same generated `config.toml`. There is
no per-account switch to throw, and no account on a niri host is on the waybar
stack while another is on Noctalia; setting `local.niri.shell` in one of the
`home/<name>/` files is how one would be, and nothing does that.

That works because nothing under `home/joshr/` writes the name `joshr` into a
path. `home.username` in `home/joshr/home.nix` (and `home/joshr/server.nix`)
is a `lib.mkDefault`, each account's own `home.username` outranks it at
ordinary priority, and everything downstream is derived from it:

| Derived from the account name | Where |
|---|---|
| `~` and everything under it | `home.homeDirectory` |
| `~/.mozilla/firefox/<name>` | `home/joshr/firefox.nix`, read back by `niri/firefox.nix` |
| `com.<name>.NiriSystem` | `home/joshr/obs.nix` |

Both resolve to exactly what they were for `joshr`, so nothing of joshr's
moved when the other accounts were added — no Firefox profile to migrate, no
D-Bus name to rename. The Noctalia state paths behave the same way: the
config, the palettes, the plugin, `~/.local/state/niri-theme` and the live
theme directory the Qt and VS Code symlinks follow are all built from
`config.home.homeDirectory`, so two sessions running at once on one machine
never write to each other's.

The desktop entries in `home/joshr/desktop-apps.nix` used to be on that list
too, as `<name>-gwenview.desktop` and friends. They aren't any more — they now
carry KDE's own ids, and don't need to be told apart per account because each
one is written into that account's own `~/.local/share/applications`. See
[the media handlers](#the-media-handlers-and-why-they-replace-kdes-own-entries).

One thing the other accounts do *not* get their own of: the git identity —
joshr's name and address, from `home/common/git.nix` on the desktop hosts and
from `home/joshr/server.nix` on the server. Their commits carry it until it's
overridden, and each `home/<name>/home.nix` has the `lib.mkForce` to do that
sitting commented out.

### Adding another account

1. An account in `modules/nixos/users.nix`. Copy the `amandak` block; the
   `sessionGroups` list above it is the shared membership.
2. A `home/<name>/` directory shaped like `home/amandak/` — a `home.nix` with
   the username, and one entrypoint per host importing joshr's.
3. The name and its entrypoint in each host's `homeModules` in `flake.nix`.

Step 3 is the one that is easy to half-do, and it fails quietly: the account
exists and can log in without it, to a session with nothing in it. Add the
line for **every** host whose configuration imports the users module that
declares the account — which for `users.nix` is all four desktop hosts, both
the Plasma pair and the niri pair.

Nothing else. In particular, don't change `local.desktop.primaryUser` unless
you mean to hand the login screen and boot menu to the new account.

## The root account

`root` uses fish as its login shell and gets the same starship prompt and eza
aliases as `joshr`, via `home/common/shell.nix`. It gets nothing else — no
Plasma, no Kitty config, no GUI packages.

That split isn't invented here; it's what the dotfiles already do. Their
`.chezmoiignore` has a `root` / `jrh` / `jrp` branch that strips the Plasma
configs, Code, spicetify, mpv, vlc, wallpapers, icons and colour schemes, and
`config.fish.tmpl` branches on username to give root an **empty**
`fish_greeting` instead of the fastfetch one. Both behaviours are reproduced
here — the greeting via `local.shell.fastfetchGreeting`, which also decides
whether fastfetch and `~/.smallfetch.jsonc` get installed at all.

Root is managed by home-manager rather than chezmoi, same as joshr. Pointing
chezmoi at the dotfiles repo for root would mean two mechanisms writing to
the same home directories, with chezmoi's state living outside the Nix store
and drifting on its own.

## Where things came from

Your `dotfiles` repo is a chezmoi repo, so it isn't "home-manager-native" —
there's no 1:1 mechanical conversion. What I did instead:

- **Settings** (kdeglobals, plasmarc, kwinrc, kglobalshortcutsrc, the
  appletsrc panel layout, fish config, VS Code settings, kitty config,
  starship.toml) were read from the repo and translated into
  `programs.plasma`/`programs.fish`/`programs.kitty`/`programs.vscode` options
  in `home/joshr/`. Anything that was pure session noise (window-tiling
  geometry caches, per-instance applet UUIDs, dialog-size memory, activity
  UUIDs) was dropped rather than transcribed.
- **Large assets** (fonts, the `Fluent-round-Pursuit` Plasma theme and other
  vendored desktop themes, the two `look-and-feel` packages, the
  `Bibata-Modern-Ice` cursor theme, your custom `j-accent`/`j-contrast` SVGs,
  and your wallpapers) are pulled straight from the `dotfiles` repo via the
  `dotfiles` flake input (see `flake.nix`) instead of being hand-copied. This
  means `nix flake update dotfiles` will pick up changes you push to that repo.
- **VS Code extensions** aren't declaratively pinned (most aren't packaged in
  nixpkgs), so `vscode.nix` reinstalls them from the marketplace on every
  `home-manager switch`, mirroring what `scripts/install-vscode-extensions.sh`
  did in the original repo.
- Things I could find no evidence you'd actually customized (e.g. almost all
  of `kglobalshortcutsrc`, which was stock KDE defaults) were left alone
  rather than guessed at.
- **Per-machine profiles have no direct equivalent here.** The dotfiles repo
  uses chezmoi templates (`.chezmoiignore`, `config.fish.tmpl`) to branch on
  OS, username, and hostname — notably a shell-and-starship-only profile for
  root and for `jrh`/`jrp` hostnames. In Nix that job belongs to separate
  `nixosConfigurations.<host>` entries in `flake.nix` rather than to
  in-file conditionals, so nothing was ported for it. If you want a minimal
  laptop host that skips Plasma/gaming, that's a new host entry importing a
  subset of `modules/nixos/`.

## Before you build this

1. **Hardware config.** `hosts/gamestation/hardware-configuration.nix` is a
   placeholder — it has invented disk labels and a guessed CPU vendor, and
   will not boot your machine. See
   [Regenerating hardware-configuration.nix](#regenerating-hardware-configurationnix)
   below.
2. **NVIDIA generation.** `modules/nixos/nvidia.nix` sets `open = true`, the
   open kernel module, which needs a Turing (RTX 20xx) card or newer. On
   anything older, flip it to `false` for the proprietary module.
3. **Multi-monitor panel layout.** `home/joshr/plasma.nix` assumes the same
   monitor arrangement as the original machine: a dock and a status bar on
   `screen = 0`, and one bar on `screen = 1`. (Screen 2 has a desktop but no
   panel, matching the upstream dotfiles.) If this is a different machine,
   adjust or drop the `screen` numbers.
4. **Git identity.** `home/joshr/home.nix` sets
   `programs.git.userEmail = "joshrandall8478@gmail.com"` — change it if
   that's not the identity you want for commits.

## Regenerating hardware-configuration.nix

`nixos-generate-config` scans the running machine — disks, filesystem UUIDs,
kernel modules needed at boot, CPU vendor — and writes a Nix module
describing it. It is machine-specific and must be regenerated per host.

**On a machine that already runs NixOS:**

```bash
sudo nixos-generate-config --show-hardware-config \
  > hosts/gamestation/hardware-configuration.nix
```

`--show-hardware-config` prints to stdout instead of writing into
`/etc/nixos`, which is what you want when the file lives in a repo.

**During a fresh install**, it's generated as part of the install flow below
(step 4), after the target disk is mounted at `/mnt`.

Either way, open the result and sanity-check it — in particular
`boot.initrd.availableKernelModules` (needs your storage controller) and that
`fileSystems` entries point at the right devices.

## Fresh install from the NixOS ISO

Boot the NixOS installer ISO (the minimal or graphical image, either works)
and get a network connection.

**1. Partition and format.** This config uses `systemd-boot`, so the disk
must be GPT with an EFI system partition. Replace `/dev/nvme0n1` with your
actual disk (`lsblk` to find it) — **this erases it**:

```bash
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 1GB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart root ext4 1GB 100%

sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
```

**2. Mount.**

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

**3. Clone this repo to where it will live permanently.** Putting it at
`/mnt/etc/nixos` means it survives the reboot and is where you'll edit it
later:

```bash
sudo nix-shell -p git --run \
  'git clone https://github.com/joshrandall8478/nixos /mnt/etc/nixos'
```

**4. Generate the hardware config into the repo.**

```bash
sudo nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/etc/nixos/hosts/gamestation/hardware-configuration.nix
```

**5. Commit it — this step is not optional.** Flakes only see files that git
tracks. A newly written, untracked `hardware-configuration.nix` is invisible
to the evaluator and the install will fail with a confusing "path does not
exist" error:

```bash
cd /mnt/etc/nixos
sudo nix-shell -p git --run 'git add hosts/gamestation/hardware-configuration.nix'
```

(You don't have to `git commit` — staging is enough for the flake to see it —
but committing keeps things tidy.)

**6. Install.** This builds the whole system, so expect it to take a while
and pull down a lot (NVIDIA driver, Plasma, Steam, VS Code):

```bash
sudo nixos-install --flake /mnt/etc/nixos#gamestation
```

If the installer's Nix complains about experimental features, prefix it:

```bash
sudo NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-install --flake /mnt/etc/nixos#gamestation
```

`nixos-install` prompts for a **root** password at the end.

**7. Reboot and log in.** `joshr`'s initial password is `changeme` (set in
`modules/nixos/users.nix`). Change it immediately:

```bash
passwd
```

That new password persists — `initialPassword` only applies at account
creation, and editing it later does nothing.

`amandak` and `sabom` are created with the same initial password and want the
same treatment. Neither is in `wheel`, so do it from that account's own
session or `sudo passwd <name>` from joshr's — see
[The accounts](#the-accounts).

**8. Commit `flake.lock`.** The first build generates one, pinning every
input to an exact revision. Commit it:

```bash
cd /etc/nixos
sudo git add flake.lock && sudo git commit -m "Pin flake inputs"
```

This matters more than it looks. `flake.nix` tracks `nixos-unstable`, so
**without a committed lock file every build resolves to whatever nixpkgs
HEAD happens to be that day** — meaning a rebuild that worked yesterday can
fail today because a package got renamed upstream. With the lock committed,
inputs only move when you explicitly run `nix flake update`.

## The XDG_DATA_DIRS workaround (nixpkgs#126590)

`modules/nixos/plasma-xdg-data-dirs.nix` works around a long-standing NixOS
bug where Plasma's Qt wrapper builds an `XDG_DATA_DIRS` of roughly 18 KB with
heavy duplication. Every process in the session inherits it, and since
applications stat every entry on startup looking for `.desktop` files, icons
and mime data, the whole session feels slow to launch things. It's especially
bad on storage with high per-operation latency — a VM disk, for instance.

The module merges all those `share/` directories into one derivation and
points the wrapper at that instead, taking `XDG_DATA_DIRS` down to two
entries. Taken from
[this comment](https://github.com/NixOS/nixpkgs/issues/126590#issuecomment-3194531220).

**It rebuilds `plasma-workspace` from source.** A modified derivation gets no
binary cache hit, so this recompiles on every `nix flake update` that touches
the package — think tens of minutes, more in a VM. If that trade stops being
worth it, drop the import from `hosts/gamestation/configuration.nix`; nothing
else depends on it.

## Rebuilding after changes

Once installed, from the repo (`/etc/nixos` if you followed the above):

```bash
sudo nixos-rebuild switch --flake .#gamestation
```

Useful variants:

```bash
# Build and check it evaluates, without activating:
sudo nixos-rebuild build --flake .#gamestation

# Activate now but don't add a boot entry (reverts on reboot — good for
# testing risky NVIDIA/kernel changes):
sudo nixos-rebuild test --flake .#gamestation

# Update all flake inputs (nixpkgs, home-manager, plasma-manager, dotfiles):
nix flake update

# Update just one input (e.g. after pushing to the dotfiles repo):
nix flake update dotfiles

# Pull a fresh wallhaven toplist. --refresh because Nix caches fetched files
# for an hour; without it you get the copy you already have. See "Wallpapers":
nix flake update --refresh wallhaven-toplist
```

`nix flake update` rewrites `flake.lock` — commit it alongside whatever
prompted the update, so a build that works is a build you can get back to.
If an update breaks something, `git checkout flake.lock` and rebuild.

If a rebuild leaves you with a broken desktop, pick the previous generation
from the boot menu at startup — nothing is destroyed by a bad switch.

## Hosts

Seven are defined. Pick one with the flake attribute:

| Host | For | Differences |
|---|---|---|
| `gamestation` | the desk, Plasma | NVIDIA; second-monitor panel; kernel params |
| `laptop` | portable, Plasma | no NVIDIA; power management; single-display panels |
| `gamestation-niri` | the desk, niri | as above, niri + SDDM instead of Plasma |
| `laptop-niri` | portable, niri | as above; no OpenRGB applet at login |
| `usb` | a stick, niri | boots anywhere; auto-login; one account; the disk tools |
| `server` | headless | no desktop at all; systemd-boot; cron jobs |
| `server-nvidia` | headless, with a card | as `server`, plus the driver and the NVENC/NvFBC patch |

```bash
sudo nixos-rebuild switch --flake .#gamestation
sudo nixos-rebuild switch --flake .#laptop
sudo nixos-rebuild switch --flake .#server
```

The two desk hosts and the two laptop hosts share everything else — the same
modules, the same `home/joshr` profile, the same package set. The two headless
hosts and the stick are the outliers and are described below.

### What actually differs

**Panels.** `home/joshr/plasma.nix` is shared. The second-monitor status bar
is gated behind `local.plasma.secondaryMonitorPanel`, which
`home/joshr/gamestation.nix` turns on and `home/joshr/laptop.nix` leaves off.
The dock and the primary status bar are on `screen = 0` and appear on both.
If the laptop gets docked to external displays and you want that bar back,
set the option to `true` in `home/joshr/laptop.nix`.

**Graphics.** `laptop` deliberately does *not* import `modules/nixos/nvidia.nix`
— that module hard-sets `services.xserver.videoDrivers = [ "nvidia" ]` for a
single always-on discrete GPU, which is wrong for integrated-only machines and
wrong for Optimus hybrids. If the laptop does have an NVIDIA chip, read the
comment at the bottom of `hosts/laptop/configuration.nix`: hybrids want PRIME
offload, not that module as written.

**Power.** `modules/nixos/laptop.nix` adds upower, thermald, fstrim, deep
sleep and the lid handling.

power-profiles-daemon used to be there too and is now in
`modules/nixos/desktop.nix`, which all five graphical hosts import. The
profile switcher is drawn on the desk as much as on the laptop — under Plasma
it is the selector inside the battery applet, which is also what the `Meta+B`
shortcut from the dotfiles talks to, and under niri it's the bar module
described above — so pinning the daemon to the laptop meant the desk had a
widget with nothing to put in it. The desk earns it in its own right anyway:
`amd_pstate` offers a desktop CPU the same three profiles, and "performance"
before a game is the same switch the laptop uses to mean the opposite of
"quiet". Where the CPU driver can't offer them the daemon still answers with a
placeholder, so the widget reads `balanced` and switching it changes nothing.

Under Plasma there is nothing to add to the panel for it. KDE ships no
standalone power-profile applet — the selector is part of
`org.kde.plasma.battery` ("Power and Battery"), which `home/joshr/plasma.nix`
already keeps in the system tray's `shown` list on both Plasma hosts, so it's
visible whether or not the machine has a battery. It swaps its tray icon per
profile — a leaf for power-saver, a dial for balanced, the performance glyph
for performance — and badges the battery icon with the profile where there is
a battery, so the "which profile am I in" reading the niri bar gives is
already there. The daemon was the only piece missing on the desk.

The **pop-up** when the profile changes is niri-only, and that asymmetry is
deliberate rather than a gap: Plasma already draws one of its own from
powerdevil, and the niri session had nothing at all until
`power-profile-osd` (see "The on-screen display"). It watches the daemon, so
it reports a change made from the bar or from a terminal exactly as it reports
one made with `Mod+P`.

It conflicts with TLP and auto-cpufreq, which nixpkgs asserts on. Neither is
enabled here; picking one up later means turning this off in the same edit.

**Kernel command line.** `hosts/gamestation/kernel-params.nix` is imported by
both desk hosts — it's the same physical box, so the flags belong to the
hardware rather than to either session, as does the choice of kernel itself,
which is switched on in the same file ([The kernel](#the-kernel)). It's a
separate file because `hardware-configuration.nix` is regenerated by
`nixos-generate-config` and says so at the top.

| | |
|---|---|
| `acpi_enforce_resources=lax` | lets i2c drivers touch ACPI-claimed regions, which is what OpenRGB needs to see SMBus RGB controllers — RAM and most motherboard headers. Without it OpenRGB finds the GPU and nothing else. It is a guard being switched off, not a feature switched on. |
| `nvidia_drm.fbdev=1` | gives the NVIDIA DRM driver a framebuffer console. `nvidia.nix` already sets the `modeset=1` half; this is the other, and it's what removes the flicker/black VT between bootloader and greeter. |
| `amd_iommu=on` + `iommu=pt` | AMD IOMMU on, in passthrough mode — identity-map the host's own devices so remapping is only paid for devices handed to a guest. Prerequisite for VFIO passthrough; does nothing on its own. |

**RGB.** The OpenRGB tray applet autostarts on the desk and **not** on the
laptop. Nothing sets that per host: `local.openrgb.autostart` defaults to
whether the daemon is enabled, and the daemon comes with
`modules/nixos/gaming.nix`, which the laptop hosts don't import. The laptop has
nothing for it to drive, so all it would buy is a tray icon, a Qt process and a
failed profile load every session — and with no daemon there's no `openrgb` on
PATH there either, since the package arrives with that module.

### The server

`server` doesn't build on `home/joshr/home.nix`. That file is the *desktop*
base — kitty, VS Code, ranger, spicetify, Firefox, Discord, OBS, a cursor
theme, fonts pulled from the dotfiles repo — none of which a headless machine
uses and all of which it would still build. So `home/joshr/server.nix` is
shaped like `home/root/home.nix` instead: `home/common/shell.nix`, git, and
nothing else. Add to it directly rather than reaching for the desktop base.

It takes `base.nix`, `boot.nix`, `cron.nix` and `users.nix`, imports
`development.nix` for real rather than commented out, and pins
`local.boot.loader = "systemd-boot"` — there's no wallpaper to draw, and this
is the machine most likely to reboot unattended.

Get in over SSH. `base.nix` already enables sshd with password auth **off**,
so put a key in place before the first boot or the only way in is a physical
console. Tailscale is enabled there too and still needs `tailscale up` once.

Each host still needs its own hardware scan —
`hosts/laptop/hardware-configuration.nix` is the same placeholder as
gamestation's and must be regenerated on the machine.

### The NVIDIA server

`server-nvidia` is that machine with a card in it, and the difference is one
import: `modules/nixos/nvidia-server.nix`. Same base, same `systemd-boot`,
same three cron jobs, same shell-only home profile — `home/joshr/server.nix`,
reused rather than copied, because a GPU isn't something a home profile has
an opinion about.

```bash
sudo nixos-rebuild switch --flake .#server-nvidia
```

It's a separate host rather than an option on `server` because they're
separate machines: different hardware scan, and a driver that rebuilds
locally on every kernel bump is not something to hand to a box with no card
in it.

The module is the *headless* driver, and deliberately not
`modules/nixos/nvidia.nix` — importing both would leave two definitions of
`hardware.nvidia.package` and stop the rebuild. What it does differently:

| | |
|---|---|
| `nvidiaPersistenced` | on. A desktop always has a client holding the driver open — the display server. A headless card has none, so without this every job pays for a full initialisation and the clocks fall back to idle in between. |
| `powerManagement` | off. The suspend/resume video-memory dance is for a machine that sleeps, and it copies the whole of VRAM to `/tmp` on the way down. |
| `nvidiaSettings` | off. It's a GUI control panel. |
| `enable32Bit` | off. It's there for 32-bit games under Proton. |
| `hardware.nvidia-container-toolkit` | follows `virtualisation.docker.enable`, so importing `development.nix` is also what gives containers the card — `docker run --rm --device=nvidia.com/gpu=all <image> nvidia-smi`. That name is a CDI spec, regenerated by a udev rule; the older `--gpus all` wants a runtime wrapper that only comes with the deprecated `virtualisation.docker.enableNvidia`, so the module turns Docker's own CDI support on instead. |
| the patch | below. |

One thing worth knowing before it confuses you: the module sets
`services.xserver.videoDrivers = [ "nvidia" ]` on a machine with no X.
nixpkgs gates its *entire* NVIDIA module on that list — kernel modules, udev
rules, the libraries under `/run/opengl-driver`, `nvidia-smi`, persistenced.
Leave it out and every `hardware.nvidia.*` setting is silently inert. It does
not enable X; `services.xserver.enable` does that, and it stays false.

#### The patch

GeForce cards carry two limits that are policy rather than silicon:

- **NVENC** refuses more than a handful of simultaneous encode sessions —
  three on older drivers, five on newer ones. The fourth `ffmpeg -c:v
  h264_nvenc` fails with `OpenEncodeSessionEx failed: out of memory (10)`
  while the card sits at 20% utilisation. This is the limit that decides how
  many streams a transcoding server can serve.
- **NvFBC**, whole-framebuffer capture, is refused on anything that isn't a
  Quadro. Sunshine, OBS and the remote desktops fall back to slower paths.

Both are a branch on the card's model inside a userspace library.
[keylase/nvidia-patch](https://github.com/keylase/nvidia-patch) publishes,
per driver version, the bytes to overwrite so the branch isn't taken, and
[icewind1991/nvidia-patch-nixos](https://github.com/icewind1991/nvidia-patch-nixos)
wraps those offsets as a nixpkgs overlay. That's the `nvidia-patch` flake
input; the overlay is applied inside `nvidia-server.nix` rather than in
`flake.nix`, so it reaches the hosts that import the module and no others.

Three consequences of the mechanism:

- **It edits a binary NVIDIA ships**, which is a licence question you're
  answering for yourself. Nothing is redistributed — the `sed` runs on the
  machine, on the driver that machine downloaded.
- **It's keyed on the exact driver version.** nixpkgs gets a new driver
  before the offsets for it are published, so a channel that moves can land
  on a version the table has never seen. That's why `local.nvidia.driver`
  defaults to `"production"` rather than the desktop's `"latest"`, and why a
  version the table doesn't cover **warns and installs unpatched** instead of
  failing. `local.nvidia.patch.required = true` turns that warning into a
  failed rebuild on a host where a capped encoder is an outage.
- **It changes the driver derivation**, so the driver builds on the machine
  instead of coming from `cache.nixos.org` — kernel module included, several
  minutes on a server CPU, repeated on every kernel or driver bump.

It reaches containers too. The CDI spec is generated against
`hardware.nvidia.package`, so the libraries bind-mounted into a container are
the patched ones — a stock Jellyfin or ffmpeg image gets the unlocked encoder
without knowing anything about it.

When a rebuild warns that the offsets are missing, in order of cheapness:

```bash
nix flake update nvidia-patch     # the table is usually days behind a release
                                  # then: local.nvidia.driver = "production";
                                  # or:   local.nvidia.patch.nvenc = false;

# what the table currently knows
nix eval .#nixosConfigurations.server-nvidia.pkgs.nvidia-patch-list.nvenc \
  --apply builtins.attrNames
```

#### Checking it worked

There's no flag to read — the check is to exceed the old limit:

```bash
nix shell nixpkgs#ffmpeg
for i in $(seq 1 8); do
  ffmpeg -f lavfi -i testsrc=size=1920x1080:rate=30 -t 60 \
         -c:v h264_nvenc -f null - &
done
nvidia-smi                        # eight encoders, or a pile of session errors
nvidia-smi -q -d ENCODER_STATS    # what the card thinks it's running
```

`nvtop` is installed for the same question asked continuously — per-process
GPU, VRAM and encoder use.

#### On other hardware

`local.nvidia.open = true` needs Turing (RTX 20xx, GTX 16xx) or newer. Most
of what ends up in a box like this is older — P4, P40, GTX 10xx — and Pascal
has no open kernel module at all, so leaving it on there produces a driver
that won't load. Set it to `false` in
`hosts/server-nvidia/configuration.nix`.

A datacenter or legacy driver that `local.nvidia.driver` can't name goes in
`local.nvidia.package` (e.g. `config.boot.kernelPackages.nvidiaPackages.dc_580`)
rather than in `hardware.nvidia.package` — the module writes that one, and a
second definition either conflicts or, forced, quietly discards the patch.

Nothing that *uses* the card is configured here. Jellyfin, Frigate, a stack
of ffmpeg jobs, ollama — this is the machine they'd run on, and they go in
that host's `configuration.nix` or a module of their own. `ai.nix` is
deliberately not imported; the host file says why.

### The stick

`usb` is a full NixOS install on a USB drive, carried around and booted on
whatever machine is in front of you. It is not an installer image: nothing on
it is read-only, it keeps state between boots, and it is rebuilt from this
repo like any other host.

```bash
sudo nixos-rebuild switch --flake .#usb
```

It is `laptop-niri` with three changes, and everything else about it — the
session, the palette, the keybinds, the shell — is the same.

**It boots on hardware it has never seen.** No `nvidia.nix`, no
`kernel-params.nix`, and no display layout: `local.niri.outputs` is left at
its empty default, which is niri's auto-detect. The interesting file is
`hosts/usb/hardware-configuration.nix`, which is a placeholder of a different
shape from the others. Filesystems are named by **label** rather than by UUID
or `/dev/sdX` — the stick is `sdb` on one machine and `sdd` on the next — and
the labels are `nixos-usb` and `USB-BOOT` rather than the `nixos`/`boot` the
fixed installs use, so that plugging the stick into one of those machines
while it is running isn't a coin toss over which filesystem answers to a name.
The initrd carries every USB host controller back to UHCI, plus `usb_storage`
and `uas` — a USB 3 drive that negotiates UAS and finds no driver falls back
slowly or not at all. `ahci`, `nvme` and `sdhci_pci` are in that list too, not
because gparted needs them (the booted system has the whole module tree and
udev loads them on sight) but so that the initrd's emergency shell can already
see the machine's own disks, which is a plausible place to end up on a machine
that is already not booting.

**It changes nothing on the machine it is plugged into.** The bootloader is
GRUB rather than the limine default, with `efiInstallAsRemovable = true` —
`grub-install --removable`, which writes the loader to `EFI/BOOT/BOOTX64.EFI`,
the one path UEFI firmware boots without being told to. Its other half is
`boot.loader.efi.canTouchEfiVariables = lib.mkForce false`: writing an NVRAM
boot entry is how a fixed disk tells the firmware it exists, and from a stick
it is a permanent entry on someone else's motherboard pointing at a drive that
won't be there next time. `mkForce` because `modules/nixos/boot.nix` sets it
true for all three loaders, which is right everywhere else. GRUB asserts the
two can't both be on, so getting this wrong stops the build rather than
producing a stick that quietly edits machines. `local.boot.detectOtherSystems`
is off for the same reason in reverse — os-prober scans the disks present at
*rebuild* time and would bake one machine's Windows into the menu shown on
every other. `local.boot.plymouth.enable` is left off here too, on the
reasoning that the boot most likely to need explaining is the one on hardware
this stick has never met, and a splash is a screen with the explanation
painted over.

**Whoever holds it is logged in.** `services.displayManager.autoLogin` names
`joshr`, and `modules/nixos/usb-users.nix` makes him the only account there is
— that file exists rather than an option on `users.nix` because a list of
accounts merges by union, so a host importing that one could add people but
never take one away. The cost is stated plainly: nothing is asked for between
power-on and the home directory, and nothing on the drive is encrypted. The
password still guards `sudo` and the lock screen, which on a device that can
be walked off with is the whole of the security. Deleting the two `autoLogin`
options brings the greeter back and changes nothing else. Logging out returns
to the greeter rather than looping straight back in — SDDM's
`autoLogin.relogin` defaults to false, which means "on boot, not on every
session end".

#### The disk tools

Two modules, imported only by this host, though there is nothing host-specific
in either.

`modules/nixos/disk-managements.nix` is the three GUIs: **gparted**, **KDE
Partition Manager** and **GNOME Disks**. They overlap on purpose — on a rescue
stick "the other one opens it" is a feature — but they are also genuinely
different tools: the first two edit partition tables, and GNOME Disks is the
udisks2 front end that does SMART, self-tests, benchmarking and writing an
image to a drive.

Two things in that module are load-bearing and easy to get wrong:

- KDE Partition Manager goes in as `programs.partition-manager.enable` rather
  than as a package. Its privileged half is kpmcore's `externalcommand`
  helper, reached over the system D-Bus, so kpmcore has to land in
  `services.dbus.packages` for its service file and polkit action to exist.
  Installed as a bare package you get a window that opens, lists the disks,
  and fails every operation with a permission error.
- gparted is `gparted.override { withAllTools = true; }`. Its wrapper bakes in
  the PATH it will use, and the default carries dosfstools, e2fsprogs and
  util-linux only — so a stock gparted greys out "format as btrfs" even on a
  machine that has btrfs-progs installed system-wide. The system PATH can't
  rescue it either: gparted is launched through pkexec, which sanitises the
  environment. The cost is that an override isn't the build in the binary
  cache, so gparted compiles locally.

`modules/nixos/filesystems-management.nix` is what all of them shell out to:
**btrfs-progs**, **exfatprogs**, **dosfstools** and **e2fsprogs** — mkfs,
fsck, resize and label for btrfs, exFAT, FAT and ext2/3/4. They're
`environment.systemPackages` because two of the three callers aren't the user:
udisks2 runs as root from a systemd unit and takes the system PATH, as does
kpmcore's helper. Mounting is a separate question and doesn't need any of it —
the kernel handles all four out of the box — these are for making, checking
and repairing.

`joshr` is deliberately **not** in the `disk` group on this host. That would
hand every process in the session raw read/write on every block device, which
is root over the machine by another name; the editors don't want it, since
asking polkit gets them the same access one operation at a time.

### Adding another host

1. `mkdir -p hosts/<newhost>`, write a `configuration.nix` importing the
   modules that apply, and generate its `hardware-configuration.nix`.
2. Add a `<newhost> = mkHost { ... }` entry to `nixosConfigurations` in
   `flake.nix`, pointing at that host module and a `homeModules` attrset —
   one entrypoint per account, `root` excepted. See
   [The accounts](#the-accounts).
3. Install with `--flake /mnt/etc/nixos#<newhost>`.


## Updating the dotfiles-derived assets

```bash
nix flake update dotfiles   # pull in changes from joshrandall8478/dotfiles
```
