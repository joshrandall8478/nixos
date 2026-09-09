{
  config,
  lib,
  osConfig,
  pkgs,
  niriTheming,
  ...
}:

# Runtime helpers, all built as store scripts and bound to keys in config.kdl.
#
# The theme switcher only ever moves one symlink (see theming.nix) and then
# nudges each tool to re-read its config. Nothing writes generated content at
# runtime.
let
  inherit (niriTheming)
    themeSet
    themes
    themeDirs
    stateDir
    activeDir
    lockFieldFrame
    ;

  # Resolve the greeting from the declarative NixOS user description while
  # the configuration is built. Runtime lock invocations no longer depend on
  # NSS/getent being available or returning a complete GECOS field.
  userDescription =
    lib.attrByPath
      [ config.home.username "description" ]
      config.home.username
      osConfig.users.users;

  userDescriptionWords =
    lib.filter (word: word != "") (lib.splitString " " userDescription);

  firstName =
    if userDescriptionWords == [ ] then
      config.home.username
    else
      builtins.head userDescriptionWords;

  # The greeting has two layers of syntax under it, and this is stripped for
  # both at evaluation time rather than argued with in shell at lock time.
  #
  # Hyprlang reads a value to the end of its line and treats `#` as the start
  # of a comment, and the line the greeting lands in is now a command that
  # Hyprlock hands to /bin/sh, inside double quotes — so a dollar, a backquote
  # or a backslash in a name would belong to the shell rather than to the
  # label. None of them belong in a first name either.
  safeFirstName =
    let
      unsafe = [
        "\r"
        "\n"
        "{"
        "}"
        "\""
        "#"
        "$"
        "`"
        "\\"
      ];
      stripped = builtins.replaceStrings unsafe (map (_: "") unsafe) firstName;
    in
    if stripped == "" then config.home.username else stripped;

  wallpaperDir = "${config.home.homeDirectory}/.local/share/wallpapers";

  useNoctalia = config.local.niri.shell == "noctalia";

  # The half of `theme-apply` that tells the shell about the switch.
  #
  # Everything else that file does — repointing the symlink, kitty's SIGUSR1,
  # the KDE palette broadcast, the SDDM state file — is the same under either
  # shell, because the theme is still one directory of rendered configs and
  # the apps reading it have not changed. Only this part differs, and it
  # differs completely: the waybar stack is three daemons that read a
  # stylesheet once at startup and have to be restarted to see a new one,
  # where noctalia holds the palette in memory and repaints on being told.
  #
  # `color-scheme-set custom <name>` works because the palette files
  # noctalia-palettes.nix generates are named for the theme id — the same
  # string this script was just given. Nothing has to translate between them.
  #
  # `|| true` for the same reason the restarts carry it: a shell that isn't
  # running yet is not a reason for the rest of the switch to fail, and the
  # palette is in the config file anyway, so the next start picks it up.
  shellApplyTheme =
    if useNoctalia then
      ''
        noctalia msg color-scheme-set custom "$name" >/dev/null 2>&1 || true
      ''
    else
      ''
        systemctl --user restart waybar.service || true
        systemctl --user restart dunst.service || true
        systemctl --user restart swayosd.service || true
      '';

  # And what that needs on PATH.
  #
  # `pkgs.noctalia` and not `pkgs.noctalia-shell` — nixpkgs carries both
  # majors and the names read backwards, so the v4 one has the more official
  # looking attribute. See the header of ./noctalia.nix.
  #
  # Naming a package straight out of `pkgs` also happens to be the only shape
  # that works here, which is worth knowing before "tidying" it into an option
  # read. This file publishes `_module.args.niriScripts`, and ./noctalia.nix
  # takes that as a formal argument, so it has to be callable before this
  # attribute set exists. Reading an *option* would mean needing the full
  # module list to collect that option's definitions, and the full module list
  # needs noctalia.nix called, which needs niriScripts, which is this.
  shellApplyInputs = lib.optional useNoctalia pkgs.noctalia;

  # The backlight device the `brightness` helper reads back for the OSD. Empty
  # when unset, which the script treats as "whichever sorts first". Shared with
  # waybar.nix through the same option so the bar and the pop-up are always
  # quoting the same display — see local.niri.brightness.device.
  brightnessDevice = config.local.niri.brightness.device;
  primaryBacklight = if brightnessDevice == null then "" else brightnessDevice;

  lockAlbumArtBackground = config.local.niri.lockAlbumArtBackground;
  lockAlbumArtCover = config.local.niri.lockAlbumArtCover;
  lockBatteryIndicator = config.local.niri.lockBatteryIndicator;

  # What a session that has never picked a wallpaper starts on — see
  # `wallpaperRestore` below.
  #
  # A path under wallpaperDir rather than the `inputs.dotfiles` store path
  # this file could equally name, because the chosen wallpaper is written to a
  # state file and read back by things that are not this session: the SDDM
  # greeter sync (modules/nixos/niri.nix) and the limine theme sync
  # (modules/nixos/boot.nix). A home path stays the same across a `nix flake
  # update dotfiles`, where the store path would move and leave the state file
  # naming a wallpaper that had been garbage collected. It is also the path
  # the picker would produce for the same image, so the default and a manual
  # re-pick of it are the same string.
  #
  # home/joshr/home.nix links the dotfiles' wallpapers into that directory
  # file by file, so this resolves to nixos.png in the store either way.
  # `wallpaperRestore` checks it exists and falls through to a random one if
  # the dotfiles ever drop the file.
  defaultWallpaper = "${wallpaperDir}/nixos.png";

  # swaylock, patched so the date stacks onto two lines and can't overhang the
  # ring.
  #
  # Upstream draws the date as one row sized at a hardcoded `arc_radius / 6`
  # (render.c), so it grows in exact proportion to the circle and a long date
  # overhangs by the same fraction at every radius. No flag reaches it —
  # `--font-size` sets the clock above it and nothing else is exposed — so a
  # wider `--indicator-radius` cannot buy the room. Without the patch the only
  # options are to shorten the date or narrow the font, and both give something
  # up: the installed fonts are FiraCode and Poppins, with nothing condensed.
  #
  # So the patch teaches it to split `--datestr` on a newline (strftime `%n`)
  # and stack the halves — weekday over month and day. Two short lines fit at
  # full size where one long one didn't: at radius 130 "Wednesday" and
  # "September 24" come out 117px and 156px against chords of 246px and 231px,
  # where the single row was 299px against 240px.
  #
  # It also scales a line down if it still wouldn't fit, bounded by the ring's
  # inner chord at that line's own baseline rather than the diameter, since the
  # date sits below the centre where the circle has already narrowed. With
  # stacking that never triggers for this format — it's the backstop that makes
  # an overhang impossible for any format or locale.
  #
  # Costs a source build of swaylock-effects, which is a small C project and
  # quick. If a nixpkgs bump ever moves those lines the patch will fail to
  # apply, and the fallback is a one-line `--datestr` short enough to fit
  # (`%a, %b %d`).
  swaylock = pkgs.swaylock-effects.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./swaylock-date-fit.patch ];
  });

  # name -> store path, as a shell case statement.
  themeCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (n: d: ''${n}) target="${d}" ;;'') themeDirs
  );

  # Every palette in themes.nix, split by light and dark — which is the only
  # form anything wants it in.
  #
  # There used to be one flat list here, and a filter on it that dropped a
  # `noctalia-*` prefix: theme-set.nix carried a hand-transcribed copy of
  # noctalia's own builtin palettes, so that the greeter and the boot menu
  # could be given a prebuilt match when the shell was switched to one of
  # them. Nothing ever selected them — the shell writes `noctalia-live` to
  # `current`, not a builtin's name — and both consumers read the shell's
  # resolved manifest now, so the copy and the filter are gone together.
  #
  # The split is what everything that offers a choice actually wants. A
  # picker that mixes the light and the dark palettes makes the light/dark
  # preference meaningless — you would set it and then undo it with the next
  # pick — and a *random* jump across the divide is worse still, since the
  # one thing you can be sure of about the room you are in is that it has not
  # changed since the last keypress.
  namesInMode = m: lib.attrNames (lib.filterAttrs (_: t: t.mode == m) themes);
  darkNames = lib.concatStringsSep "\n" (namesInMode "dark");
  lightNames = lib.concatStringsSep "\n" (namesInMode "light");

  # The mode a fresh session starts in: whatever the default palette is.
  defaultTheme = themeSet.default;
  defaultMode = themes.${defaultTheme}.mode;

  # `name) field="value" ;;` arms, at the indentation the case statements
  # below sit at.
  caseArms =
    f:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (n: t: "          ${n}) ${f t} ;;") themes);
  themeModeCases = caseArms (t: ''mode="${t.mode}"'');
  themeCounterpartCases = caseArms (t: ''counter="${t.counterpart}"'');

  # The menu's rows: the palette's id, which is what the switcher speaks, and
  # its description, which is what tells two dark blues apart at a glance.
  menuRows =
    names:
    lib.escapeShellArgs (map (n: "${n} — ${themes.${n}.description}") names);
  darkRows = menuRows (namesInMode "dark");
  lightRows = menuRows (namesInMode "light");
  allRows = menuRows (lib.attrNames themes);

  # --- the light/dark preference, and the two files that hold it ----------
  #
  # `~/.local/state/niri-theme/mode` is "dark", "light" or "auto", and it is
  # a *preference*, not a state: in "auto" it says nothing about what is on
  # screen, only that the answer comes from somewhere else.
  #
  # `~/.local/state/niri-theme/selected` is the palette this switcher last
  # applied. It exists because `current` cannot answer the question under
  # both shells: under noctalia the shell owns that file and writes
  # `noctalia-live` into it — deliberately, because a palette derived from a
  # wallpaper has no name — so there would be nothing there to find a
  # counterpart for. `selected` is written under both shells by `theme-apply`
  # and nothing else touches it.
  #
  # The cost of that under noctalia is honest and small: change the palette
  # from noctalia's own settings panel rather than through `theme-apply`, and
  # `selected` is stale, so the next light/dark toggle moves to the
  # counterpart of the palette you last picked *here*. That is the same
  # limitation everything outside the shell has under noctalia — see "Theme
  # sync under noctalia" in MANUAL.md — and the fix in every case is to pick
  # through the menu.
  modeState = ''
    write_state() {
      # $1 path, $2 contents. Atomic: the SDDM and limine sync units watch
      # this directory with systemd path units and can fire mid-write, and a
      # half-written palette name is a greeter with no colours.
      mkdir -p "${stateDir}"
      tmp="$(mktemp "$1.XXXXXX")"
      printf %s "$2" > "$tmp"
      mv -f "$tmp" "$1"
    }

    read_pref() {
      case "$(cat "${stateDir}/mode" 2>/dev/null || true)" in
        dark) printf dark ;;
        light) printf light ;;
        auto) printf auto ;;
        *) printf %s "${defaultMode}" ;;
      esac
    }

    # What the *system* says, which is what "auto" follows.
    #
    # org.gnome.desktop.interface color-scheme is the freedesktop light/dark
    # preference on a Linux desktop: the XDG desktop portal serves it as
    # org.freedesktop.appearance color-scheme, and GTK4, libadwaita,
    # Electron, Firefox and Qt6 all read it from there. Reading it rather
    # than declaring it is the whole point of "auto" — anything that can
    # write that key, including a settings panel or a plain `dconf write`,
    # then decides what the desktop wears.
    #
    # `default` — the value the key holds when nobody has expressed a
    # preference — is not "light", and is not treated as one.
    read_system_mode() {
      case "$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null || true)" in
        *prefer-light*) printf light ;;
        *prefer-dark*) printf dark ;;
        *) printf %s "${defaultMode}" ;;
      esac
    }

    effective_mode() {
      if [ "$(read_pref)" = auto ]; then read_system_mode; else read_pref; fi
    }

    read_selected() {
      sel="$(cat "${stateDir}/selected" 2>/dev/null || true)"
      [ -n "$sel" ] || sel="${defaultTheme}"
      printf %s "$sel"
    }

    # Both of these come out empty for a name that is not a palette, which is
    # what the callers check.
    mode_of() {
      mode=""
      case "$1" in
${themeModeCases}
      esac
      printf %s "$mode"
    }

    counterpart_of() {
      counter=""
      case "$1" in
${themeCounterpartCases}
      esac
      printf %s "$counter"
    }
  '';

  # Publishing the mode to everything this config does not render a palette
  # for.
  #
  # The same key `read_system_mode` above reads, written rather than read:
  # when the preference is dark or light this desktop *is* the system's
  # light/dark preference, and GTK4, libadwaita, Electron and Firefox follow
  # it without any of them being themed here. In "auto" the key is left
  # alone, because there the desktop is following it and writing it back
  # would be an argument with whatever set it.
  #
  # gtk-theme and icon-theme go with it in both cases. They are not the
  # freedesktop preference, but a light session with Adwaita-dark widgets and
  # Papirus-Dark folder icons is not a light session.
  #
  # What does *not* follow: GTK3. It reads ~/.config/gtk-3.0/settings.ini,
  # which home-manager owns as a read-only symlink into the store, and there
  # is no XSettings daemon in a niri session to override it. GTK3 apps
  # therefore keep the build-time Adwaita-dark until the next login of a
  # differently built profile. GTK4 and libadwaita read the portal and change
  # in place.
  appearanceIpc = ''
    dconf_set() {
      # Only writes when the value differs. `theme-mode --watch` watches this
      # whole directory rather than the one key — so that it also notices a
      # home-manager activation resetting gtk-theme underneath it — and an
      # unconditional write would wake the watcher with its own change.
      have="$(dconf read "$1" 2>/dev/null || true)"
      if [ "$have" != "$2" ]; then
        dconf write "$1" "$2" >/dev/null 2>&1 || true
      fi
    }

    # $1: "dark" or "light". $2: "system" when we are following the key
    # rather than driving it.
    publish_appearance() {
      if [ "$1" = light ]; then
        gtk_theme="Adwaita"
        icons="Papirus-Light"
        scheme="'prefer-light'"
      else
        gtk_theme="Adwaita-dark"
        icons="Papirus-Dark"
        scheme="'prefer-dark'"
      fi

      dconf_set /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'"
      dconf_set /org/gnome/desktop/interface/icon-theme "'$icons'"

      if [ "''${2:-}" != system ]; then
        dconf_set /org/gnome/desktop/interface/color-scheme "$scheme"
      fi
    }
  '';

  # Apply a theme by name: repoint the symlink, then reload consumers.
  #
  # The shell is the one consumer that differs between the two values of
  # `local.niri.shell`; see `shellApplyTheme` above for that half. Everything
  # below it is the same either way, because a theme is still a directory of
  # rendered config files and the apps reading it have not changed.
  #
  #   niri    watches its config and the include target changed, so it
  #           reloads on its own.
  #   waybar  restarted. It's started with `-s <active>/waybar.css`, and a
  #           restart is the only way to be sure the stylesheet is re-read —
  #           SIGUSR2 alone did not reliably repaint.
  #   dunst   restarted; it's launched with `-config <active>/dunstrc`.
  #   swayosd restarted. Same reason as the other two — it's started with
  #           `--style <active>/swayosd.css` and reads that once, at startup.
  #   noctalia
  #           told, not restarted: `color-scheme-set custom <name>` names one
  #           of the palettes generated by ./noctalia-palettes.nix, which are
  #           filed under the same theme id this script takes. It repaints in
  #           place, and it replaces the three restarts above rather than
  #           joining them — those daemons are not running under it.
  #   wofi    nothing — it reads its stylesheet fresh on each launch. Still
  #           true under noctalia, where wofi is no longer the launcher but is
  #           still the `--dmenu` behind theme-menu and wallpaper-menu.
  #   kitty   SIGUSR1, which is kitty's documented "re-read kitty.conf"
  #           signal. It follows the include and repaints open windows, so
  #           running terminals change colour in place.
  #   KDE     a palette-changed signal on the session bus. This is the
  #           mechanism Plasma itself uses when you pick a colour scheme, and
  #           plasma-integration — loaded because qt.platformTheme.name is
  #           "kde", see ./default.nix — listens for it and re-reads
  #           kdeglobals, so an open Dolphin repaints in place. Best effort:
  #           nothing guarantees a given Qt app subscribes, and anything that
  #           doesn't keeps its old palette until relaunched.
  #   VS Code nothing to send. Extensions, and therefore colour themes, are
  #           scanned once at startup; the editor picks the new palette up
  #           the next time it starts.
  #   SDDM    under waybar, picked up by a system path unit watching the file
  #           written below; applies at the next greeter start. Under noctalia
  #           it follows the shell's palette manifest instead and this script
  #           is not in the chain at all. See modules/nixos/niri.nix.
  #   Limine  the same, for the boot menu. See modules/nixos/boot.nix.
  #   Spotify nothing under waybar — a Spicetify build is immutable and its
  #           colours are baked in, so the palette it was built with is the
  #           palette it has. Under noctalia it follows the shell's live CSS
  #           without this script's involvement. See ../spicetify.nix.
  #
  # --- what this does *not* do under noctalia ----------------------------
  #
  # Repoint `active`, or write `current`. Both belong to the shell there: its
  # templates render the live directory and its `colors_changed` hook
  # publishes it, so anything written here would be overwritten moments later
  # by the hook this very script triggers. Worse, in the window between the
  # two the symlink names a build-time palette, which is the state Dolphin or
  # VS Code would read if either happened to start in it.
  #
  # This is also where an `NIRI_THEME_FROM_NOCTALIA` guard used to live,
  # against a hook that called back into this script. No such hook exists —
  # noctalia's hooks run `noctalia-theme-resync` directly — so the variable
  # was never set by anything and the branch it guarded was dead.
  themeApply = pkgs.writeShellApplication {
    name = "theme-apply";
    runtimeInputs =
      (with pkgs; [
        coreutils
        libnotify
        systemd
        procps
        dbus
        dconf
      ])
      ++ shellApplyInputs;
    text = ''
      ${modeState}
      ${appearanceIpc}

      keep_mode=""
      if [ "''${1:-}" = "--keep-mode" ]; then
        keep_mode=1
        shift
      fi

      name="''${1:-}"
      if [ -z "$name" ]; then
        echo "usage: theme-apply [--keep-mode] <name>" >&2
        exit 2
      fi

      target=""
      case "$name" in
      ${themeCases}
        *) echo "unknown theme: $name" >&2; exit 1 ;;
      esac

      ${
        if useNoctalia then
          ''
            # The prebuilt directory is not read under this shell, so the case
            # above is doing double duty as the check that `$name` names a
            # palette at all — `color-scheme-set` would otherwise take an id
            # noctalia has no file for and repaint with nothing.
            [ -n "$target" ] || exit 1
          ''
        else
          ''
            mkdir -p "${stateDir}"
            ln -sfn "$target" "${activeDir}"
            write_state "${stateDir}/current" "$name"
          ''
      }

      # Which palette the switcher is on, under either shell. See the note on
      # `modeState` for why this is not `current`.
      write_state "${stateDir}/selected" "$name"

      theme_mode="$(mode_of "$name")"

      # An explicit pick decides the light/dark preference too. Choosing
      # `gruvbox` from the menu while the session is in light mode means you
      # want the dark one, and leaving the preference on "light" would have
      # the next toggle — or, in "auto", the next thing that touches the
      # system key — quietly undo the choice you just made.
      #
      # --keep-mode is for the one caller that is *implementing* a mode
      # change rather than making one: `theme-mode` has already written the
      # preference and is applying the counterpart that follows from it.
      if [ -z "$keep_mode" ]; then
        write_state "${stateDir}/mode" "$theme_mode"
        publish_appearance "$theme_mode"
      elif [ "$(read_pref)" = auto ]; then
        publish_appearance "$theme_mode" system
      else
        publish_appearance "$theme_mode"
      fi

      ${shellApplyTheme}

      # -x so this matches the kitty process and not, say, an editor that
      # happens to have "kitty" in its command line. Non-zero simply means no
      # terminal is open.
      pkill -USR1 -x kitty || true

      # Tell running KDE apps their palette changed, so an open Dolphin
      # repaints instead of waiting to be relaunched.
      #
      # This is KGlobalSettings::notifyChange, the signal Plasma emits when a
      # colour scheme is applied; the two int32 arguments are the change type
      # (0 = PaletteChanged) and an unused argument the signature still
      # requires. It is a plain broadcast — with no subscriber it goes
      # nowhere and costs nothing, which is why it is safe to send blind.
      dbus-send --session --type=signal \
        /KGlobalSettings org.kde.KGlobalSettings.notifyChange \
        int32:0 int32:0 >/dev/null 2>&1 || true

      notify-send -a theme -i preferences-desktop-theme \
        "Theme" "Switched to $name — Some apps may need to be restarted for $name to apply." || true
    '';
  };

  # Set, or follow, the session's light/dark preference.
  #
  # A mode here is not a second palette dimension the way it is in a shell
  # that computes its own colours. Every palette in themes.nix is finished
  # and is already either light or dark, so switching modes means switching
  # *palettes*: to the `counterpart` the current one names. `gruvbox` toggles
  # to `gruvbox-light` and back; `gruvbox-hard` toggles to `gruvbox-light`
  # and comes back to plain `gruvbox`, because a family with three dark
  # contrasts still has to have one canonical answer. See the header of
  # themes.nix.
  #
  #   theme-mode dark|light   pick one and stay there
  #   theme-mode auto         follow the system's own preference
  #   theme-mode toggle       the other one of dark/light; leaves auto
  #   theme-mode status       the preference, then what it resolves to
  #   theme-mode --watch      the long-running half of "auto"; see the unit
  #                           at the bottom of this file
  #
  # Under noctalia this works without any new IPC: the counterpart is a
  # palette id like any other, so `theme-apply` hands it to
  # `color-scheme-set custom` exactly as it does for a manual pick. Noctalia's
  # *own* dark/light switch stays a no-op — ./noctalia-palettes.nix writes
  # the same colours into both variants of every generated palette on purpose,
  # so that a palette you chose is the palette you get — and this is the
  # switch that means something here.
  themeMode = pkgs.writeShellApplication {
    name = "theme-mode";
    runtimeInputs = with pkgs; [
      coreutils
      dconf
      themeApply
    ];
    text = ''
      ${modeState}
      ${appearanceIpc}

      # Bring the session in line with whatever the preference now resolves
      # to. Idempotent, which is what makes it safe to call from the watch
      # loop on every change: if the active palette is already the right way
      # up, this only republishes, and `dconf_set` will not write a value
      # that is already there.
      sync_mode() {
        want="$(effective_mode)"
        sel="$(read_selected)"
        have="$(mode_of "$sel")"
        counter="$(counterpart_of "$sel")"

        if [ -n "$have" ] && [ "$have" != "$want" ] && [ -n "$counter" ]; then
          theme-apply --keep-mode "$counter"
          return 0
        fi

        if [ "$(read_pref)" = auto ]; then
          publish_appearance "$want" system
        else
          publish_appearance "$want"
        fi
      }

      set_pref() {
        write_state "${stateDir}/mode" "$1"
        sync_mode
      }

      case "''${1:-status}" in
        dark | light | auto)
          set_pref "$1"
          ;;
        toggle)
          if [ "$(effective_mode)" = dark ]; then set_pref light; else set_pref dark; fi
          ;;
        status)
          printf '%s\t%s\n' "$(read_pref)" "$(effective_mode)"
          ;;
        --watch)
          # The whole directory rather than the one key, so that a
          # home-manager activation resetting gtk-theme and icon-theme
          # underneath us is noticed too — those are written by
          # home-manager's own gtk module on every `nixos-rebuild switch`,
          # and without this they would stay wrong until the next login.
          #
          # This does not feed back on itself: `dconf_set` writes only when
          # the value differs, so the writes this loop makes in response to a
          # change either are the change or do not happen.
          sync_mode
          dconf watch /org/gnome/desktop/interface/ | while read -r _; do
            sync_mode
          done
          ;;
        *)
          echo "usage: theme-mode [dark|light|auto|toggle|status|--watch]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Cycle to the next theme, wrapping around. Bound to nothing; still on
  # PATH.
  #
  # Within the current mode: see `namesInMode` above for why every chooser
  # here stays on one side of the light/dark line.
  themeCycle = pkgs.writeShellApplication {
    name = "theme-cycle";
    runtimeInputs = with pkgs; [
      coreutils
      dconf
      themeApply
    ];
    text = ''
      ${modeState}

      if [ "$(effective_mode)" = light ]; then
        themes="${lightNames}"
      else
        themes="${darkNames}"
      fi

      current="$(read_selected)"

      next="$(echo "$themes" | awk -v cur="$current" '
        { list[NR] = $0 }
        END {
          for (i = 1; i <= NR; i++) if (list[i] == cur) { print list[i % NR + 1]; exit }
          print list[1]
        }')"

      theme-apply "$next"
    '';
  };

  # Jump to a random theme, within the current mode.
  #
  # The current theme is excluded from the draw, so this always visibly does
  # something: a plain random pick over a couple of dozen palettes lands on
  # the one already active often enough to read as broken rather than as
  # chance.
  #
  # Bound to nothing. The Mod+Shift halves of the theme and wallpaper pairs
  # were removed because Mod+Shift+W is one slip from Mod+Ctrl+W and the slip
  # silently replaced whatever you had chosen; `theme-random`, `theme-cycle`
  # and `wallpaper-random` are all still here for when that is genuinely what
  # you want.
  themeRandom = pkgs.writeShellApplication {
    name = "theme-random";
    runtimeInputs = with pkgs; [
      coreutils
      dconf
      gnugrep
      themeApply
    ];
    text = ''
      ${modeState}

      if [ "$(effective_mode)" = light ]; then
        themes="${lightNames}"
      else
        themes="${darkNames}"
      fi

      current="$(read_selected)"

      # -x so a name can't match as a substring of another, -F so nothing in
      # a theme name is read as a pattern. `|| true` because grep exits 1 when
      # it selects nothing, which under pipefail would abort the script.
      pick="$(printf '%s\n' "$themes" \
                | grep -vxF -- "$current" \
                | shuf -n1 || true)"

      # Only reachable if the current mode holds exactly one palette, in
      # which case there is nothing to switch to.
      [ -n "$pick" ] || exit 0

      theme-apply "$pick"
    '';
  };

  # Pick a theme, or a mode, from a wofi menu. Mod+Ctrl+T.
  #
  # Three things about the shape of it:
  #
  # The mode rows come first and are radio buttons, not a toggle. "Match the
  # system" is a third state and not a variant of the other two, and a single
  # toggle row could not show which of the three you are in — which matters
  # most for `auto`, where the palette on screen tells you what the system
  # said and nothing tells you that it was the system that said it.
  #
  # The list under them is only the palettes in the current mode. Picking one
  # from the other side is still possible — the last row opens the whole set
  # — and doing so moves the preference with it, because an explicit pick is
  # an explicit pick. See the --keep-mode note in `theme-apply`.
  #
  # And every row carries the palette's description as well as its id. With
  # fifty-one palettes, a column of bare names is a list of things you have
  # to already know; `tokyo-night` and `kanagawa` in particular were for a
  # long time much harder to tell apart in the menu than they are on screen.
  themeMenu = pkgs.writeShellApplication {
    name = "theme-menu";
    runtimeInputs = with pkgs; [
      coreutils
      dconf
      wofi
      themeApply
      themeMode
    ];
    text = ''
      ${modeState}

      show_all=0

      while :; do
        pref="$(read_pref)"
        eff="$(effective_mode)"

        dark_mark="○"
        light_mark="○"
        auto_mark="○"
        case "$pref" in
          dark) dark_mark="●" ;;
          light) light_mark="●" ;;
          auto) auto_mark="●" ;;
        esac

        if [ "$show_all" = 1 ]; then
          rows="$(printf '%s\n' ${allRows})"
          last_row="≡ Only $eff themes"
        elif [ "$eff" = light ]; then
          rows="$(printf '%s\n' ${lightRows})"
          last_row="≡ Show every theme"
        else
          rows="$(printf '%s\n' ${darkRows})"
          last_row="≡ Show every theme"
        fi

        choice="$(printf '%s\n' \
          "$dark_mark Dark" \
          "$light_mark Light" \
          "$auto_mark Match the system — currently $eff" \
          "$rows" \
          "$last_row" \
          | wofi --dmenu --prompt "Theme" --insensitive)" || exit 0

        case "$choice" in
          "")
            exit 0
            ;;
          "$dark_mark Dark")
            theme-mode dark
            exit 0
            ;;
          "$light_mark Light")
            theme-mode light
            exit 0
            ;;
          "$auto_mark Match the system"*)
            theme-mode auto
            exit 0
            ;;
          "≡ Show every theme")
            show_all=1
            ;;
          "≡ Only "*)
            show_all=0
            ;;
          *)
            # The rows are "<id> — <description>"; no palette id contains a
            # space, so cutting at the first one recovers the id.
            theme-apply "''${choice%% *}"
            exit 0
            ;;
        esac
      done
    '';
  };

  # Wallpaper: awww daemon plus a picker over ~/.local/share/wallpapers.
  # The chosen path is remembered so it can be restored at login.
  wallpaperSet = pkgs.writeShellApplication {
    name = "wallpaper-set";
    runtimeInputs = with pkgs; [
      awww
      libnotify
    ];
    text = ''
      img="''${1:-}"
      [ -z "$img" ] && { echo "usage: wallpaper-set <image>" >&2; exit 2; }
      [ -f "$img" ] || { echo "no such file: $img" >&2; exit 1; }

      # Start the daemon if it isn't already up.
      awww query >/dev/null 2>&1 || { awww-daemon & sleep 0.5; }

      awww img "$img" \
        --transition-type grow \
        --transition-pos center \
        --transition-duration 1 \
        --transition-fps 60

      mkdir -p "${stateDir}"
      printf %s "$img" > "${stateDir}/wallpaper"
    '';
  };
wallpaperMenu = pkgs.writeShellApplication {
  name = "wallpaper-menu";

  runtimeInputs = with pkgs; [
    wofi
    findutils
    coreutils
    imagemagick
    libnotify
    util-linux
    wallpaperSet
  ];

  text = ''
    dir="${wallpaperDir}"
    [ -d "$dir" ] || {
      echo "no wallpaper dir: $dir" >&2
      exit 1
    }

    cache="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-menu"
    entries="$(mktemp)"
    images="$(mktemp)"

    mkdir -p "$cache"
    trap 'rm -f "$entries" "$images"' EXIT

    find -L "$dir" -type f \
      \( -iname '*.png' \
      -o -iname '*.jpg' \
      -o -iname '*.jpeg' \
      -o -iname '*.webp' \) \
      -print 2>/dev/null |
      sort > "$images"

    [ -s "$images" ] || {
      echo "no wallpapers found in: $dir" >&2
      exit 1
    }

    # Generate every missing preview. The function scans the wallpaper
    # directory itself so it remains safe when run in the background after
    # this menu invocation exits.
    build_missing_previews() {
      while IFS= read -r img; do
        stamp="$(stat -c '%Y:%s' "$img")"
        key="$(
          printf '%s\0%s' "$img" "$stamp" |
            sha256sum |
            cut -d ' ' -f1
        )"

        thumb="$cache/$key.jpg"
        [ -f "$thumb" ] && continue

        tmp="$cache/.$key.$$.tmp.jpg"

        if magick "$img" -auto-orient \
            -thumbnail '320x180^' \
            -gravity center \
            -extent 320x180 \
            -strip \
            -quality 85 \
            "$tmp" 2>/dev/null; then
          mv -f "$tmp" "$thumb"
        else
          rm -f "$tmp"
        fi
      done < <(
        find -L "$dir" -type f \
          \( -iname '*.png' \
          -o -iname '*.jpg' \
          -o -iname '*.jpeg' \
          -o -iname '*.webp' \) \
          -print 2>/dev/null |
          sort
      )
    }

    # Determine how much work is waiting before deciding which picker layout
    # to show.
    missing_count=0

    while IFS= read -r img; do
      stamp="$(stat -c '%Y:%s' "$img")"
      key="$(
        printf '%s\0%s' "$img" "$stamp" |
          sha256sum |
          cut -d ' ' -f1
      )"

      [ -f "$cache/$key.jpg" ] ||
        missing_count=$((missing_count + 1))
    done < "$images"

    if [ "$missing_count" -ge 10 ]; then
      # Only one invocation may build at a time. The notification happens
      # after acquiring the lock, so opening the picker twice does not produce
      # duplicate builders or duplicate notifications.
      (
        flock -n 9 || exit 0

        notify-send \
          -a wallpaper-menu \
          -i preferences-desktop-wallpaper \
          -t 6000 \
          "Wallpaper picker" \
          "The wallpaper widget is building its cache. This may take a moment." \
          || true

        build_missing_previews
      ) 9> "$cache/.build.lock" &

      # While the cache is cold, open immediately as a plain searchable list.
      # Selection still resolves to the same wallpaper path.
      while IFS= read -r img; do
        rel="''${img#"$dir"/}"
        printf '%s\n' "$rel" >> "$entries"
      done < "$images"

      choice="$(
        wofi --dmenu \
          --prompt "Wallpaper · previews building" \
          --insensitive \
          --no-custom-entry \
          --cache-file /dev/null \
          --width 55% \
          --lines 12 \
          --columns 1 \
          < "$entries" ||
          true
      )"
    else
      # A small amount of missing work is quick enough to finish before
      # opening the normal thumbnail grid.
      build_missing_previews

      while IFS= read -r img; do
        rel="''${img#"$dir"/}"
        stamp="$(stat -c '%Y:%s' "$img")"
        key="$(
          printf '%s\0%s' "$img" "$stamp" |
            sha256sum |
            cut -d ' ' -f1
        )"

        thumb="$cache/$key.jpg"
        preview="$img"
        [ -f "$thumb" ] && preview="$thumb"

        printf 'img:%s:text:%s\n' \
          "$preview" \
          "$rel" >> "$entries"
      done < "$images"

      choice="$(
        wofi --dmenu \
          --prompt "Wallpaper" \
          --insensitive \
          --allow-images \
          --parse-search \
          --no-custom-entry \
          --cache-file /dev/null \
          --width 80% \
          --lines 3 \
          --columns 4 \
          --define=image_size=180 \
          < "$entries" ||
          true
      )"

      # Image-grid mode may return the complete Wofi image escape.
      choice="''${choice#*:text:}"
    fi

    [ -n "$choice" ] && wallpaper-set "$dir/$choice"
  '';
};
 
  wallpaperRandom = pkgs.writeShellApplication {
    name = "wallpaper-random";
    runtimeInputs = with pkgs; [
      findutils
      coreutils
      wallpaperSet
    ];
    text = ''
      dir="${wallpaperDir}"
      [ -d "$dir" ] || exit 0
      pick="$(find -L "$dir" -type f \
                \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
              2>/dev/null | shuf -n1)"
      [ -n "$pick" ] && wallpaper-set "$pick"
    '';
  };

  # Restore the remembered wallpaper at login.
  #
  # Three steps, most specific first: whatever was last picked, then the
  # default (see `defaultWallpaper`), then a random one. The middle step is
  # what makes a fresh account — or a machine where the state file hasn't been
  # written yet, which includes the first login after an install — land on a
  # known image instead of whichever of the collection `shuf` happened to
  # reach for. The random step stays as the last resort for a dotfiles tree
  # that no longer carries the default.
  #
  # It does not overrule a choice: `wallpaper-set` writes the state file, so
  # anything picked from `Mod+Ctrl+W` wins on every login after it.
  wallpaperRestore = pkgs.writeShellApplication {
    name = "wallpaper-restore";
    runtimeInputs = [
      pkgs.awww
      wallpaperSet
      wallpaperRandom
    ];
    text = ''
      awww query >/dev/null 2>&1 || { awww-daemon & sleep 0.5; }
      saved="$(cat "${stateDir}/wallpaper" 2>/dev/null || echo "")"
      if [ -n "$saved" ] && [ -f "$saved" ]; then
        wallpaper-set "$saved"
      elif [ -f "${defaultWallpaper}" ]; then
        wallpaper-set "${defaultWallpaper}"
      else
        wallpaper-random
      fi
    '';
  };

  screenshotDir = "${config.home.homeDirectory}/Pictures/Screenshots";

  # Where the last selected region is remembered. Its own directory rather
  # than niri-theme/ next to the wallpaper: that one is named for the theme
  # state it holds, and a screenshot region isn't part of a theme.
  screenshotStateDir = "${config.home.homeDirectory}/.local/state/niri-screenshot";

  # Which annotation editor `screenshotAnnotate` opens. Only the noctalia path
  # reads it — the waybar `screenshot` helper below is built around satty's
  # ability to write the finished file itself, which is the part spectacle has
  # no command-line equivalent for. See local.niri.screenshotEditor.
  screenshotEditor = config.local.niri.screenshotEditor;

  # Annotated region capture: the screen freezes, slurp selects, grim captures,
  # satty annotates and writes the result.
  #
  # This is the waybar session's screenshot. Under noctalia the shell captures
  # instead — `noctalia msg screenshot-region`, freezing and selecting and
  # remembering the last region itself — and only the annotate-and-save tail
  # survives, as `screenshotAnnotate` below. See ./noctalia.nix.
  #
  # Plain screen and window captures are bound straight to niri's built-in
  # `screenshot-screen` / `screenshot-window` actions instead — the compositor
  # already knows the exact geometry, so there's nothing for a script to
  # compute and get wrong.
  #
  # Two modes:
  #
  #   screenshot          select a region, remember it, capture it
  #   screenshot last     capture the remembered region again, no selection
  #
  # `last` is for the repeat case — the same panel or window region, shot over
  # and over, where redrawing the selection by hand each time is the tedious
  # part and is also what makes the frames not line up.
  #
  # slurp has no way to *pre-fill* a selection, which is why this is a separate
  # mode rather than "reopen slurp with last time's box ready to nudge". Its
  # `-r` reads boxes on stdin and restricts the selection to them, so feeding
  # it the saved region would let you click that box to accept it but never
  # drag its edges — a worse version of `last`, with an extra click.
  #
  # The saved geometry is grim's own `X,Y WxH`, straight from slurp and passed
  # back to grim unparsed. Nothing here needs to understand it, so nothing here
  # can misparse it.
  #
  # The freeze in front of the selection is wayfreeze, and it is there because
  # selecting and capturing are two different moments: everything the region is
  # usually drawn around — a video, an animation, a menu that closes when it
  # loses focus, a tooltip — has had time to move on by the time grim runs.
  # Freezing first makes the frame you selected the frame you get.
  # `local.niri.screenshotFreeze` turns it off; `last` never needs it, having no
  # selection to draw.
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs =
      (with pkgs; [
        grim
        slurp
        satty
        wl-clipboard
        libnotify
        coreutils
      ])
      ++ lib.optional config.local.niri.screenshotFreeze pkgs.wayfreeze;
    text = ''
      mkdir -p "${screenshotDir}" "${screenshotStateDir}"
      region="${screenshotStateDir}/region"
      mode="''${1:-select}"

      # Month-day-year on a 12-hour clock, matching niri's own
      # `screenshot-path` and every other clock in the session. The cost is
      # that filenames no longer sort chronologically; "%Y-%m-%d_%H-%M-%S"
      # is the string to put back in both places if that matters more.
      stamp="$(date '+%m-%d-%Y_%I-%M-%S-%p')"
      out="${screenshotDir}/screenshot_$stamp.png"

      # grim writes to a file rather than down a pipe into satty, so that a
      # geometry it rejects is catchable here. Piping would only surface as a
      # pipefail exit after satty had already been handed nothing.
      shot="$(mktemp -t screenshot-XXXXXXXX.png)"
      trap 'rm -f "$shot"' EXIT

      geom=""
      if [ "$mode" = "last" ]; then
        geom="$(cat "$region" 2>/dev/null || true)"
      fi

      # A remembered region can stop being valid — a monitor unplugged, or the
      # layout rearranged under it. Fall through to a fresh selection rather
      # than failing, since the point of the key is to be quick.
      if [ -n "$geom" ] && ! grim -g "$geom" "$shot" 2>/dev/null; then
        notify-send -a screenshot \
          "Screenshot" "Last region isn't on screen any more — select a new one."
        geom=""
      fi

      if [ -z "$geom" ]; then
        ${lib.optionalString config.local.niri.screenshotFreeze ''
          # Hold the screen still for the length of the selection. wayfreeze
          # screencopies every output and paints the copies straight back as
          # overlay layer surfaces, so slurp draws its box over a still frame
          # and the grim below captures that same frame rather than whatever
          # the screen has moved on to.
          #
          # --hide-cursor keeps the pointer out of the copy. Left in, it would
          # be painted into the still frame with the live pointer drawn over
          # the top of it, and a capture across that spot would show two.
          #
          # --enable-keyboard reads backwards and isn't: it means "let the
          # keyboard through to other surfaces", and without it wayfreeze asks
          # for exclusive keyboard focus itself. niri gives exclusive focus to
          # the *lowest* layer surface asking for it, which is the freeze and
          # not slurp, so Escape would dismiss the freeze and leave slurp
          # selecting over a live screen. With it, slurp keeps the keyboard and
          # Escape cancels the screenshot, which is what Escape should do.
          frozen="$shot.frozen"
          wayfreeze --hide-cursor --enable-keyboard \
            --after-freeze-cmd "touch '$frozen'" &
          freezer=$!

          # Replaces the trap set above, and has to: from here a still frame is
          # covering the session, and every way out of this script — cancelled
          # selection included — has to take it back down.
          trap 'rm -f "$shot" "$frozen"; kill "$freezer" 2>/dev/null || true' EXIT

          # slurp has to map *after* the freeze. niri stacks layer surfaces in
          # the order they map and sends the click to the top one, so a slurp
          # that got there first would sit under the still frame and the drag
          # would go to wayfreeze instead. --after-freeze-cmd runs once every
          # output's surface is configured, so that touch is the signal that
          # it's safe to go; a fixed sleep would be a guess at how long
          # screencopying however many displays takes.
          #
          # Bounded, and abandoned early if wayfreeze is gone, because a freeze
          # that never arrives should cost a selection over the live screen and
          # nothing more.
          waited=0
          while [ ! -e "$frozen" ] && [ "$waited" -lt 60 ] && kill -0 "$freezer" 2>/dev/null; do
            sleep 0.025
            waited=$((waited + 1))
          done
        ''}
        # Cancelled selection exits non-zero; that's not an error.
        geom="$(slurp -d -b '#0a0e0acc' -c '#39ff14' -s '#39ff1420' -w 2)" || exit 0
        grim -g "$geom" "$shot"
        ${lib.optionalString config.local.niri.screenshotFreeze ''
          # The pixels are in hand, so put the live screen back before satty
          # opens — the editor belongs over the session, not over a photograph
          # of it, and satty is where the time goes.
          kill "$freezer" 2>/dev/null || true
        ''}

        # Only after grim accepts it, so a region that can't be captured is
        # never the one `last` comes back to.
        printf %s "$geom" > "$region"
      fi

      # `--disable-notifications` because satty posts its own desktop
      # notification on save — "File saved to '<path>'.", with a thumbnail of
      # the annotated image — and the notify-send below says the same thing in
      # this session's own wording. Left on, every save arrives twice. Ours is
      # the one kept: it is app-named `screenshot` rather than `Satty`, it
      # names the file rather than the whole path, and it is the same
      # notification the spectacle path sends, so the two editors don't
      # announce a save differently.
      satty --filename "$shot" \
        --output-filename "$out" \
        --early-exit \
        --disable-notifications \
        --copy-command wl-copy

      if [ -f "$out" ]; then
        notify-send -a screenshot -i "$out" "Screenshot" "Saved $(basename "$out")"
      fi
    '';
  };

  # What noctalia pipes each capture into. It is the annotate-and-save tail of
  # the `screenshot` script above, kept because noctalia's own screenshot
  # service captures and delivers but does not annotate: it hands the PNG to
  # one shell command on stdin and lets that command decide what the picture
  # becomes.
  #
  # So noctalia is told to neither save nor copy (see ./noctalia.nix) and this
  # does both, through the editor `local.niri.screenshotEditor` names. With
  # satty that is exactly what the region script always did — same editor, same
  # `--early-exit`, same wl-copy on save, same notification with the shot as
  # its icon. Spectacle is the other choice and is a different shape: it cannot
  # read stdin, so the PNG is written to its destination first and spectacle is
  # opened on that file, which means the capture is saved whether or not the
  # editor is ever used and spectacle's own Save is what overwrites it.
  #
  # `$NOCTALIA_SCREENSHOT_PATH` is the path noctalia computed for this capture
  # and exported into the command's environment: directory and filename pattern
  # stay noctalia's settings rather than being spelled a second time here, and
  # what satty writes lands where noctalia would have written it. Empty would
  # mean noctalia had nothing to save to, which is not a case its own settings
  # can produce here, but a satty invoked with an empty --output-filename would
  # fail obscurely, so it is checked.
  screenshotAnnotate = pkgs.writeShellApplication {
    name = "screenshot-annotate";
    runtimeInputs =
      (with pkgs; [
        wl-clipboard
        libnotify
        coreutils
      ])
      ++ (
        if screenshotEditor == "spectacle" then
          [
            pkgs.kdePackages.spectacle
            pkgs.util-linux # setsid
          ]
        else
          [ pkgs.satty ]
      );
    text = ''
      out="''${NOCTALIA_SCREENSHOT_PATH:-}"
      if [ -z "$out" ]; then
        notify-send -a screenshot -u critical \
          "Screenshot" "Noctalia passed no output path — nothing was saved."
        exit 1
      fi

      mkdir -p "$(dirname "$out")"

      ${
        if screenshotEditor == "spectacle" then
          ''
            # spectacle only opens files, so the pipe is spent here rather than
            # handed on. `cat` and not a redirect alone because the exit status
            # of the write is what decides whether there is anything to edit.
            cat > "$out"

            # The clipboard is filled from here too: spectacle's editor has its
            # own copy action but nothing that can be asked for one from the
            # command line, so without this a capture would reach the clipboard
            # only if you remembered to press it.
            wl-copy --type image/png < "$out"

            notify-send -a screenshot -i "$out" "Screenshot" "Saved $(basename "$out")"

            # Not waited on: spectacle is a session-lifetime KDE application
            # with no `--early-exit` of its own, and noctalia keeps a thread
            # blocked on this command until it returns.
            setsid spectacle --edit-existing "$out" >/dev/null 2>&1 &
          ''
        else
          ''
            # `--filename -` reads the PNG on stdin, which is how noctalia hands
            # it over.
            #
            # `--disable-notifications` for the reason given on the waybar
            # script's satty call: satty announces its own saves, and the
            # notify-send below already announces this one. Noctalia is not the
            # other half of the pair here — it is told to neither save nor copy
            # (see ./noctalia.nix) and its screenshot service only notifies for
            # the outputs it performed itself, so a capture that is piped and
            # nothing else passes through it silently.
            satty --filename - \
              --output-filename "$out" \
              --early-exit \
              --disable-notifications \
              --copy-command wl-copy

            # Absent when the editor was closed without saving, which is a
            # cancel and not a failure — the same reason the old script tested
            # for the file.
            if [ -f "$out" ]; then
              notify-send -a screenshot -i "$out" "Screenshot" "Saved $(basename "$out")"
            fi
          ''
      }
    '';
  };

  # Lock the session. Colours come from the active theme's swaylock.env, so
  # the lock screen follows whatever theme is current.
  #
  # `--color` is the flat colour swaylock paints *underneath* the screenshot
  # background, and it is what you actually see whenever there is no
  # screenshot to draw over it. Its default is white, so leaving it off is
  # what made the lock screen come up blank white with a monitor powered off.
  #
  # `--screenshots` captures each output through wlr-screencopy at lock time,
  # and a capture of an output that is currently blanked fails. In the
  # packaged fork (jirutka's swaylock-effects 1.7.0.0) that failure handler
  # clears `args.screenshots` on the shared state rather than on the one
  # surface that failed, so a single blanked monitor takes the screenshot
  # background away from *every* display — hence full white everywhere, not
  # just on the display that was off. Pointing --color at the theme
  # background turns that fallback into a themed solid colour.
  #
  # It's reachable in normal use because the blank and the lock are
  # independent: Mod+Escape blanks on demand, Mod+Shift+L does both at once,
  # and swayidle blanks at 600s and locks before sleep, so "outputs off" and
  # "now lock" overlap easily.
  #
  # niri's `layout { background-color }` has no bearing on this. That is the
  # backdrop behind windows; swaylock's own surface covers it.
  #
  # The `%n` in `--datestr` is the line break that stacks the weekday over the
  # month and day. Stock swaylock would draw it as a literal newline character
  # in one row; reading it as a break is the patch on `swaylock` above, which
  # is also what keeps the date from overhanging. See the comment there.
  #
  # Thickness moves 8 → 9 with the radius (110 → 130) only to hold the ring's
  # weight steady; at 8 a 130 ring reads visibly thinner than the 110 one did.
  # What is playing, for the whole lock screen, from one MPRIS round trip that
  # every widget on every monitor shares.
  #
  # Everything on this screen that knows about music — the track label, the
  # three transport buttons under it, the cover card, the background behind
  # both and the frame around the password field — has to give the same
  # answer, or a cover from one player ends up under a title from another and
  # a button skips a third. That is why this is one fragment rather than a
  # loop copied into each script.
  #
  # It is also why it is *cached*. A widget with no `monitor` is built once per
  # output (Renderer.cpp, getOrCreateWidgetsFor), so on the desk there are
  # three backgrounds, three covers, three field frames, three track labels and
  # nine transport buttons, each with its own timer, and all of them asking the
  # same question within a few hundred milliseconds of each other. Asking MPRIS
  # once per widget cost around fifty playerctl processes every three seconds,
  # most of the weight of it on Hyprlock's render thread, where `reload_cmd`
  # runs through spawnSync. Now the first one to find the answer stale fetches
  # it and the rest read a file.
  #
  # The window is shorter than every timer that asks, so a tick never serves a
  # previous tick's answer — it only ever covers the burst of widgets firing
  # together.
  #
  # One call rather than the four this used to take, too: `--all-players` with
  # a format string returns every player's name, status and metadata in one
  # go, because playerctl's format context carries `playerName` and `status`
  # alongside the metadata fields (playerctl-formatter.c).
  #
  # Prefer a playing player. When nothing is actively playing, retain the
  # first paused track so the lock screen still reflects the current media
  # session. Leaves `player` empty when there is nothing to show, which makes
  # every caller here fall back to what it shows without music.
  #
  # The `timeout` is not defensive programming for its own sake: this is a
  # D-Bus call into other desktop applications, and a player that has stopped
  # answering — a hung browser tab is the usual one — blocks its caller for
  # D-Bus's own 25s default. Two of the callers cannot afford that: one runs on
  # the path that has to lock the screen before the machine suspends, and one
  # runs on Hyprlock's render thread. A second is already far longer than an
  # answer takes.
  mprisSnapshot = ''
    mpris_cache="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprlock-track"

    # Seconds an answer is reused for. See above: below every interval that
    # asks (the track label's 1.5s is the shortest), above the spread of one
    # burst.
    mpris_cache_seconds=1

    player=""
    player_status=""
    art_url=""
    media_url=""
    artist=""
    title=""

    # Only the fields, and only in this order: the two that can hold anything
    # a tagger allowed go last, so a stray delimiter inside one of them can
    # shift nothing but the other.
    mpris_format='{{playerName}}|||{{status}}|||{{mpris:artUrl}}|||{{xesam:url}}|||{{artist}}|||{{title}}'

    mpris_from_cache() {
      local stamp age

      [ -r "$mpris_cache" ] || return 1

      {
        read -r stamp
        read -r player
        read -r player_status
        read -r art_url
        read -r media_url
        read -r artist
        read -r title
      } < "$mpris_cache" || true

      case "$stamp" in
        "" | *[!0-9]*) return 1 ;;
      esac

      # A clock that went backwards leaves an answer from the future, which is
      # not fresh, it is unreadable.
      age=$(( EPOCHSECONDS - stamp ))
      [ "$age" -ge 0 ] || return 1
      [ "$age" -le "$mpris_cache_seconds" ] || return 1
    }

    mpris_query() {
      local line rest name status arturl mediaurl
      local paused_player="" paused_status="" paused_art=""
      local paused_media="" paused_artist="" paused_title=""

      player=""
      player_status=""
      art_url=""
      media_url=""
      artist=""
      title=""

      while IFS= read -r line || [ -n "$line" ]; do
        # Anything without the delimiters in it did not come from the format
        # above — a newline inside a title, most likely.
        rest="''${line#*|||}"
        [ "$rest" != "$line" ] || continue

        name="''${line%%|||*}"
        status="''${rest%%|||*}"
        rest="''${rest#*|||}"
        arturl="''${rest%%|||*}"
        rest="''${rest#*|||}"
        mediaurl="''${rest%%|||*}"
        rest="''${rest#*|||}"

        case "$status" in
          Playing)
            player="$name"
            player_status="$status"
            art_url="$arturl"
            media_url="$mediaurl"
            artist="''${rest%%|||*}"
            title="''${rest#*|||}"
            break
            ;;

          Paused)
            if [ -z "$paused_player" ]; then
              paused_player="$name"
              paused_status="$status"
              paused_art="$arturl"
              paused_media="$mediaurl"
              paused_artist="''${rest%%|||*}"
              paused_title="''${rest#*|||}"
            fi
            ;;
        esac
      done < <(
        timeout 1 playerctl --all-players metadata --format "$mpris_format" \
          2>/dev/null || true
      )

      if [ -z "$player" ]; then
        player="$paused_player"
        player_status="$paused_status"
        art_url="$paused_art"
        media_url="$paused_media"
        artist="$paused_artist"
        title="$paused_title"
      fi

      # Only the schemes the fetcher can resolve. `data:` URLs are left out on
      # purpose: a handful of players inline an entire JPEG there, and it would
      # travel through a cache file to save one local read.
      case "$art_url" in
        http://* | https://* | file://*) ;;
        *) art_url="" ;;
      esac
    }

    mpris_write() {
      local tmp="$mpris_cache.$$.tmp"

      printf '%s\n' \
        "$EPOCHSECONDS" "$player" "$player_status" "$art_url" "$media_url" \
        "$artist" "$title" > "$tmp"

      mv -f "$tmp" "$mpris_cache"
    }

    mpris_snapshot() {
      if ! mpris_from_cache; then
        mpris_query
        mpris_write
      fi
    }
  '';

  # A short-lived MPRIS query for the lock screen.
  #
  # No player means no output, which makes Hyprlock hide the label.
lockNowPlaying = pkgs.writeShellApplication {
  name = "lock-now-playing";

  runtimeInputs = with pkgs; [
    playerctl
    coreutils
  ];

  text = ''
    ${readLockColors}
    ${mprisSnapshot}

    # Everything below used to be four playerctl calls of its own — status,
    # artist and title, player name, media URL. They are all in the one
    # snapshot now, which on a cache hit costs no processes at all.
    mpris_snapshot

    [ -n "$player" ] || exit 0
    [ -n "$title" ] || exit 0

    status="$player_status"

    # Remove instance suffixes such as firefox.instance123 and normalize case.
    source="''${player,,}"
    source="''${source%%.*}"

    case "$media_url" in
      *open.spotify.com/* | spotify:*)
        source="spotify"
        ;;
      *music.youtube.com/*)
        source="youtube-music"
        ;;
      *youtube.com/* | *youtu.be/*)
        source="youtube"
        ;;
    esac

    case "$source" in
      spotify | spotifyd)
        player_icon=""
        ;;

      firefox)
        player_icon="󰈹"
        ;;

      chromium | chrome | google-chrome)
        player_icon=""
        ;;

      brave | brave-browser)
        player_icon="󰖟"
        ;;

      vivaldi | vivaldi-stable)
        player_icon="󰖟"
        ;;

      mpv)
        player_icon=""
        ;;

      vlc)
        player_icon="󰕼"
        ;;

      cider | cider-2)
        player_icon=""
        ;;

      youtube | youtube-music)
        player_icon=""
        ;;

      cmus | mpd | rhythmbox | strawberry | amberol)
        player_icon="󰎆"
        ;;

      *)
        player_icon="󰎆"
        ;;
    esac

    case "$status" in
      Playing)
        status_text=""
        ;;
      Paused)
        status_text="  "
        ;;
      *)
        exit 0
        ;;
    esac

    if [ -n "$artist" ]; then
      display="$artist · $title"
    else
      display="$title"
    fi

    # Hyprlock labels support markup, so sanitize media metadata before it
    # reaches the generated label.
    #
    # In the shell rather than through tr, sed and cut, which was four
    # processes and a subshell every time a track label redrew. Two other
    # things fall out of doing it here: the truncation happens *before* the
    # escaping, so it can no longer cut an entity in half and take the whole
    # label down to plain text, and it counts characters rather than bytes, so
    # it cannot split one either.
    display="''${display//[$'\r\n\t']/ }"

    while [ "$display" != "''${display//  / }" ]; do
      display="''${display//  / }"
    done

    display="''${display:0:100}"

    # Ampersands first, or the escapes escape each other; and each `&` in the
    # replacement is backslashed because bash reads a bare one as the text the
    # pattern matched.
    display="''${display//&/\&amp;}"
    display="''${display//</\&lt;}"
    display="''${display//>/\&gt;}"

    # Wrapped in the current colour, for the same reason as `lock-label`: a
    # colour cannot reach a Hyprlock label any other way once it is running.
    printf '<span foreground="#%s">%s%s  %s</span>\n' \
      "$LOCK_FG" \
      "$player_icon" \
      "$status_text" \
      "$display"
  '';
};

  # One transport control on the lock screen: previous, play/pause or next.
  #
  # A button rather than a row, called once per control, because a Hyprlock
  # label carries a single `onclick` and the area that catches it is the
  # label's own text — three controls have to be three labels.
  #
  # No player means no output, and a label with no text draws nothing and has
  # no box for a click to land in, so the row is simply not there on a lock
  # screen with no music. That is the same mechanism the track name above it
  # already runs on, and it is why the controls need no separate "is anything
  # playing" test in the config.
  #
  # Gated on exactly what the track name is gated on — a player, a title, and
  # a status of Playing or Paused — so the two can never disagree about
  # whether there is a media session worth showing.
  lockMediaButton = pkgs.writeShellApplication {
    name = "lock-media-button";

    runtimeInputs = with pkgs; [
      playerctl
      coreutils
    ];

    text = ''
      ${readLockColors}
      ${mprisSnapshot}

      # The names are playerctl's own commands, so the button a label draws
      # and the argument its `onclick` passes to `lock-media-control` are the
      # same word.
      case "''${1:-}" in
        previous | play-pause | next)
          button="$1"
          ;;
        *)
          echo "lock-media-button: want previous, play-pause or next" >&2
          exit 2
          ;;
      esac

      mpris_snapshot

      [ -n "$player" ] || exit 0
      [ -n "$title" ] || exit 0

      case "$player_status" in
        Playing | Paused) ;;
        *) exit 0 ;;
      esac

      case "$button" in
        previous)
          glyph=""
          ;;

        next)
          glyph=""
          ;;

        # The action, not the state: a button says what clicking it will do,
        # which is the opposite of the marker in the track name beside it —
        # that one is a pause glyph *because* the player is paused. Both are
        # conventional and neither reads as the other in place.
        play-pause)
          case "$player_status" in
            Playing) glyph="" ;;
            *)       glyph="" ;;
          esac
          ;;
      esac

      # In the colour of whatever is playing, for the reason given on
      # `lock-label`: a colour cannot reach a Hyprlock label any other way
      # once it is running. Nothing here needs escaping — every glyph above is
      # a private-use codepoint, and none of them is markup.
      printf '<span foreground="#%s">%s</span>\n' "$LOCK_FG" "$glyph"
    '';
  };

  # What the buttons above do when clicked.
  #
  # Aimed at a named player rather than left to playerctl's "first available"
  # default. The lock screen has already chosen one out of however many are
  # registered — a playing one, else the first paused one — and it is that
  # player's cover and title on the screen, so a button beneath them that
  # skipped a different player's queue would be lying about what it controls.
  #
  # Hyprlock runs `onclick` detached, so this is not on the render thread; the
  # `timeout` is here for the same reason as the ones in the snapshot, which
  # is that a wedged player would otherwise hold this process for D-Bus's own
  # 25-second default.
  lockMediaControl = pkgs.writeShellApplication {
    name = "lock-media-control";

    runtimeInputs = with pkgs; [
      playerctl
      coreutils
    ];

    text = ''
      ${mprisSnapshot}

      case "''${1:-}" in
        previous | play-pause | next)
          action="$1"
          ;;
        *)
          echo "lock-media-control: want previous, play-pause or next" >&2
          exit 2
          ;;
      esac

      mpris_snapshot

      # Nothing playing, nothing to do. Reachable in principle if a player
      # disappears between the tick that drew the button and the click on it,
      # and it is also what makes a stray click on an empty label harmless.
      [ -n "$player" ] || exit 0

      # Instance first, then the bare application name, as one priority list:
      # `--player` takes a comma-separated list and acts on the *first* entry
      # that matches, so this prefers the exact instance the snapshot named —
      # `firefox.instance123` rather than whichever Firefox answers first —
      # without any risk of firing the action twice, which two separate calls
      # in a fallback chain would carry.
      players="$player,''${player%%.*}"

      if ! timeout 1 playerctl --player="$players" "$action"; then
        echo "lock-media-control: $action went nowhere ($player)" >&2
      fi

      # The snapshot on disk describes the track as it was before the click.
      # Dropping it means the next widget tick asks MPRIS itself rather than
      # serving that answer, so the play/pause glyph, the track name, the
      # cover and the colours all follow the click on their own next tick
      # instead of a cache lifetime after it.
      rm -f "$mpris_cache"
    '';
  };

  # The colours the lock screen is wearing *at this moment*, written down where
  # anything drawing part of that screen can read them without asking MPRIS.
  #
  # There is one writer — `lock-album-art`, which Hyprlock already runs every
  # few seconds to find the current cover — and several readers, one per label,
  # several times a second. Having the readers work it out for themselves would
  # mean a D-Bus round trip per label per tick, and would let two labels
  # disagree mid-track-change. A file in the runtime directory is a few
  # microseconds and one answer.
  lockColorsPath = ''
    lock_colors="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprlock-colors"
  '';

  # The theme's lock colours, as `LOCK_*` shell variables.
  #
  # Sourced, unlike the album palette below, because this one is a store path:
  # it is written by a derivation and cannot be edited by anything that isn't
  # already rebuilding the system.
  lockThemeColors = ''
    # shellcheck disable=SC1091
    if [ -r "${activeDir}/swaylock.env" ]; then
      . "${activeDir}/swaylock.env"
    fi

    : "''${LOCK_BG:=0a0e0a}"
    : "''${LOCK_ACCENT:=39ff14}"
    : "''${LOCK_ACCENT_DIM:=1f8b0d}"
    : "''${LOCK_FG:=c8f5c8}"
    : "''${LOCK_FG_DIM:=5c7a5c}"
    : "''${LOCK_ERR:=ff5555}"
    : "''${LOCK_WARN:=f5d76e}"
  '';

  # An album's colours over whatever is already set, given a file that may hold
  # some. `LOCK_ERR` and `LOCK_WARN` are deliberately not in the list: an error
  # is red and a caps-lock warning is yellow whatever happens to be playing.
  #
  # Read rather than sourced, one known key at a time and only when the value
  # is six hex digits. These files are ours and hold nothing else, but they
  # live in a cache directory rather than in the store, and one of the callers
  # is the script standing between a locked session and the desktop.
  lockPaletteColors = ''
    lock_palette_colors() {
      local key value

      [ -n "$1" ] || return 0
      [ -r "$1" ] || return 0

      while IFS='=' read -r key value; do
        case "$value" in
          [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
          *) continue ;;
        esac

        # Every colour, whether or not this particular caller wants it: the
        # ones a script doesn't read are still the ones it would have to add
        # here if it ever did.
        # shellcheck disable=SC2034
        case "$key" in
          LOCK_BG)         LOCK_BG="$value" ;;
          LOCK_ACCENT)     LOCK_ACCENT="$value" ;;
          LOCK_ACCENT_DIM) LOCK_ACCENT_DIM="$value" ;;
          LOCK_FG)         LOCK_FG="$value" ;;
          LOCK_FG_DIM)     LOCK_FG_DIM="$value" ;;
        esac
      done < "$1"
    }
  '';

  # The colours labels should use at runtime. Album colours only participate
  # when the album-art background does; the independent cover-card option may
  # still show the sleeve without repainting any text.
  readLockColors = ''
    ${lockThemeColors}

    ${lib.optionalString lockAlbumArtBackground ''
      ${lockColorsPath}
      ${lockPaletteColors}

      lock_palette_colors "$lock_colors"
    ''}
  '';

  # Where rendered album art lives, and how a track maps onto a file name.
  # Shared by the two scripts below so that neither has to ask the other.
  #
  # Keyed by the cover URL rather than by artist and title, because the URL is
  # what the rendering actually depends on: hashing it gives a name that is
  # safe in a Hyprlang path, stable across locks — the second lock during the
  # same song does no work at all — and different for two albums that happen
  # to share a title.
  albumArtPaths = ''
    art_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/niri/album-art"

    # <cover url> -> every file that cover is filed under, as variables.
    #
    # Assignments rather than an answer per question: this is on the path
    # Hyprlock blocks its render thread for, and a function that printed would
    # cost a subshell per path — six forks to build six strings.
    # All of them, whether or not a given caller wants all of them: the ones a
    # script doesn't read are still the ones it would have to add here if it
    # ever did.
    # shellcheck disable=SC2034
    art_paths() {
      local sum

      sum="$(printf '%s' "$1" | sha256sum)"
      art_key="''${sum:0:32}"

      art_backdrop="$art_cache/$art_key.backdrop.jpg"
      art_cover="$art_cache/$art_key.cover.png"
      art_field="$art_cache/$art_key.field.png"
      art_palette="$art_cache/$art_key.palette"
      art_lock="$art_cache/.$art_key.lock"
      art_source="$art_cache/.$art_key.source"
    }
  '';

  # The wallpaper, behind a fixed, punctuation-free path.
  #
  # Hyprlang reads `path =` to the end of the line and does no quoting or
  # escaping of its own, so a wallpaper named `Sunset #2 (final).png` cannot
  # be pointed at directly — the `#` starts a comment. The symlink is what the
  # config names instead. Prints nothing when there is no usable wallpaper,
  # which leaves Hyprlock on the flat themed `color` underneath.
  hyprlockWallpaper = ''
    hyprlock_wallpaper() {
      local wallpaper extension link

      wallpaper="$(cat "${stateDir}/wallpaper" 2>/dev/null || true)"
      [ -n "$wallpaper" ] || return 0
      [ -f "$wallpaper" ] || return 0

      extension="$(
        printf %s "''${wallpaper##*.}" |
          tr '[:upper:]' '[:lower:]'
      )"

      case "$extension" in
        png | jpg | jpeg | webp) ;;
        *) return 0 ;;
      esac

      link="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprlock-wallpaper.$extension"
      ln -sfn -- "$wallpaper" "$link" || return 0

      printf '%s\n' "$link"
    }
  '';

  # Something valid for the cover card to point at when nothing is playing.
  #
  # It has to be an image rather than an empty answer. Hyprlock reads an empty
  # `reload_cmd` result as "keep what you have" — both Background.cpp and
  # Image.cpp return early on it — which is the behaviour worth having while a
  # cover is still rendering, and exactly the wrong one when the music has
  # stopped. So the way to take the card off the screen is to hand Hyprlock a
  # picture of nothing. Sized to match the card so nothing is scaled.
  emptyCover =
    pkgs.runCommand "hyprlock-empty-cover.png"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        magick -size 256x256 xc:none png32:$out
      '';

  # Renders the current track's cover into the two shapes the lock screen
  # wants — a blurred full-screen backdrop that stands in for the wallpaper,
  # and a small framed card to sit above the track name — and reads the
  # colours off it that the rest of the lock screen then wears.
  #
  # Run detached, by `lock-album-art` whenever a track turns up that has never
  # been rendered. It downloads and it runs ImageMagick, so it is the half of
  # this that is allowed to take a second; see the comment on `lock-album-art`
  # for why nothing on Hyprlock's clock may. Takes the cover URL, and works it
  # out from MPRIS when run by hand without one.
  lockAlbumArtFetch = pkgs.writeShellApplication {
    name = "lock-album-art-fetch";

    runtimeInputs = with pkgs; [
      coreutils
      curl
      file
      findutils
      gawk
      imagemagick
      playerctl
      util-linux
    ];

    text = ''
      ${albumArtPaths}
      ${lockPaletteColors}
      ${lockFieldFrame}
      ${mprisSnapshot}

      # The caller usually knows the URL already, having just looked it up to
      # discover the render was missing. Without one, work it out.
      art_url="''${1:-}"

      if [ -z "$art_url" ]; then
        mpris_snapshot
      fi

      [ -n "$art_url" ] || exit 0

      # Wherever it came from — MPRIS above, or an argument, which is not
      # necessarily one of ours once this is a command on PATH.
      case "$art_url" in
        http://* | https://* | file://*) ;;
        *)
          echo "lock-album-art-fetch: unsupported cover URL: $art_url" >&2
          exit 2
          ;;
      esac

      art_paths "$art_url"

      render_complete() {
        ${lib.optionalString lockAlbumArtBackground ''
          [ -f "$art_backdrop" ] || return 1
          [ -f "$art_palette" ] || return 1
        ''}
        ${lib.optionalString lockAlbumArtCover ''
          [ -f "$art_cover" ] || return 1
        ''}
        return 0
      }

      if render_complete; then
        exit 0
      fi

      mkdir -p "$art_cache"

      # One worker per track. A second request while the first is still
      # fetching returns rather than queues, because whoever asked is a reload
      # timer that will ask again in a couple of seconds anyway — and two
      # curls racing to write the same cache entry is the one way this could
      # hand Hyprlock a half-written JPEG.
      exec 9>"$art_lock"
      if ! flock -n 9; then
        exit 0
      fi

      # The holder we just queued behind may have finished the job.
      if render_complete; then
        exit 0
      fi

      source_file="$art_source"
      tmp_backdrop="$art_backdrop.tmp"
      tmp_cover="$art_cover.tmp"
      tmp_field="$art_field.tmp"
      tmp_palette="$art_palette.tmp"
      trap '
        rm -f "$source_file" "$tmp_backdrop" "$tmp_cover" "$tmp_field" \
          "$tmp_palette"
      ' EXIT

      case "$art_url" in
        file://*)
          # Percent-decoded, because this arrives as a URL: local players hand
          # back file:///tmp/mpv/Some%20Album.jpg for a file whose name has a
          # space in it.
          local_cover="''${art_url#file://}"
          local_cover="$(printf '%b' "''${local_cover//%/\\x}")"

          if [ ! -f "$local_cover" ]; then
            echo "lock-album-art-fetch: no such cover: $local_cover" >&2
            exit 0
          fi

          # Copied rather than read in place: the player owns that file and is
          # free to delete it on the next track, halfway through the render.
          cp -- "$local_cover" "$source_file"
          ;;

        *)
          # Bounded on every axis, because this runs behind a lock screen on
          # whatever network happens to be there, and a cover is never worth
          # waiting on. `--proto-redir` is the one doing real work: without it
          # a redirect could walk this into file:// and feed a local file of
          # its choosing to the renderer below.
          if ! curl --fail --location --silent --show-error \
              --proto '=http,https' --proto-redir '=http,https' \
              --connect-timeout 5 --max-time 20 \
              --max-filesize 16000000 \
              --output "$source_file" "$art_url"; then
            echo "lock-album-art-fetch: could not fetch $art_url" >&2
            exit 0
          fi
          ;;
      esac

      # The metadata was a claim; this is the check. It also keeps ImageMagick
      # away from the formats that have delegates behind them — an
      # image/svg+xml can name external references, and a cover never is one.
      mime="$(file --brief --mime-type -- "$source_file" 2>/dev/null || true)"

      case "$mime" in
        image/png | image/jpeg | image/webp | image/gif | image/bmp | image/avif) ;;
        *)
          echo "lock-album-art-fetch: $art_url is $mime, not a cover" >&2
          exit 0
          ;;
      esac

      # `[0]` throughout: an animated cover is one image to the lock screen,
      # and without it ImageMagick writes one output file per frame and the
      # moves at the bottom find nothing where they expect a render.

      # What colour the cover is, in one pass, before anything is drawn with
      # it. A twelve-colour histogram of a 100px copy is a cheap and honest
      # summary of a sleeve; `album-palette.awk` turns it into the exposure
      # the backdrop is rendered at and the palette the lock screen wears.
      # Alpha is flattened onto black first, so a transparent PNG cover does
      # not report the colour of nothing.
      if ! magick "''${source_file}[0]" \
          -background black -alpha remove -alpha off \
          -resize 100x100^ -gravity center -extent 100x100 \
          -depth 8 -colors 12 \
          -format %c histogram:info:- |
          gawk -f ${./album-palette.awk} > "$tmp_palette"; then
        echo "lock-album-art-fetch: could not read the colours of $art_url" >&2
        exit 0
      fi

      # How far to stop the backdrop down, as a percentage for `-modulate`.
      # Written by the awk above, and re-checked here because it is about to
      # be interpolated into a command line.
      art_brightness="$(
        gawk -F= '$1 == "ART_BRIGHTNESS" { print $2; exit }' "$tmp_palette"
      )"

      case "$art_brightness" in
        "" | *[!0-9]*) art_brightness=100 ;;
      esac

      ${lib.optionalString lockAlbumArtBackground ''
      # The backdrop. Blurring at 512px and scaling the result up costs a
      # fraction of blurring at 2560px and lands in the same place once it is
      # this soft — the detail was on its way out either way. The square crop
      # first is for the players that report a 16:9 thumbnail instead of a
      # cover.
      #
      # The exposure is the one thing here that is about the lock screen
      # rather than about the picture. Hyprlock's own `brightness` in the
      # background block is a fixed multiplier set for the wallpapers, which
      # are chosen and are mostly dark; album covers are neither, and a sleeve
      # that is mostly white leaves every label on this screen sitting on a
      # pale wash, unreadable. So the cover is exposed *to* a target instead
      # of by a constant — see the reasoning in album-palette.awk — with a
      # little saturation put back to stop the dimming going muddy.
      if ! magick "''${source_file}[0]" \
          -auto-orient -strip -colorspace sRGB \
          -resize 512x512^ -gravity center -extent 512x512 \
          -blur 0x8 \
          -modulate "$art_brightness,110" \
          -filter Lanczos -resize 2560x1440^ \
          -gravity center -extent 2560x1440 \
          -quality 92 "jpg:$tmp_backdrop"; then
        echo "lock-album-art-fetch: could not render a backdrop from $art_url" >&2
        exit 0
      fi
      ''}

      ${lib.optionalString lockAlbumArtCover ''
      # The card: the cover at 200px with soft corners, a hairline edge to
      # lift it off whatever it is sitting on, and a shadow under it, on a
      # 256px transparent canvas that leaves the shadow room to fall.
      #
      # All of it baked into the PNG rather than left to Hyprlock's own
      # `rounding` and `border_size`, for one reason: when the music stops the
      # widget is pointed at a transparent image, and a Hyprlock border would
      # draw a neat empty box around the nothing.
      if ! magick "''${source_file}[0]" \
          -auto-orient -strip -colorspace sRGB \
          -resize 200x200^ -gravity center -extent 200x200 -alpha set \
          \( -size 200x200 xc:none -fill white \
             -draw 'roundrectangle 0,0 199,199 18,18' \) \
          -compose DstIn -composite \
          \( -size 200x200 xc:none -fill none \
             -stroke 'rgba(255,255,255,0.28)' -strokewidth 2 \
             -draw 'roundrectangle 1,1 198,198 17,17' \) \
          -compose Over -composite \
          \( +clone -background black -shadow 50x8+0+4 \) \
          +swap -background none -layers merge +repage \
          -gravity center -background none -extent 256x256 \
          "png32:$tmp_cover"; then
        echo "lock-album-art-fetch: could not render a cover from $art_url" >&2
        exit 0
      fi
      ''}

      # The password field, in this cover's colours, if the cover had any.
      #
      # Nothing is written when it didn't: `lock-album-art` then answers with
      # the theme's own frame, which is a store path that follows a theme
      # switch. A frame rendered here in theme colours would be a copy that
      # doesn't, and it would go stale the moment the theme changed.
      LOCK_ACCENT_DIM=""
      LOCK_BG=""
      lock_palette_colors "$tmp_palette"

      if [ -n "$LOCK_ACCENT_DIM" ] && [ -n "$LOCK_BG" ]; then
        if ! lock_field_frame "$LOCK_ACCENT_DIM" "$LOCK_BG" "$tmp_field"; then
          echo "lock-album-art-fetch: could not render a field frame" >&2
          exit 0
        fi

        mv -f "$tmp_field" "$art_field"
      fi

      # Into place only now, and one rename each, so the reload timer either
      # finds the old answer or a finished new one and never a partial file.
      # The palette goes last on purpose. `lock-session` takes its colours
      # from it and its pictures from the other three, so a palette on disk has
      # to mean the pictures are already there — otherwise a lock landing in
      # this gap would wear a cover it is not showing.
      ${lib.optionalString lockAlbumArtBackground ''
        mv -f "$tmp_backdrop" "$art_backdrop"
      ''}
      ${lib.optionalString lockAlbumArtCover ''
        mv -f "$tmp_cover" "$art_cover"
      ''}
      mv -f "$tmp_palette" "$art_palette"

      # Keep the cache bounded. Thirty tracks each way is a few megabytes and
      # covers an evening of skipping; past that it is a song you are not
      # about to lock the screen on.
      prune_art() {
        find "$art_cache" -maxdepth 1 -type f -name "$1" -printf '%T@ %p\n' |
          sort -rn |
          tail -n +31 |
          cut -d ' ' -f2- |
          xargs -r rm -f
      }

      ${lib.optionalString lockAlbumArtBackground ''
        prune_art '*.backdrop.jpg' || true
      ''}
      ${lib.optionalString lockAlbumArtCover ''
        prune_art '*.cover.png' || true
      ''}
      prune_art '*.palette' || true

      # And the lock files, which are empty and never numerous, but are
      # otherwise the one thing here that only accumulates. A week is far
      # longer than any of them is held, so nothing in use is removed.
      find "$art_cache" -maxdepth 1 -type f -name '.*.lock' -mtime +7 -delete ||
        true
    '';
  };

  # What Hyprlock asks, every few seconds, for the path it should be showing.
  # Prints one path and returns: it never downloads and never renders.
  #
  # That restraint is the whole design. Hyprlock runs `reload_cmd` through
  # `spawnSync` from a timer callback on its main thread (Background.cpp,
  # Image.cpp), so every millisecond spent in here is a millisecond the lock
  # screen is not drawing, and a cover fetched inline over a hotel wifi would
  # freeze the clock and the password field for as long as curl felt like
  # taking. A track that has no render yet is handed to
  # `lock-album-art-fetch` in a detached process and collected on a later
  # tick instead.
  lockAlbumArt = pkgs.writeShellApplication {
    name = "lock-album-art";

    runtimeInputs = with pkgs; [
      coreutils
      playerctl
      util-linux
    ];

    text = ''
      ${albumArtPaths}
      ${hyprlockWallpaper}
      ${lib.optionalString lockAlbumArtBackground ''
        ${lockColorsPath}
        ${lockPaletteColors}
        ${lockThemeColors}
      ''}
      ${mprisSnapshot}

      mode="''${1:-}"

      case "$mode" in
        backdrop | cover | field | palette | all) ;;
        *)
          echo "usage: lock-album-art backdrop|cover|field|palette|all" >&2
          exit 2
          ;;
      esac

      mpris_snapshot

      art_key=""
      [ -z "$art_url" ] || art_paths "$art_url"

      # One answer, for one of the four things a lock screen takes from a
      # cover. Prints nothing when there is nothing to say.
      answer() {
        local want="$1" rendered=""

        if [ -n "$art_key" ]; then
          case "$want" in
            backdrop) ${lib.optionalString lockAlbumArtBackground ''rendered="$art_backdrop"''} ;;
            cover)    ${lib.optionalString lockAlbumArtCover ''rendered="$art_cover"''} ;;
            field)    ${lib.optionalString lockAlbumArtBackground ''rendered="$art_field"''} ;;
            palette)  ${lib.optionalString lockAlbumArtBackground ''rendered="$art_palette"''} ;;
          esac

          if [ -f "$rendered" ]; then
            printf '%s\n' "$rendered"
            return 0
          fi
        fi

        case "$want" in
          backdrop)
            # The wallpaper is the answer whenever the cover isn't: no music,
            # a cover that could not be fetched, or one still rendering.
            # Hyprlock crossfades between whatever two paths it is handed, so
            # the swap reads as a transition in both directions.
            hyprlock_wallpaper
            ;;

          cover)
            if [ -z "$art_url" ]; then
              printf '%s\n' "${emptyCover}"
            fi

            # With a cover on the way, print nothing at all. Hyprlock keeps
            # what it has, which holds the last cover on screen for the second
            # the new one takes rather than blinking through the empty one.
            ;;

          field)
            # The theme's own frame whenever the album has no colours of its
            # own to lend: no music, a grey sleeve, or a cover still
            # rendering. A store path, so it follows a theme switch.
            if [ -r "${activeDir}/lock-field.png" ]; then
              printf '%s\n' "${activeDir}/lock-field.png"
            fi
            ;;

          palette)
            # And nothing to fall back to here: no palette means the lock
            # screen keeps the theme's own colours, which is what the caller
            # does with an empty answer anyway.
            ;;
        esac
      }

      # Anything missing starts the render, once, however many answers are
      # being asked for. Every descriptor is redirected before the fork
      # because Hyprlock is reading this command's stdout, and a pipe left
      # open in the worker would keep it waiting on the download after all the
      # trouble taken not to.
      if [ -n "$art_key" ]; then
        render_missing=false
        ${lib.optionalString lockAlbumArtBackground ''
          [ -f "$art_backdrop" ] || render_missing=true
          [ -f "$art_palette" ] || render_missing=true
        ''}
        ${lib.optionalString lockAlbumArtCover ''
          [ -f "$art_cover" ] || render_missing=true
        ''}

        if [ "$render_missing" = true ]; then
          setsid -f ${lib.getExe lockAlbumArtFetch} "$art_url" \
            </dev/null >/dev/null 2>&1 || true
        fi
      fi

      ${lib.optionalString lockAlbumArtBackground ''
        # Write down the colours this track comes with, for the labels.
        #
        # Here rather than in a script of their own because this is the one
        # thing Hyprlock already runs on a timer that knows which track is
        # playing — so the labels get to be a file read instead of an MPRIS
        # round trip each, and every one of them changes colour on the same
        # tick as the background does. Written to a temporary file and renamed,
        # because a widget with no monitor runs one copy of this per output and
        # they land on top of each other.
        lock_palette_colors "$(answer palette)"

        lock_colors_tmp="$lock_colors.$$.tmp"

        {
          printf 'LOCK_BG=%s\n' "$LOCK_BG"
          printf 'LOCK_ACCENT=%s\n' "$LOCK_ACCENT"
          printf 'LOCK_ACCENT_DIM=%s\n' "$LOCK_ACCENT_DIM"
          printf 'LOCK_FG=%s\n' "$LOCK_FG"
          printf 'LOCK_FG_DIM=%s\n' "$LOCK_FG_DIM"
        } > "$lock_colors_tmp"

        mv -f "$lock_colors_tmp" "$lock_colors"
      ''}

      case "$mode" in
        # Everything `lock-session` needs, in one run. It asks on the path
        # that has to have the screen locked before the machine suspends, and
        # four separate runs would be four separate rounds of MPRIS calls for
        # one question about one track.
        all)
          wants=( ${lib.escapeShellArgs (
            lib.optionals lockAlbumArtBackground [ "backdrop" ]
            ++ lib.optionals lockAlbumArtCover [ "cover" ]
            ++ [ "field" ]
            ++ lib.optionals lockAlbumArtBackground [ "palette" ]
          )} )

          for want in "''${wants[@]}"; do
            value="$(answer "$want")"
            [ -z "$value" ] || printf '%s=%s\n' "$want" "$value"
          done
          ;;

        *)
          answer "$mode"
          ;;
      esac
    '';
  };

  # A lock screen label, in the colour of whatever is playing.
  #
  # Hyprlock has no way to change a widget's colour once it is up, so the
  # colour has to arrive inside the text: labels are rendered through
  # `pango_parse_markup` (hyprgraphics, TextResource.cpp), which means a
  # `<span foreground=...>` in a label's *output* does what a `color =` in its
  # config cannot. Hyprlock re-runs a `cmd[update:N]` label on every tick
  # whether or not its command line changed — `alwaysUpdate` is set for all of
  # them (IWidget.cpp) — so the label picks up a new colour a tick after the
  # track does.
  #
  # Nothing here touches MPRIS: `lock-album-art` has already written down what
  # colour the screen is wearing. That matters because this runs once a second
  # per clock per monitor.
  #
  # If the markup is ever malformed, pango falls back to rendering it as plain
  # text — which the label's own `color` then draws in the theme's colour. The
  # failure mode is a lock screen that looks like it did before this existed.
  lockLabel = pkgs.writeShellApplication {
    name = "lock-label";

    runtimeInputs = [ pkgs.coreutils ];

    text = ''
      ${readLockColors}

      text="''${1:-}"

      # Markup in, markup out: whatever is wrapped has to be escaped, or a
      # name like "Q&A" takes the whole label down to plain text. Ampersands
      # first, or the escapes escape each other.
      #
      # Each `&` is backslashed because bash reads an unescaped one in the
      # replacement half of a substitution as "whatever the pattern matched"
      # — so `''${text//</&lt;}` would put a `<` back where the `&` should be.
      text="''${text//&/\&amp;}"
      text="''${text//</\&lt;}"
      text="''${text//>/\&gt;}"

      printf '<span foreground="#%s">%s</span>\n' "$LOCK_FG" "$text"
    '';
  };

  # The machine's own battery, or nothing at all on a machine without one.
  #
  # Shared between the widget below and `lock-session`, which asks the same
  # question while it writes the config, so that the two can never disagree
  # about whether this machine has a battery to draw.
  #
  # `/sys/class/power_supply` holds every power source the kernel knows about,
  # and most of them are not the answer. The mains adapter is in there with a
  # `type` of Mains, and so is anything with a battery that the machine merely
  # talks to — a wireless mouse, a controller, a headset — which the kernel
  # marks with a `scope` of Device. Drawing one of those would put the charge
  # of a mouse where the laptop's own is meant to be, on a screen where there
  # is nothing to click to find out which it meant. A `present` of 0 is the
  # third case: a bay the driver enumerated with no pack in it.
  #
  # The first match wins, which on a two-pack laptop means BAT0 and not the
  # sum of both. Summing them honestly needs `energy_full` from each — the
  # capacities are percentages of different sizes and averaging them is wrong
  # — and the drivers that report `charge_*` in µAh instead cannot be added at
  # all across packs at different voltages. None of the machines here has a
  # second battery; if one ever does, that is the work it would take.
  batteryDevice = ''
    battery_device() {
      local device kind scope present

      for device in /sys/class/power_supply/*; do
        [ -r "$device/type" ] || continue

        # `2>/dev/null` ahead of the input redirect, not after it. Bash
        # applies redirections left to right and reports a failed one on
        # whatever stderr is at that moment, so the usual trailing order
        # prints "No such file or directory" and *then* silences the file
        # descriptor it was going to be printed on. These reads are guarded,
        # so the only way they fail is the device going away mid-loop — which
        # is a thing that happens, and which nothing needs to hear about.
        read -r kind 2>/dev/null < "$device/type" || continue
        [ "$kind" = Battery ] || continue

        scope=System
        if [ -r "$device/scope" ]; then
          read -r scope 2>/dev/null < "$device/scope" || continue
        fi

        # A `case` rather than `[ … ] && continue`, which under `set -e` would
        # take the whole script down on the batteries this is meant to keep.
        case "$scope" in
          Device) continue ;;
        esac

        if [ -r "$device/present" ]; then
          read -r present 2>/dev/null < "$device/present" || continue
          [ "$present" = 1 ] || continue
        fi

        printf '%s\n' "$device"
        return 0
      done
    }
  '';

  # The battery, for the bottom-right corner of the lock screen.
  #
  # The same glyphs and the same thresholds as the bar's battery module
  # (waybar.nix), because it is the same battery: a machine reading 󰁼 25% in
  # the bar and something else on the lock screen would be saying two things
  # about one number. Warning at 30 and critical at 15, neither of them while
  # it is charging, exactly as the bar's stylesheet has it — and in the
  # theme's own warn and err rather than the album's, for the same reason the
  # palette leaves those two alone. A battery about to die is red whatever is
  # playing.
  #
  # Prints nothing when there is no battery. `lock-session` has already left
  # the widget out of the config in that case, so this is the answer for the
  # narrow window the other check cannot cover — a pack pulled out of its bay
  # while the screen is locked — and a label with no text draws nothing.
  #
  # A handful of `read` builtins and no processes at all, on the resource
  # gatherer's thread rather than the renderer's; see the label commands in
  # `lock-session`.
  lockBattery = pkgs.writeShellApplication {
    name = "lock-battery";

    runtimeInputs = [ pkgs.coreutils ];

    text = ''
      ${readLockColors}
      ${batteryDevice}

      device="$(battery_device)"
      [ -n "$device" ] || exit 0

      # Every driver here reports `capacity` directly. One that didn't would
      # leave the corner empty rather than wrong, which is the right way for
      # this to fail: the charge is not worth guessing at from `energy_now`
      # and a full-charge value the driver would also have had to publish.
      #
      # Redirect order as in battery_device above — stderr first, or a battery
      # pulled out mid-lock writes a line to Hyprlock's log every three
      # seconds until the screen is unlocked.
      read -r capacity 2>/dev/null < "$device/capacity" || exit 0

      case "$capacity" in
        "" | *[!0-9]*) exit 0 ;;
      esac

      status=Unknown
      if [ -r "$device/status" ]; then
        read -r status 2>/dev/null < "$device/status" || status=Unknown
      fi

      case "$status" in
        Charging)
          glyph="󰂄"
          ;;

        # On mains with nothing left to put in: "Full", or "Not charging" from
        # a battery held below 100% on purpose by a charge threshold, which is
        # a normal state rather than a fault and must not read as one.
        Full | "Not charging")
          glyph="󰚥"
          ;;

        # waybar fills five icons from the same percentage, in buckets of
        # twenty. Written out rather than computed so the two lists can be
        # compared by eye.
        *)
          if [ "$capacity" -ge 80 ]; then
            glyph="󰂂"
          elif [ "$capacity" -ge 60 ]; then
            glyph="󰂀"
          elif [ "$capacity" -ge 40 ]; then
            glyph="󰁾"
          elif [ "$capacity" -ge 20 ]; then
            glyph="󰁼"
          else
            glyph="󰁺"
          fi
          ;;
      esac

      color="$LOCK_FG"

      case "$status" in
        Charging | Full | "Not charging") ;;
        *)
          if [ "$capacity" -le 15 ]; then
            color="$LOCK_ERR"
          elif [ "$capacity" -le 30 ]; then
            color="$LOCK_WARN"
          fi
          ;;
      esac

      # Wrapped in a colour for the same reason as `lock-label`: a Hyprlock
      # label's colour is fixed at parse time, and the only colour that can
      # reach one afterwards is one inside its own text. Nothing here needs
      # pango-escaping — a glyph and a number, both of them ours.
      printf '<span foreground="#%s">%s  %s%%</span>\n' "$color" "$glyph" "$capacity"
    '';
  };

  # Switch the current seat to SDDM without unlocking or ending this session.
  #
  # Kept below `switch-user` as a low-level primitive: the normal desktop
  # action locks first, while Hyprlock can call this directly because the
  # session is already locked.
  switchToGreeter = pkgs.writeShellApplication {
    name = "switch-to-greeter";
    runtimeInputs = [ pkgs.dbus ];
    text = ''
      seat="''${XDG_SEAT_PATH:-/org/freedesktop/DisplayManager/Seat0}"

      exec dbus-send --system --print-reply \
        --dest=org.freedesktop.DisplayManager \
        "$seat" \
        org.freedesktop.DisplayManager.Seat.SwitchToGreeter
    '';
  };

  # Exposed deliberately on the lock screen. Suspending leaves Hyprlock in
  # place, so waking the machine returns to the same locked session.
  suspendSystem = pkgs.writeShellApplication {
    name = "suspend-system";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      exec systemctl suspend
    '';
  };

  lockSession = pkgs.writeShellApplication {
  name = "lock-session";

  runtimeInputs = [
    pkgs.hyprlock
    pkgs.coreutils
    pkgs.gawk
    pkgs.glibc.bin
    pkgs.util-linux
    swaylock
  ];

  text = ''
    # This blocks until the session is unlocked. Nothing on a timer should
    # call it directly — see `lock-now` below, which is what swayidle, the
    # keybinds and the bar all go through.

    grace=0

    while [ "$#" -gt 0 ]; do
      case "$1" in
        # Seconds during which any input dismisses the lock without a
        # password. Zero by default, because every deliberate route to the
        # lock — the keybinds, the bar, the session menu, switch-user,
        # before-sleep, `loginctl lock-session` — means "lock it", and on
        # those a grace window is one in which the very act of waking the
        # screen to check that it locked would unlock it again.
        #
        # The one caller that wants a nonzero value is the idle timer in
        # lock.nix, which passes `--grace 2`: there the lock fired on its own
        # while you were away from the desk, and the two seconds cover walking
        # back into it as it fires.
        --grace)
          grace="''${2:-}"
          case "$grace" in
            "" | *[!0-9]*) echo "lock-session: --grace wants a number" >&2; exit 2 ;;
          esac
          shift 2
          ;;
        *)
          echo "usage: lock-session [--grace <seconds>]" >&2
          exit 2
          ;;
      esac
    done

    # One locker at a time, held for as long as this process lives.
    #
    # Without it a second lock request — the lid closing onto an already
    # locked session, a stray Mod+L, before-sleep arriving after the idle
    # timer — starts a second hyprlock, which cannot take the session lock
    # and exits non-zero, and the fallback below then reads that as "hyprlock
    # is broken" and layers a swaylock on top of the working lock screen.
    #
    # An open file descriptor rather than a PID file or a process-name match:
    # the kernel drops the lock when the process dies however it dies, so
    # there is no stale state to clean up, and it survives the `exec swaylock`
    # at the bottom (fd 9 is not close-on-exec) so the fallback holds it too.
    #
    # `lock-now` tests the same file, which is how it knows the locker is up.
    lockfile="''${XDG_RUNTIME_DIR:-/tmp}/lock-session.lock"
    exec 9>"$lockfile"
    if ! flock -n 9; then
      exit 0
    fi

    ${lockThemeColors}
    ${lib.optionalString lockAlbumArtBackground ''
      ${lockPaletteColors}
    ''}

    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    config="$runtime_dir/hyprlock-niri.conf"

    mkdir -p "$runtime_dir"
    umask 077

    # The first name is baked into this script from
    # users.users.<name>.description during Nix evaluation, already stripped
    # of everything that could break the line it lands in.
    first_name=${lib.escapeShellArg safeFirstName}
    greeting="Welcome, $first_name."

    ${lib.optionalString (config.local.niri.timeBasedLockGreetings || config.local.niri.randomLockGreetings) ''
      greetings=("Welcome, $first_name.")
      read -r hour < <(date '+%H')

    # Morning is 05:00-11:59, afternoon is 12:00-17:59, and evening also
      # covers the quiet hours after midnight. Only greetings for the current
      # part of the day enter the draw.


      case "$hour" in
        05 | 06 | 07 | 08 | 09 | 10 | 11)
          greetings+=(
            "Good Morning, $first_name."
          )
          ;;
        12 | 13 | 14 | 15 | 16 | 17)
          greetings+=(
            "Good Afternoon, $first_name."
          )
          ;;
        *)
          greetings+=(
            "Good Evening, $first_name."
          )
          ;;
      esac
    ''
    }
    ${lib.optionalString config.local.niri.randomLockGreetings ''
      # Pick once per lock rather than on the label's refresh timer. The one
      # `date` call is the only process this adds; the list and the draw use
      # Bash builtins, so the greeting costs nothing while the lock screen is
      # up. With the option off, Nix leaves this whole block out.
      greetings+=(
        "Back at it again, $first_name."
        "Nice to see you, $first_name."
        "Ready when you are, $first_name."
      )

      read -r weekday < <(date '+%u')

      # Morning is 05:00-11:59, afternoon is 12:00-17:59, and evening also
      # covers the quiet hours after midnight. Only greetings for the current
      # part of the day enter the draw.
      case "$hour" in
        05 | 06 | 07 | 08 | 09 | 10 | 11)
          daypart=Morning
          greetings+=(
            "Fresh start, $first_name."
          )
          ;;
        12 | 13 | 14 | 15 | 16 | 17)
          daypart=Afternoon
          greetings+=(
            "Let's keep it going, $first_name."
          )
          ;;
        *)
          daypart=Evening
          greetings+=(
            "The night shift begins, $first_name."
          )
          ;;
      esac

      # Weekday mornings and afternoons lean toward work and coding. Evenings
      # and the whole weekend lean toward games instead.
      if [ "$weekday" -le 5 ] && [ "$daypart" != Evening ]; then
        greetings+=(
          "Coffee, then code, $first_name."
          "Ready to ship something, $first_name?"
	  "Back to VS Code, $first_name."
        )
      else
        greetings+=(
          "Where we dropping, $first_name?"
          "Stand by for Titanfall, $first_name."
          "Late night coding, $first_name?"
          "One more round, $first_name?"
        )
      fi
    ''}

    ${lib.optionalString (config.local.niri.timeBasedLockGreetings || config.local.niri.randomLockGreetings) ''
      greeting_count="''${#greetings[@]}"
      greeting_index=$((RANDOM % greeting_count))
      greeting="''${greetings[$greeting_index]}"
    ''}

    ${hyprlockWallpaper}

    # Stale links from an earlier lock, before hyprlock_wallpaper re-creates
    # the one that matches the wallpaper as it is now.
    rm -f "$runtime_dir"/hyprlock-wallpaper.*

    # Ask once for every enabled album-art image and for the field frame. The
    # palette and its album-coloured frame only participate with the album-art
    # background; a disabled background leaves every colour on the theme even
    # when the independent cover card remains enabled.
    #
    # Under a `timeout` because this is the path that has to have the screen
    # locked before the machine suspends. lock-album-art bounds its own MPRIS
    # queries and should never come near this, and if it does, everything
    # below falls back to what it would show without music.
    backdrop=""
    cover=""
    field=""
    ${lib.optionalString lockAlbumArtBackground ''
      palette=""
    ''}

    while IFS='=' read -r kind value; do
      case "$kind" in
        backdrop) backdrop="$value" ;;
        cover)    cover="$value" ;;
        field)    field="$value" ;;
        ${lib.optionalString lockAlbumArtBackground ''
          palette) palette="$value" ;;
        ''}
      esac
    done < <(timeout 2 ${lib.getExe lockAlbumArt} all || true)

    if [ -z "$backdrop" ]; then
      backdrop="$(hyprlock_wallpaper)"
    fi

    path_line=""

    if [ -n "$backdrop" ]; then
      path_line="    path = $backdrop"
    fi

    # The cover card above the track name. Always a real image, so the widget
    # has something valid to point at from the first frame: a transparent one
    # when nothing is playing, or when the cover is still rendering and the
    # reload timer is about to bring it in.
    if [ -z "$cover" ]; then
      cover="${emptyCover}"
    fi

    # The password field's frame, as a picture of one — see lockFieldFrame in
    # theming.nix for why it has to be a picture, and for the geometry that
    # keeps it exactly where Hyprlock would have drawn its own.
    #
    # With a frame to draw, the real field's outline and fill are made
    # transparent and the image shows through. Without one, the field goes
    # back to drawing them itself, in the colours of whatever is playing at
    # the moment of the lock; the only way to get there is a theme directory
    # from before this existed, but the lock screen has to come up either way.
    field_outer="00000000"
    field_inner="00000000"

    if [ -z "$field" ]; then
      field="${emptyCover}"
      field_outer="''${LOCK_ACCENT_DIM}dd"
      field_inner="''${LOCK_BG}d6"
    fi

    ${lib.optionalString lockAlbumArtBackground ''
      # And the album's own colours over the theme's, when the cover had a
      # colour confident enough to take. `album-palette.awk` decides that and
      # writes the file.
      #
      # This is the lock screen's *first* set of colours rather than its only
      # one: `lock-album-art` writes the same answer out again on every tick,
      # and the labels below re-read it — so what is fixed here is only what
      # cannot follow, which is the dots inside the field and the red and yellow
      # of a failed password and a caps-lock warning.
      lock_palette_colors "$palette"
    ''}

    # Read straight for the swaylock fallback at the bottom, which stays on
    # the wallpaper: that is the locker of last resort, and routing the album
    # art through it too would put one more thing that can fail on the path
    # that only runs because something already has.
    wallpaper="$(cat "${stateDir}/wallpaper" 2>/dev/null || true)"

    ${lib.optionalString lockBatteryIndicator ''
      ${batteryDevice}

      # Whether there is a battery to draw, decided here rather than left to
      # the widget: a desk should not carry a label that wakes every three
      # seconds to discover it has nothing to say, and a lock screen with an
      # empty corner is not the same thing as one with no corner widget in it
      # at all. Asked once per lock, so a machine that grows a battery — a
      # laptop whose pack was out of its bay — has one by the next lock.
      battery="$(battery_device)"
    ''}

    # The config, comments and all — Hyprlang keeps its own `#` lines, and
    # they are the only documentation the generated file has.
    #
    # Nothing in here may contain a backtick, including the comments: this
    # heredoc is unquoted, so a pair of them is a command substitution rather
    # than a piece of punctuation. Same for a `$` that isn't meant for the
    # shell — see the escaped \$TIME12 and \$FAIL below.
    cat > "$config" <<EOF
    general {
        # The session and media controls below are clickable, so keep the
        # pointer visible instead of making users hunt for it by echolocation.
        hide_cursor = false
        ignore_empty_input = true
        immediate_render = true
        text_trim = true
        fail_timeout = 1800
    }

    auth {
        pam:enabled = true
        pam:module = hyprlock
    }

    animations {
        enabled = true

        bezier = graceful, 0.22, 1, 0.36, 1

        animation = fadeIn, 1, 2.4, graceful
        animation = fadeOut, 1, 2.0, graceful
        animation = inputFieldDots, 1, 2.8, graceful
        animation = inputFieldColors, 1, 2.2, graceful
        animation = inputFieldFade, 1, 2.2, graceful
    }

    background {
        monitor =
    $path_line
        color = rgb($LOCK_BG)

        blur_passes = 1
        blur_size = 3

        noise = 0.05
        contrast = 1.0
        brightness = 0.64
        vibrancy = 0.16
        vibrancy_darkness = 0.12

    ${lib.optionalString lockAlbumArtBackground ''
        # Follows the music. lock-album-art answers with the blurred cover of
        # whatever is playing and with the wallpaper when nothing is, so the
        # background changes with the track and comes back to the wallpaper
        # when the music stops. The crossfade is what keeps that from
        # registering as a flicker.
        #
        # Three seconds rather than one, because a widget with no monitor is
        # built once per output and each copy runs its own reload command on
        # Hyprlock's main thread — on the desk that is three backgrounds and
        # three covers all asking. All it costs is a track change landing a
        # beat later than it could.
        reload_time = 3
        reload_cmd = ${lib.getExe lockAlbumArt} backdrop
        crossfade_time = 0.9
    ''}
    }

    # Quiet clock above the greeting.
    #
    # Through lock-label rather than as a plain \$TIME12, so that it follows
    # the music: a Hyprlock label's colour is fixed at parse time, and the
    # only colour that can reach one afterwards is one inside its own text.
    # Hyprlock substitutes \$TIME12 into the command line before running it
    # (IWidget.cpp formats the string, then strips the cmd prefix), so the
    # clock is still Hyprlock's own — this only paints it.
    #
    # The color below is what pango falls back to if the markup ever fails to
    # parse, and the alpha it carries applies either way.
    label {
        monitor =
        text = cmd[update:1000] ${lib.getExe lockLabel} "\$TIME12"
        color = rgba(''${LOCK_FG}dd)
        font_size = 72
        font_family = Poppins

        position = 0, 125
        halign = center
        valign = center
    }

    # With randomLockGreetings off this remains the original welcome; with it
    # on, the selection is made once above and kept until the lock is dismissed.
    # The refresh remains because lock-label also follows the album palette.
    label {
        monitor =
        text = cmd[update:3000] ${lib.getExe lockLabel} "$greeting"
        color = rgb($LOCK_FG)
        font_size = 40
        font_family = Poppins

        position = 0, 35
        halign = center
        valign = center
    }

    ${lib.optionalString lockAlbumArtCover ''
    # The cover of whatever is playing, sitting just above the track name.
    # The rounded corners, the hairline edge and the shadow are all in the
    # image rather than in the options below, which is what lets nothing
    # playing be a transparent image and leave no empty frame behind.
    #
    # The cover and the track name below it sit 36px higher than the password
    # field alone would put them, which is the height of the transport
    # controls beneath them. Moving them rather than squeezing the controls
    # into the gap that was already there keeps the card, the name and the
    # buttons reading as one block, and it costs nothing on a screen with no
    # music: everything between the field and the clock is empty then anyway.
    image {
        monitor =
        path = $cover

        size = 256
        rounding = 0
        border_size = 0

        reload_time = 3
        reload_cmd = ${lib.getExe lockAlbumArt} cover

        position = 0, 220
        halign = center
        valign = bottom
    }
    ''}

    # The active MPRIS track. This remains blank when there is no recognized
    # media session, so the lock screen does not grow an empty placeholder.
    label {
        monitor =
        text = cmd[update:1500] ${lib.getExe lockNowPlaying}

        color = rgba(''${LOCK_FG}cc)
        font_size = 18
        font_family = FiraCode Nerd Font
        text_align = center

        position = 0, 194
        halign = center
        valign = bottom
    }

    # Previous, play/pause and next for the track named above — the same
    # three actions the XF86Audio keys already reach while locked, for a
    # machine whose keyboard hasn't got them.
    #
    # Three labels rather than one row: a Hyprlock label carries a single
    # onclick, and the area that catches it is the label's own text. That
    # second half is also what hides the row when the music stops —
    # lock-media-button prints nothing without a media session, and a label
    # with no text has no box for a click to land in. A click that somehow
    # found one anyway would reach a lock-media-control that exits without
    # doing anything, for want of a player to do it to.
    #
    # 1500 to match the track name, rather than something quicker for the
    # play/pause glyph: that is the shortest interval the shared MPRIS cache
    # is built to serve (see mprisSnapshot), and it keeps this glyph and the
    # pause marker in the name beside it turning over together instead of a
    # beat apart. The action itself is immediate either way — only the glyph
    # waits for a tick, and a click drops the cache so that tick asks MPRIS
    # rather than serving what was true before the click.
    label {
        monitor =
        text = cmd[update:1500] ${lib.getExe lockMediaButton} previous
        color = rgba(''${LOCK_FG}cc)
        font_size = 24
        font_family = FiraCode Nerd Font

        position = -56, 148
        halign = center
        valign = bottom

        onclick = ${lib.getExe lockMediaControl} previous
    }

    label {
        monitor =
        text = cmd[update:1500] ${lib.getExe lockMediaButton} play-pause
        color = rgba(''${LOCK_FG}cc)
        font_size = 24
        font_family = FiraCode Nerd Font

        position = 0, 148
        halign = center
        valign = bottom

        onclick = ${lib.getExe lockMediaControl} play-pause
    }

    label {
        monitor =
        text = cmd[update:1500] ${lib.getExe lockMediaButton} next
        color = rgba(''${LOCK_FG}cc)
        font_size = 24
        font_family = FiraCode Nerd Font

        position = 56, 148
        halign = center
        valign = bottom

        onclick = ${lib.getExe lockMediaControl} next
    }

    # The password field's frame, drawn as an image so that it can change
    # colour with the track — nothing else can, since Hyprlock re-reads paths
    # and never colours. 624x62 at 0,70 is exactly the box the field below
    # would have drawn its own outline in; see lockFieldFrame in theming.nix.
    #
    # Under the field rather than over it, so the dots and the text stay on
    # top, and so the outline the field still draws for a wrong password or a
    # caps-lock warning lands over this one rather than beneath it.
    image {
        monitor =
        path = $field

        size = 62
        rounding = 0
        border_size = 0
        zindex = 0

        reload_time = 3
        reload_cmd = ${lib.getExe lockAlbumArt} field

        position = 0, 70
        halign = center
        valign = bottom
    }

    # One low, horizontal password field. Dots begin at the left and animate
    # individually so typing travels across the line rather than accumulating
    # as a static cluster in its center.
    #
    # Its outline and fill are transparent because the image above is drawing
    # them. The thickness stays, and so do the check, fail and capslock
    # colours: those are the states Hyprlock animates the outline *to*, and
    # they are the reason this is a transparent outline rather than no
    # outline. They keep the theme's red and yellow, which is what an error
    # and a warning should be whatever is playing.
    input-field {
        monitor =
        zindex = 1

        size = 620, 58
        outline_thickness = 2
        rounding = 18

        dots_size = 0.15
        dots_spacing = 0.42
        dots_center = true
        dots_rounding = -1
        dots_text_format = •

        outer_color = rgba($field_outer)
        inner_color = rgba($field_inner)
        font_color = rgb($LOCK_FG)
        font_family = FiraCode Nerd Font

        fade_on_empty = false
        hide_input = false
        placeholder_text = Password

        check_color = rgb($LOCK_ACCENT)
        check_text = Unlocking…

        fail_color = rgb($LOCK_ERR)
        fail_text = <i>\$FAIL</i>

        capslock_color = rgb($LOCK_WARN)

        position = 0, 72
        halign = center
        valign = bottom
    }

    # Lightweight session actions, styled like the clock rather than as
    # boxed controls. Hyprlock still shows the normal pointer over each label,
    # but there is no custom color, scaling, or opacity hover effect.
    label {
        monitor =
        text = cmd[update:3000] ${lib.getExe lockLabel} "󰍃 Switch user"
        color = rgba(''${LOCK_FG}cc)
        font_size = 15
        font_family = FiraCode Nerd Font

        position = -78, 18
        halign = center
        valign = bottom

        onclick = ${lib.getExe switchToGreeter}
    }

    label {
        monitor =
        text = cmd[update:3000] ${lib.getExe lockLabel} "󰒲 Sleep"
        color = rgba(''${LOCK_FG}cc)
        font_size = 15
        font_family = FiraCode Nerd Font

        position = 78, 18
        halign = center
        valign = bottom

        onclick = ${lib.getExe suspendSystem}
    }
    EOF

    ${lib.optionalString lockBatteryIndicator ''
      # Appended rather than written into the config above, because this is
      # the one widget whose presence depends on the machine it is being
      # written for.
      if [ -n "$battery" ]; then
        cat >> "$config" <<EOF
      # The battery, in the far corner, away from everything you interact
      # with: this is the one thing on the lock screen that is only ever
      # read. It sits on the same 18px baseline as the session controls, so
      # the bottom of the screen still reads as one row.
      #
      # Ticking with the greeting and the session controls rather than on a
      # clock of its own. A charge level is slow enough that anything faster
      # would be for nothing, and the colour of it is not: the labels pick up
      # the album's palette on their own next tick, and a battery three
      # seconds behind the rest of the screen is a battery nobody notices
      # catching up.
      label {
          monitor =
          text = cmd[update:3000] ${lib.getExe lockBattery}
          color = rgba(''${LOCK_FG}cc)
          font_size = 15
          font_family = FiraCode Nerd Font

          position = -32, 18
          halign = right
          valign = bottom
      }
      EOF
      fi
    ''}

    # Hyprlock blocks until the session is unlocked. A nonzero exit here
    # means it failed to initialize, not merely that a password was wrong.
    if hyprlock --config "$config" --grace "$grace"; then
      exit 0
    fi

    # Last-resort locker. Even a Hyprlock regression must not leave the
    # session exposed.
    image_args=()
    if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
      image_args=(
        --image ":$wallpaper"
        --scaling fill
      )
    fi

    exec swaylock \
      "''${image_args[@]}" \
      --color "$LOCK_BG" \
      --clock \
      --indicator \
      --indicator-radius 130 \
      --indicator-thickness 9 \
      --effect-blur 8x5 \
      --effect-vignette 0.4:0.4 \
      --datestr "%A%n%B %d" \
      --timestr "%I:%M %p" \
      --font "FiraCode Nerd Font" \
      --ring-color "$LOCK_ACCENT_DIM" \
      --ring-clear-color "$LOCK_WARN" \
      --ring-ver-color "$LOCK_ACCENT" \
      --ring-wrong-color "$LOCK_ERR" \
      --key-hl-color "$LOCK_ACCENT" \
      --bs-hl-color "$LOCK_ERR" \
      --inside-color "$LOCK_BG"cc \
      --inside-clear-color "$LOCK_BG"cc \
      --inside-ver-color "$LOCK_BG"cc \
      --inside-wrong-color "$LOCK_BG"cc \
      --line-color 00000000 \
      --separator-color 00000000 \
      --text-color "$LOCK_FG" \
      --text-clear-color "$LOCK_FG" \
      --text-ver-color "$LOCK_FG" \
      --text-wrong-color "$LOCK_ERR" \
      --fade-in 0.2 \
      --grace "$grace"
  '';
};

  # Lock, and come back as soon as the lock is up rather than when it ends.
  #
  # This exists because of one line in swayidle: home-manager passes it `-w`
  # by default (`services.swayidle.extraArgs`), and with `-w` swayidle's
  # `cmd_exec` does a single fork and then `waitpid()`s the command from
  # inside its Wayland event loop instead of double-forking and returning
  # (main.c). Pointing a timeout straight at `lock-session`, which blocks
  # until you type your password, therefore froze the whole idle timer at the
  # moment it locked: the 600s `power-off-monitors` never fired, so the
  # screen locked and then stayed lit indefinitely. The `lock` and
  # `before-sleep` events had the same problem — a lid close on mains, or a
  # suspend, wedged the timer until the session was unlocked again.
  #
  # `-w` is worth keeping, though, and that's why this is a wrapper rather
  # than an `extraArgs = [ ]`: it is what makes swayidle hold logind's sleep
  # delay lock until `before-sleep` has returned, which is the guarantee that
  # the machine never suspends before the locker is on screen. So the command
  # has to return quickly *and* not before the lock has taken — both of which
  # this does.
  #
  # Idempotent, so every route to the lock can call it: already locked is a
  # silent success rather than a second locker.
  lockNow = pkgs.writeShellApplication {
    name = "lock-now";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      lockSession
    ];
    text = ''
      lockfile="''${XDG_RUNTIME_DIR:-/tmp}/lock-session.lock"

      # True once lock-session holds the lock. Testing it in a subshell takes
      # the lock only for the life of that subshell, so this never races the
      # real holder — and `flock -n` failing is the *positive* answer here,
      # hence the negation.
      locked() { ! ( flock -n 9 ) 9>"$lockfile"; }

      if locked; then
        exit 0
      fi

      # setsid so the locker outlives this script and its caller. swayidle
      # reaps the `sh -c` that ran us and nothing else; niri's `spawn` and
      # waybar's `on-click` behave the same way.
      setsid lock-session "$@" &

      # Bounded wait for the locker to come up. Six seconds is far longer than
      # hyprlock needs and still short enough that a locker which never starts
      # can't hold a suspend past logind's own five-second inhibit delay.
      up=0
      for _ in $(seq 1 60); do
        if locked; then
          up=1
          break
        fi
        sleep 0.1
      done

      if [ "$up" = "0" ]; then
        echo "lock-now: no locker came up within 6s" >&2
        exit 1
      fi

      # The lock file says lock-session is *running*, which is a fraction of a
      # second before hyprlock has claimed the session lock and drawn. There
      # is no readiness signal to wait on instead — hyprlock has no IPC, and a
      # Wayland session lock isn't visible to logind — so this is a settle,
      # honestly a guess, and deliberately a generous one relative to what it
      # is covering. It matters for the two callers that do something to the
      # screen straight afterwards: `lock-blank` powers the monitors off, and
      # `switch-user` hands the seat to the greeter.
      sleep 0.3
    '';
  };

  # Lock and turn the displays off, in one key.
  #
  # The two halves are independent mechanisms — the lock is a Wayland session
  # lock, the blank is niri's own DPMS over IPC — so this is the only thing
  # that does both, and it is what Mod+Shift+L runs. Any input powers the
  # monitors back on and lands on the lock screen, exactly as the 600s idle
  # blank does.
  #
  # `--grace 0` is the default `lock-session` already uses, and is passed here
  # explicitly because this key is the clearest case for it: it means "I am
  # leaving", and it blanks the screen, so the very act of waking the display
  # to check that it locked would fall inside any grace window. Only the idle
  # timer in lock.nix asks for a nonzero grace.
  lockBlank = pkgs.writeShellApplication {
    name = "lock-blank";
    runtimeInputs = with pkgs; [
      niri
      lockNow
    ];
    text = ''
      # lock-now returns once the locker is up and settled, so there is
      # nothing to sleep on here — see the comment on its settle.
      lock-now --grace 0

      niri msg action power-off-monitors
    '';
  };

  # Dismiss the lock screen without asking for the password.
  #
  # Wired to swayidle's `unlock` event (lock.nix), which is logind's Unlock
  # signal on this session. The only thing that sends it here is SDDM: with
  # Users.ReuseSession (modules/nixos/niri.nix) a login for someone who is
  # already logged in calls UnlockSession and then ActivateSession on the
  # session they left behind, rather than starting a second one. Without this
  # you land back on your own lock screen having just typed your password into
  # the greeter, and type it again.
  #
  # It is not a hole in the lock. logind takes Unlock only from the session's
  # own user or from root — the polkit check names the session owner as the
  # user who may skip it — so the two ways to reach this are code already
  # running as you, and SDDM's daemon, which sends it having just put you
  # through PAM.
  #
  # SIGUSR1 is hyprlock's own unlock path (`enqueueUnlock`), the same one a
  # correct password takes, so the Wayland session lock is released properly.
  # Killing the locker would not unlock anything: under ext-session-lock a
  # locker that dies without releasing the lock leaves the compositor locked
  # with nothing left to type into, which is the protocol working as designed
  # rather than a bug to work around.
  #
  # Nothing here for swaylock, which `lock-session` only runs when hyprlock
  # failed to start. It has no unlock signal, so a session sitting on the
  # fallback locker still wants the password — the right direction for a
  # fallback to fail in.
  unlockSession = pkgs.writeShellApplication {
    name = "unlock-session";
    runtimeInputs = with pkgs; [
      procps
      coreutils
    ];
    text = ''
      if ! pkill -USR1 -x -u "$(id -u)" hyprlock; then
        echo "unlock-session: no hyprlock running; nothing to unlock" >&2
      fi
    '';
  };

  # Run a command only while this session is the one on the screen.
  #
  #     when-active brightness dim 20
  #
  # More than one person can be logged in at once — `switch-user` hands the
  # seat to the greeter and deliberately leaves the old session running — and
  # every one of those sessions has its own swayidle counting. niri does not
  # stop the idle clock for a session that has been switched away from:
  # pausing a session suspends libinput and DRM and nothing else, so the
  # compositor simply sees no input, decides you are idle, and the timers in
  # lock.nix fire in a session nobody is looking at.
  #
  # Locking such a session is right. Dimming and blanking it are not, because
  # neither one is confined to the session that asked for it: brightness goes
  # out over DDC/CI to the monitor itself (modules/nixos/ddcci.nix), which is
  # one piece of hardware shared by everyone on the seat. Left ungated, a
  # background session's four-minute dim lands on the screen of whoever is
  # actually using the machine, four minutes after they sat down.
  #
  # `show-session auto` is how swayidle itself finds the session it listens to
  # for logind's Lock and Unlock signals. logind resolves "auto" as the
  # caller's own session, falling back to the user's display session, and that
  # fallback is what makes it work from a `systemd --user` service — there is
  # no XDG_SESSION_ID in that environment and the unit's cgroup sits outside
  # any login session, so asking about "this process's session" gets nowhere.
  #
  # A question that can't be answered runs the command. Sessions on no seat at
  # all — a VM, a headless box, an ssh login — report themselves active, and
  # anything that leaves this empty (no logind, no session) is a machine where
  # there is nobody else to interrupt in the first place.
  whenActive = pkgs.writeShellApplication {
    name = "when-active";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if [ "$#" -eq 0 ]; then
        echo "usage: when-active <command> [args...]" >&2
        exit 2
      fi

      active="$(loginctl show-session auto --property=Active --value 2>/dev/null || true)"

      if [ "$active" = "no" ]; then
        exit 0
      fi

      exec "$@"
    '';
  };

  # Sleep inhibitor. One entry point for the keybind and the waybar module,
  # so the two can't disagree about the state.
  #
  # All the actual work is in idle-inhibit.service (lock.nix); this only
  # starts and stops it. systemd holding the state means `status` is a real
  # query rather than a flag file that can go stale — if the inhibitor dies
  # for any reason, the bar shows it.
  #
  # Not waybar's built-in `idle_inhibitor` module: that one holds a Wayland
  # idle-inhibit lock on waybar's own surface, which is a fine mechanism but
  # can only be toggled by clicking the module. There's no IPC to it, so a
  # keybind would have no way in. It also wouldn't hold off logind sleep.
  idleInhibit = pkgs.writeShellApplication {
    name = "idle-inhibit";
    runtimeInputs = with pkgs; [
      systemd
      libnotify
      procps
    ];
    text = ''
      unit=idle-inhibit.service

      is_on() { systemctl --user is-active --quiet "$unit"; }

      case "''${1:-toggle}" in
        on)  systemctl --user start "$unit" ;;
        off) systemctl --user stop  "$unit" ;;
        toggle)
          if is_on; then systemctl --user stop "$unit"
          else systemctl --user start "$unit"
          fi
          ;;
        status)
          # waybar custom module, return-type json.
          if is_on; then
            printf '%s\n' '{"text":"󰅶","class":"activated","tooltip":"Awake — no dim, lock, blank or sleep"}'
          else
            printf '%s\n' '{"text":"󰒲","class":"deactivated","tooltip":"Idle actions normal — click to stay awake"}'
          fi
          exit 0
          ;;
        *)
          echo "usage: idle-inhibit [toggle|on|off|status]" >&2
          exit 2
          ;;
      esac

      # Refresh the bar now rather than waiting for its next poll. waybar
      # re-runs a custom module on SIGRTMIN+<signal>; 8 is the number set on
      # the module in waybar.nix.
      pkill -RTMIN+8 waybar || true

      if is_on; then
        notify-send -a idle-inhibit -i preferences-desktop-screensaver \
          "Staying awake" "Idle actions and sleep are inhibited" || true
      else
        notify-send -a idle-inhibit -i preferences-desktop-screensaver \
          "Idle actions restored" "Screen will dim, lock and blank as usual" || true
      fi
    '';
  };

  # Session menu: shown by the waybar power button and a hotkey.
  # Switch to the login greeter, leaving this session running on its own VT.
  #
  # SDDM implements the org.freedesktop.DisplayManager D-Bus interface, whose
  # Seat object has SwitchToGreeter — that's the supported way to do this;
  # there's no CLI equivalent. SDDM exports the seat path as XDG_SEAT_PATH in
  # the session, with Seat0 as the fallback for a single-seat machine.
  #
  # The session is locked first. SwitchToGreeter doesn't lock anything, so
  # without this, switching back would land straight in an unlocked desktop.
  switchUser = pkgs.writeShellApplication {
    name = "switch-user";
    runtimeInputs = lib.optional (!useNoctalia) lockNow;
    text =
      if useNoctalia then
        ''
          # Switching seats does not lock the session on its own. Ask the
          # shell that owns this session to claim the Wayland lock first, then
          # give it the same short settle the legacy locker used before the
          # greeter takes the DRM devices away.
          ${lib.getExe pkgs.noctalia} msg session lock
          ${pkgs.coreutils}/bin/sleep 0.3

          exec ${lib.getExe switchToGreeter}
        ''
      else
        ''
          # lock-now returns once the locker is up rather than when it ends,
          # and carries the settle that the hand-rolled
          # `lock-session & sleep 0.3` here used to do by hand.
          lock-now

          exec ${lib.getExe switchToGreeter}
        '';
  };

  sessionMenu = pkgs.writeShellApplication {
    name = "session-menu";
    runtimeInputs = with pkgs; [
      wofi
      systemd
      niri
      lockNow
      switchUser
    ];
    text = ''
      choice="$(printf '%s\n' \
        "  Lock" \
        "  Switch user" \
        "  Log out" \
        "  Suspend" \
        "  Reboot" \
        "  Shut down" \
        | wofi --dmenu --prompt "Session" --insensitive --width 260 --height 300)"

      case "$choice" in
        *Lock*)        lock-now ;;
        *"Switch user"*) switch-user ;;
        *"Log out"*)   niri msg action quit --skip-confirmation ;;
        *Suspend*)     systemctl suspend ;;
        *Reboot*)      systemctl reboot ;;
        *"Shut down"*) systemctl poweroff ;;
      esac
    '';
  };

  # The on-screen display, as one entry point.
  #
  # swayosd draws it (see ./osd.nix); this is the only thing that knows how to
  # ask. Two shapes, matching the two a client request can actually produce:
  #
  #   osd progress <icon> <percent>   icon, bar and a percentage
  #   osd message  <icon> <text>      icon and a line of text
  #
  # `<icon>` is a Freedesktop icon name. swayosd bundles its own set inside the
  # binary — `sink-volume-{muted,low,medium,high}-symbolic`, the matching
  # `source-volume-*` for microphones, and `display-brightness-symbolic` — and
  # those are the ones to reach for: they are the glyphs its native OSD draws,
  # and being compiled in they cannot go missing when the icon theme changes.
  #
  # Every call is best effort. `swayosd-client` exits non-zero when the server
  # isn't up, and a missing pop-up must never turn into a volume or brightness
  # key that appears to have failed.
  #
  # That is also why swayosd is never asked to *change* anything, only to draw.
  # `swayosd-client --output-volume raise` and `--brightness raise` do the
  # change and the drawing together, and that is the usage its README
  # documents — but with the server down they do neither, so a crashed OSD
  # daemon would take the media keys with it. Its brightness backend is a
  # second reason: it is `brightnessctl` with at most one `--device`, which is
  # the exact behaviour `brightness` below exists to work around, and asking it
  # for a wildcard makes `brightnessctl get` print one line per display into a
  # parser that wants a single number. So both callers make the change
  # themselves and read the result back.
  osd = pkgs.writeShellApplication {
    name = "osd";
    runtimeInputs = with pkgs; [
      swayosd
      gawk
      coreutils
    ];
    text = ''
      icon="''${2:-}"

      case "''${1:-}" in
        progress)
          pct="''${3:-}"

          # A malformed reading draws nothing rather than a wrong bar.
          case "$pct" in
            "" | *[!0-9]*) exit 0 ;;
          esac

          # The bar takes a 0.0–1.0 fraction; the label is padded to the width
          # of "100%" so the bar beside it doesn't shift sideways as the number
          # gains a digit. swayosd's own volume OSD pins that label at four
          # characters for the same reason, but a client-drawn one has no width
          # to set — only the text.
          swayosd-client \
            --custom-icon "$icon" \
            --custom-progress "$(awk -v p="$pct" 'BEGIN { printf "%.2f", p / 100 }')" \
            --custom-progress-text "$(printf '%3d%%' "$pct")" \
            >/dev/null 2>&1 || true
          ;;
        message)
          swayosd-client \
            --custom-icon "$icon" \
            --custom-message "''${3:-}" \
            >/dev/null 2>&1 || true
          ;;
        *)
          echo "usage: osd [progress <icon> <percent>|message <icon> <text>]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Volume, and the display that goes with it.
  #
  # wpctl is still what moves the volume, with the same arguments the keybinds
  # used to carry inline — this exists so that changing it and showing it are
  # one action, and so that every route to the volume goes through one place.
  # There are three: the media keys, waybar's click to mute, and waybar's
  # scroll. That last one is why `up`/`down` take an optional step — the bar
  # scrolls in single points where a key moves five.
  #
  # The level is read back from wpctl after the change rather than tracked
  # here. That costs one extra call and buys a display that is telling the
  # truth: `volume show` on its own draws whatever the system is actually at,
  # including a level set from pavucontrol or by an application.
  #
  # Mute is a message rather than a greyed-out bar. swayosd's native volume OSD
  # dims the bar by marking the widget insensitive, which a client request
  # can't do — and "Muted" in words is clearer than a bar you have to notice is
  # a different shade anyway.
  #
  # Raising while muted stays muted, which is wpctl's behaviour and was this
  # config's before. The OSD makes that state visible instead of leaving you to
  # work out why the sound didn't come back.
  volume = pkgs.writeShellApplication {
    name = "volume";
    runtimeInputs = with pkgs; [
      wireplumber
      gawk
      coreutils
      osd
    ];
    text = ''
      # Percentage points per press. wpctl reads "5%+" and "0.05+" as the same
      # thing (its argument regex is `(\d*\.?\d*)(%?)([-+]?)`, and a `%` just
      # divides by 100); percent is the form here because the step can also
      # arrive as an argument, and waybar's scroll passes 1.
      default_step=5
      sink="@DEFAULT_AUDIO_SINK@"
      mic="@DEFAULT_AUDIO_SOURCE@"

      # Optional second argument on up/down. A non-number falls back rather
      # than failing: a mistyped step should still change the volume.
      step="''${2:-$default_step}"
      case "$step" in
        "" | *[!0-9]*) step="$default_step" ;;
      esac

      # `wpctl get-volume` prints "Volume: 0.65", or "Volume: 0.65 [MUTED]".
      show_sink() {
        state="$(wpctl get-volume "$sink" 2>/dev/null || true)"
        [ -n "$state" ] || return 0

        case "$state" in
          *MUTED*)
            osd message sink-volume-muted-symbolic "Muted"
            return 0
            ;;
        esac

        pct="$(printf '%s\n' "$state" | awk 'NR == 1 { printf "%d", $2 * 100 + 0.5 }')"

        # The same thresholds swayosd's native OSD uses, so the glyph means the
        # same thing however the volume was changed.
        if [ "$pct" -le 0 ]; then
          icon=muted
        elif [ "$pct" -le 33 ]; then
          icon=low
        elif [ "$pct" -le 66 ]; then
          icon=medium
        else
          icon=high
        fi

        osd progress "sink-volume-$icon-symbolic" "$pct"
      }

      # The microphone has no level bound to a key, only a mute toggle, so it
      # gets the state in words rather than a bar.
      show_mic() {
        state="$(wpctl get-volume "$mic" 2>/dev/null || true)"
        [ -n "$state" ] || return 0

        case "$state" in
          *MUTED*) osd message source-volume-muted-symbolic "Microphone muted" ;;
          *)       osd message source-volume-high-symbolic  "Microphone on" ;;
        esac
      }

      case "''${1:-}" in
        # -l 1.0 caps the sink at 100%. Software gain above that is available
        # in pavucontrol for the once-a-year quiet recording; on a key held
        # down it is a way to damage speakers.
        up)       wpctl set-volume "$sink" "''${step}%+" -l 1.0 ; show_sink ;;
        down)     wpctl set-volume "$sink" "''${step}%-"        ; show_sink ;;
        mute)     wpctl set-mute   "$sink" toggle               ; show_sink ;;
        mic-mute) wpctl set-mute   "$mic"  toggle               ; show_mic ;;
        set)
          [ -n "''${2:-}" ] || { echo "usage: volume set <percent>" >&2; exit 2; }
          wpctl set-volume "$sink" "$2%" -l 1.0
          show_sink
          ;;
        # Draw the current level without changing it.
        show) show_sink ;;
        *)
          echo "usage: volume [up|down [pct]|mute|mic-mute|set <pct>|show]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Brightness, across every backlight device rather than only the first.
  #
  # `brightnessctl set` with no --device picks the first device it finds and
  # adjusts that one alone. On the laptop there is exactly one — the internal
  # panel — so that was invisible. The desk reaches its monitors through
  # ddcci-backlight (modules/nixos/ddcci.nix), which registers one device per
  # display, and "the first one" there means a single monitor changes and the
  # other doesn't. Hence the loop.
  #
  # Also the reason the keybinds call this rather than brightnessctl directly:
  # a host with one display and a host with two want the same key to mean the
  # same thing.
  #
  # The rest of this is about a DDC/CI monitor being a thing that can *refuse*,
  # which a laptop panel never does. Writing `/sys/class/backlight/<dev>/
  # brightness` is a register write on a panel and a round trip to another
  # computer on a monitor, and the driver does not check the answer:
  # ddcci-backlight's update_status sends the command and reports success
  # (ddcci_monitor_writectrl) whether or not anything took it. So `brightness`
  # is only ever the last value *written*, and after a write the monitor missed
  # — asleep behind DPMS, or still bringing the link back up — it is a number
  # nothing on the desk agrees with.
  #
  # `actual_brightness` is the other one, and it is the honest one: reading it
  # makes the driver go and ask the monitor (ddcci_backlight_get_brightness is
  # a live VCP 0x10 read). It is also what waybar's backlight module reads, so
  # everything here reads it too — the bar and the OSD quoting two different
  # sysfs files about the same display is most of what "out of sync" meant.
  brightness = pkgs.writeShellApplication {
    name = "brightness";
    runtimeInputs = with pkgs; [
      brightnessctl
      util-linux
      coreutils
      osd
    ];
    text = ''
      step=5

      sysfs=/sys/class/backlight

      # Where `dim` records what it is about to leave, for `restore` to put
      # back. See `dim` below for why this isn't brightnessctl's --save.
      state="''${XDG_RUNTIME_DIR:-/tmp}/brightness.dim"

      # Serialise against other runs of this script.
      #
      # A DDC/CI write is a round trip over the monitor's own i2c bus, on the
      # order of 100ms per display — the kernel backlight of a laptop panel is
      # effectively instant by comparison. Holding the key down generates
      # presses far faster than the monitors can answer.
      #
      # Two acquisitions, because the two kinds of caller want opposite things
      # from a busy lock. A key press is one of a stream and the stream is
      # worth more than any single press, so `-n` drops it and the backlog
      # can't keep applying for seconds after the key is released. The idle
      # timer's dim and restore arrive once and have no successor to correct
      # them, so they wait — a dropped `restore` is a screen left dim with
      # nothing else coming to undo it.
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/brightness.lock"
      lock_now()  { flock -n 9; }
      lock_wait() { flock -w 15 9; }
      unlock()    { flock -u 9; }

      # Every backlight device, in a stable order.
      #
      # A glob rather than `brightnessctl --list`, which is readdir order and
      # so is whatever the kernel's directory hashing gives that boot. That
      # order decides which display speaks for the rest when none is pinned,
      # and a reading that moved between monitors from one boot to the next
      # would be worse than either answer.
      devices=()
      for path in "$sysfs"/*; do
        [ -e "$path/brightness" ] || continue
        devices+=("''${path##*/}")
      done

      if [ ''${#devices[@]} -eq 0 ]; then
        echo "brightness: no backlight devices — see modules/nixos/ddcci.nix" >&2
        exit 1
      fi

      # The display the OSD quotes. `local.niri.brightness.device` pins it to
      # the same one the bar reports (waybar.nix); unset leaves both to their
      # own idea of "first", which is the old behaviour and is fine on a
      # machine with one panel. See the option for how to find the name.
      primary="''${devices[0]}"
      configured=${lib.escapeShellArg primaryBacklight}
      if [ -n "$configured" ]; then
        if [ -e "$sysfs/$configured/brightness" ]; then
          primary="$configured"
        else
          echo "brightness: no backlight device '$configured'; using $primary" >&2
        fi
      fi

      # sysfs reads. Anything that isn't a plain number — a missing file, or a
      # DDC/CI read the monitor didn't answer — is a failure rather than a 0.
      read_int() {
        local v
        v="$(cat "$1" 2>/dev/null || true)"
        case "$v" in
          "" | *[!0-9]*) return 1 ;;
        esac
        printf '%s\n' "$v"
      }

      # What the display is at, falling back to what was last written to it
      # when the monitor won't say. See the header comment.
      actual()   { read_int "$sysfs/$1/actual_brightness" || read_int "$sysfs/$1/brightness"; }
      intended() { read_int "$sysfs/$1/brightness"; }
      maximum()  { read_int "$sysfs/$1/max_brightness"; }

      # One monitor refusing a write shouldn't stop the others moving.
      #
      # Raw values rather than brightnessctl's own `%`, `+n%` and `n%-`, so the
      # arithmetic below can start from `actual` — brightnessctl's relative
      # steps are computed from `brightness`, which is the number that goes
      # wrong. Still brightnessctl and not a plain `echo > sysfs`: it falls
      # back to logind's SetBrightness when the device isn't group-writable,
      # which is the fallback the laptop ran on for a long time.
      write() {
        brightnessctl --class=backlight --device="$1" --quiet set "$2" >/dev/null 2>&1 || true
      }

      # A step is `step`% of each device's own range, which is brightnessctl's
      # definition of `+5%` and keeps a 0–100 DDC monitor and a 0–96000 laptop
      # panel moving by the same visible amount.
      step_all() {
        local dir="$1" dev cur max delta target
        for dev in "''${devices[@]}"; do
          max="$(maximum "$dev")" || continue
          cur="$(actual "$dev")" || continue

          delta=$(( (step * max + 50) / 100 ))
          if [ "$delta" -lt 1 ]; then
            delta=1
          fi

          if [ "$dir" = up ]; then
            target=$(( cur + delta ))
          else
            target=$(( cur - delta ))
          fi

          # Clamping is ours now that the target is, and it has to be: a
          # monitor reporting 100 when the script thinks it is at 20 would
          # otherwise be asked for 105.
          if [ "$target" -lt 0 ]; then
            target=0
          elif [ "$target" -gt "$max" ]; then
            target="$max"
          fi

          write "$dev" "$target"
        done
      }

      set_all() {
        local pct="$1" dev max
        for dev in "''${devices[@]}"; do
          max="$(maximum "$dev")" || continue
          write "$dev" "$(( (pct * max + 50) / 100 ))"
        done
      }

      # The on-screen display, read back off the device rather than predicted
      # from the step — including the clamping above, which a predicted number
      # would get wrong at both ends of the range.
      #
      # One display speaks for all of them, and `round` matches waybar's
      # `round(actual * 100 / max)` so the pop-up and the bar can't disagree
      # by a percent. They can still each be right about a *different* number
      # if the monitors have drifted apart — one refused a write, or was
      # adjusted from its own buttons — which is what pinning `primary` is
      # for: at least it is always the same screen being quoted.
      show_osd() {
        local cur max
        max="$(maximum "$primary")" || return 0
        cur="$(actual "$primary")" || return 0
        [ "$max" -gt 0 ] || return 0

        osd progress display-brightness-symbolic "$(( (cur * 100 + max / 2) / max ))"
      }

      # Make the displays agree with what has been written to them.
      #
      # This is the repair for a write the monitor never took: ask it what it
      # is actually at, and write again if the answer disagrees. A monitor
      # coming out of DPMS needs a second or two before it will answer at all,
      # which is what the attempts are for, and a monitor that simply rounds
      # differently is why a unit of slack is close enough.
      #
      # The re-write is also the only thing that tells the bar to look. The
      # backlight class emits a uevent on every write to `brightness`,
      # including one that changes nothing, and waybar's backlight module
      # otherwise re-reads on its own poll interval — which is deliberately
      # slow (waybar.nix) precisely because each poll is a DDC/CI read.
      #
      # The lock is dropped between attempts on purpose. This can run for
      # several seconds while a monitor wakes up, and holding it throughout
      # would make every brightness key pressed in the meantime hit `flock -n`
      # and be thrown away. A press that lands in a gap changes `brightness`,
      # and the next attempt re-asserts that instead — the person at the
      # keyboard wins the argument.
      settle() {
        local dev want got diff pending attempt=0 attempts=6

        while [ "$attempt" -lt "$attempts" ]; do
          attempt=$(( attempt + 1 ))
          pending=0

          for dev in "''${devices[@]}"; do
            want="$(intended "$dev")" || continue
            got="$(actual "$dev")" || got=""

            if [ -n "$got" ]; then
              diff=$(( want - got ))
              if [ "''${diff#-}" -le 1 ]; then
                continue
              fi
            fi

            pending=1
            write "$dev" "$want"
          done

          if [ "$pending" -eq 0 ]; then
            return 0
          fi

          if [ "$attempt" -lt "$attempts" ]; then
            unlock
            sleep 1
            lock_wait || return 0
          fi
        done
      }

      # Record where every display is and drop them all to <percent>. This is
      # the swayidle dim warning; `restore` is its other half.
      #
      # The levels are kept here rather than through brightnessctl's --save
      # and --restore, because that pair has no idea whether it has already
      # saved. A second dim with no restore in between overwrote the saved
      # level with the *dimmed* one, and from then on every restore returned
      # the screen to 20% and stayed there until a key was pressed. That is a
      # latch rather than a glitch, and one dropped restore was enough to arm
      # it. The file's existence is the "already dimmed" flag that closes it.
      #
      # No OSD on either half: the dim is what happens when you have stopped
      # touching the machine, and the restore is what happens the instant you
      # touch it again. A pop-up on the second would fire on every return to
      # the desk, reporting a level that hasn't changed from what it was
      # before the timer ran.
      dim() {
        local pct="$1" dev cur

        if [ -e "$state" ]; then
          return 0
        fi

        : > "$state.new"
        for dev in "''${devices[@]}"; do
          cur="$(actual "$dev")" || continue
          printf '%s %s\n' "$dev" "$cur" >> "$state.new"
        done
        mv "$state.new" "$state"

        set_all "$pct"
      }

      restore() {
        local dev want

        if [ ! -e "$state" ]; then
          return 0
        fi

        while read -r dev want; do
          case "$want" in
            "" | *[!0-9]*) continue ;;
          esac
          write "$dev" "$want"
        done < "$state"

        rm -f "$state"
        settle
      }

      case "''${1:-}" in
        up)
          lock_now || exit 0
          step_all up
          show_osd
          ;;
        down)
          lock_now || exit 0
          step_all down
          show_osd
          ;;
        set)
          case "''${2:-}" in
            "" | *[!0-9]*) echo "usage: brightness set <percent>" >&2; exit 2 ;;
          esac
          lock_now || exit 0
          set_all "$2"
          show_osd
          ;;
        dim)
          case "''${2:-}" in
            "" | *[!0-9]*) echo "usage: brightness dim <percent>" >&2; exit 2 ;;
          esac
          lock_wait || exit 0
          dim "$2"
          ;;
        restore)
          lock_wait || exit 0
          restore
          ;;
        # Re-assert every display's level and wait for it to take. For the
        # moments a monitor was in no state to listen — coming out of DPMS,
        # coming out of suspend — where sysfs, the bar and the panel in front
        # of you can otherwise sit at three different answers. See lock.nix.
        sync)
          lock_wait || exit 0
          settle
          ;;
        *)
          echo "usage: brightness [up|down|set <pct>|dim <pct>|restore|sync]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # The power profile — power-saver, balanced, performance — and the pop-up
  # that goes with it.
  #
  # `powerprofilesctl` is what moves it, the same command the bar and every
  # other route already end up in; this exists so there is one place that knows
  # the order they cycle in and one place that knows what each looks like on
  # screen.
  #
  #   power-profile next / prev     step through the profiles the daemon offers
  #   power-profile set <name>      one by name
  #   power-profile show            draw the current one, changing nothing
  #
  # `show` is the drawing half, and it is deliberately not called from the
  # other three. Nothing here shows the profile it just set: the watcher below
  # does that, having heard the daemon say so, which is the only way a change
  # made from waybar, from Plasma's battery applet, from `powerprofilesctl` in
  # a terminal or by the daemon itself gets a pop-up too. Drawing here as well
  # would give the keybind two.
  #
  # The order is whatever `powerprofilesctl list` prints, rather than a list
  # written down here, so a machine whose driver offers a profile beyond the
  # usual three cycles through that one as well instead of skipping it — and
  # `next` means the same direction as the bar's left click, which walks the
  # daemon's list too.
  #
  # With nothing answering on the system bus, the three that change something
  # say so on stderr and exit non-zero, and `show` draws nothing at all. That
  # is a host without `services.power-profiles-daemon.enable`
  # (modules/nixos/desktop.nix), which is a configuration mistake rather than
  # something to report on screen to whoever pressed the key — and the same
  # condition already hides the bar's widget.
  powerProfile = pkgs.writeShellApplication {
    name = "power-profile";
    runtimeInputs = with pkgs; [
      power-profiles-daemon
      gawk
      osd
    ];
    text = ''
      # `powerprofilesctl list` prints one `  <name>:` line per profile, with a
      # `*` in the first column on the active one and its driver and degraded
      # state indented underneath. The anchors are what keep those detail lines
      # out: they are indented four spaces, so `^[* ] ` never reaches their
      # colon.
      profiles() {
        powerprofilesctl list 2>/dev/null |
          awk '/^[* ] [a-z-]+:$/ { sub(/:$/, "", $NF); print $NF }'
      }

      # A profile the daemon has no driver for is still a profile it accepts
      # and reports, so this is the state of the machine either way.
      current() {
        powerprofilesctl get 2>/dev/null
      }

      # Step through the list, wrapping. Same shape as `theme-cycle` above:
      # awk holds the list, finds the current entry and prints its neighbour,
      # falling back to the first entry when the current one isn't in the list
      # — which is what happens when the daemon is answering but `get` didn't.
      step() {
        local direction="$1" now
        now="$(current || true)"

        profiles | awk -v cur="$now" -v dir="$direction" '
          { list[NR] = $0 }
          END {
            if (NR == 0) exit 1
            for (i = 1; i <= NR; i++)
              if (list[i] == cur) {
                # 1-based and wrapping in both directions: +1 is i % NR + 1,
                # -1 is the same walk with NR - 2 added instead.
                print list[(i + (dir == "next" ? 0 : NR - 2)) % NR + 1]
                exit
              }
            print list[1]
          }'
      }

      apply() {
        [ -n "$1" ] || { echo "power-profile: no power profiles daemon" >&2; exit 1; }

        # Already there is not a failure, and it is reachable: two keypresses
        # in a row on a machine with one profile land here.
        [ "$1" != "$(current || true)" ] || exit 0

        if ! powerprofilesctl set "$1"; then
          echo "power-profile: could not set $1" >&2
          exit 1
        fi
      }

      case "''${1:-}" in
        next) apply "$(step next || true)" ;;
        prev) apply "$(step prev || true)" ;;
        set)
          [ -n "''${2:-}" ] || { echo "usage: power-profile set <profile>" >&2; exit 2; }
          apply "$2"
          ;;
        show)
          profile="$(current || true)"
          [ -n "$profile" ] || exit 0

          # Freedesktop icon names, from the icon theme rather than from the
          # set swayosd compiles in — it carries volume and brightness and
          # nothing else. Papirus-Dark, which this session wears (see
          # ./default.nix), ships all three under `symbolic/status`; a theme
          # that didn't would leave swayosd drawing its `missing-symbolic`
          # fallback beside the right words.
          #
          # The labels are capitalised rather than passed through as the
          # daemon's own lowercase identifiers, so the pop-up reads like the
          # rest of the session's messages ("Muted", "Microphone on").
          case "$profile" in
            power-saver) icon=power-profile-power-saver-symbolic ; label="Power saver" ;;
            balanced)    icon=power-profile-balanced-symbolic    ; label="Balanced" ;;
            performance) icon=power-profile-performance-symbolic ; label="Performance" ;;
            # A profile from a driver neither this case nor Papirus knows
            # about. The balanced glyph is the neutral one of the three and
            # the name is spelled out beside it, so the pop-up still says
            # which profile took.
            *)           icon=power-profile-balanced-symbolic    ; label="$profile" ;;
          esac

          osd message "$icon" "$label"
          ;;
        *)
          echo "usage: power-profile [next|prev|set <profile>|show]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Draw the power profile whenever it changes, whoever changed it.
  #
  # This is the whole reason the profile gets an OSD at all. Volume and
  # brightness are moved by the keys that draw them, so the pop-up can live in
  # the script that makes the change; the profile is not. It is moved by the
  # bar (waybar's `power-profiles-daemon` module has its own click handler and
  # takes no `on-click` of ours), by `powerprofilesctl` in a terminal, by a
  # `powerprofilesctl launch` hold that a game takes and gives back, and by the
  # daemon itself when it drops out of performance on a hot machine. So the
  # thing worth watching is the daemon, not any one route into it.
  #
  # `gdbus monitor` rather than `dbus-monitor`, and the difference matters
  # here: dbus-monitor asks the bus to make it a monitor, which the system
  # bus's default policy allows root and nobody else, so it fails in a user
  # session. gdbus subscribes to the signal instead — an ordinary AddMatch for
  # a broadcast, which the same policy allows — and PropertiesChanged is a
  # broadcast.
  #
  # `--dest` filters to the daemon's own connection, so the loop below is woken
  # by its properties and nothing else on the bus. The legacy
  # `net.hadess.PowerProfiles` name is the one asked for: the daemon has owned
  # it since it existed and still does alongside the newer
  # org.freedesktop.UPower.PowerProfiles, and both names are the same
  # connection — so a match on either sees the signals from both objects.
  #
  # `stdbuf -oL` because gdbus prints through stdio, which block-buffers once
  # its stdout is a pipe: without it a change would sit in a 4KB buffer instead
  # of reaching the loop.
  #
  # The profile is read back rather than parsed out of the signal, for the
  # reason `volume` reads wpctl back: it makes the pop-up describe the machine
  # rather than the event. It also means the loop doesn't care which property
  # changed — `PerformanceDegraded` and `ActiveProfileHolds` come through the
  # same signal, and they are filtered out here by the profile simply not
  # having moved.
  powerProfileOsd = pkgs.writeShellApplication {
    name = "power-profile-osd";
    runtimeInputs = with pkgs; [
      coreutils
      glib
      power-profiles-daemon
      powerProfile
    ];
    text = ''
      # What the session is already sitting at, so the first pop-up is a
      # change and not a report of the state at login.
      last="$(powerprofilesctl get 2>/dev/null || true)"

      stdbuf -oL gdbus monitor --system --dest net.hadess.PowerProfiles |
        while IFS= read -r line; do
          case "$line" in
            *PropertiesChanged*) ;;
            # gdbus also prints a line when the name changes owner, which is
            # the daemon being restarted. Nothing to draw for that, and the
            # readback below would only report a profile that hasn't moved.
            *) continue ;;
          esac

          profile="$(powerprofilesctl get 2>/dev/null || true)"
          [ -n "$profile" ] || continue
          [ "$profile" != "$last" ] || continue

          last="$profile"
          power-profile show
        done
    '';
  };

  # Audio visualiser for the bar. See the custom/cava module in waybar.nix.
  cavaConfig = pkgs.writeText "cava-waybar.conf" ''
    [general]
    # Eight glyphs in a status bar, not a full-screen visualiser — and every
    # frame is a waybar label redraw, so 30 rather than cava's default 60.
    framerate = 30
    bars = 8
    autosens = 1

    # After two seconds of silence cava stops doing FFT and just checks for
    # input once a second, until sound comes back. Nothing is playing most of
    # the time, and this is meant to be a detail rather than a background job.
    sleep_timer = 2

    [input]
    # pipewire-pulse is on (modules/nixos/niri.nix), and `pulse` with
    # `source = auto` follows the *default sink's* monitor — so it tracks
    # whichever output you switched to instead of a device named here.
    method = pulse
    source = auto

    [output]
    method = raw
    raw_target = /dev/stdout
    data_format = ascii
    # 0-7, one value per block glyph in the mapping below.
    ascii_max_range = 7
  '';

  # Eight bars of the playing audio, or nothing at all when it's quiet.
  #
  # Emitting an empty line is what hides it: waybar hides a custom module
  # whose text is empty. So the bar looks exactly as it did before whenever
  # the music stops, which is the point — the widget doesn't reserve a slot
  # or leave a flat row of glyphs sitting there.
  #
  # It follows *audio*, not the mpris player, so a notification chime blips it
  # for a moment too. That's deliberate: it needs no polling and no second
  # process, and it reacts within a frame. To tie it to the player instead,
  # the gate would have to be `playerctl --follow status` feeding this loop.
  #
  # No stdbuf anywhere in here, and it isn't an oversight — cava's raw output
  # is plain write(2) with no stdio buffer (output/raw.c), and bash flushes
  # its printf per iteration, so frames arrive one at a time on their own.
  cavaBar = pkgs.writeShellApplication {
    name = "cava-bar";
    runtimeInputs = [ pkgs.cava ];
    text = ''
      cava -p ${cavaConfig} | while IFS= read -r frame; do
        # `0;3;5;7;` -> `0357`
        bars="''${frame//;/}"

        # An all-zero frame is silence. Anything at all in 1-7 is sound.
        case "$bars" in
          *[1-7]*) ;;
          *) echo; continue ;;
        esac

        # Parameter substitution rather than sed or tr: this runs thirty times
        # a second, and a process per frame is not the way to draw a
        # decoration. The replacements can't collide — every result is a
        # non-digit.
        bars="''${bars//0/▁}"
        bars="''${bars//1/▂}"
        bars="''${bars//2/▃}"
        bars="''${bars//3/▄}"
        bars="''${bars//4/▅}"
        bars="''${bars//5/▆}"
        bars="''${bars//6/▇}"
        bars="''${bars//7/█}"

        printf '%s\n' "$bars"
      done
    '';
  };
  # Caps lock for the bar — the glyph while the lock is on, nothing at all
  # while it is off. See the custom/caps-lock module in waybar.nix.
  #
  # The empty line is the entire design. waybar hides a custom module whose
  # text is empty (Custom::update), and hiding is the only way for a module to
  # cost *no* room: a glyph styled invisible still holds its slot, and even a
  # zero-width label still costs the 6px `spacing` the bar puts between
  # modules, because GTK only skips that gap for children that are hidden
  # outright. So an indicator that is meant to exist only while the lock is on
  # has to be a custom module that prints nothing the rest of the time —
  # exactly the trick cava-bar above uses to vanish when the music stops.
  #
  # That is also why this isn't waybar's own `keyboard-state` module, which is
  # otherwise precisely this widget: it always draws its label, locked or not,
  # and no stylesheet can take that label out of the layout.
  #
  # It watches the LED rather than the key. The compositor owns the lock state
  # and mirrors it onto the caps LED of every keyboard, and the kernel hands
  # each EV_LED change to everything holding the device open (INPUT_PASS_TO_ALL
  # in drivers/input/input.c) — so a blocking select over the keyboards is the
  # whole loop. No polling, and the glyph turns over with the keypress rather
  # than at the next tick.
  #
  # Python rather than shell: the shell version is `evtest` piped into `read`,
  # which means picking the right event device out of a hex LED bitmask in
  # /proc/bus/input/devices, and stdbuf to defeat evtest's block buffering once
  # its stdout is a pipe. python-evdev asks each device what it supports and
  # reads the starting state with an ioctl, which is the part shell can't do
  # at all.
  #
  # Reading /dev/input needs the `input` group; joshr has it from
  # modules/nixos/users.nix. Without it every device fails to open, the script
  # finds no keyboards and exits, and the bar is simply short one module.
  capsLockWatch = pkgs.writeText "caps-lock-watch.py" ''
    """Print the caps lock glyph while caps lock is on, an empty line while it
    is off. One line per change, forever."""

    import select
    import sys

    from evdev import InputDevice, ecodes, list_devices

    GLYPH = "󰪛"


    def keyboards():
        """Every input device that reports a caps lock LED."""
        found = []
        for path in sorted(list_devices()):
            try:
                device = InputDevice(path)
            except OSError:
                continue
            if ecodes.LED_CAPSL in device.capabilities().get(ecodes.EV_LED, []):
                found.append(device)
            else:
                device.close()
        return found


    def emit(on):
        print(GLYPH if on else "", flush=True)


    def main():
        devices = keyboards()
        if not devices:
            emit(False)
            return 1

        state = any(ecodes.LED_CAPSL in device.leds() for device in devices)
        emit(state)

        while True:
            readable, _, _ = select.select(devices, [], [])
            for device in readable:
                try:
                    events = list(device.read())
                except BlockingIOError:
                    # Woken with nothing to read. Not an error, and not worth
                    # tearing the module down over.
                    continue
                except OSError:
                    # The keyboard was unplugged. Leave the slot empty and quit;
                    # waybar's restart-interval starts a fresh scan, which is
                    # also how a keyboard plugged in later gets picked up.
                    emit(False)
                    return 1

                for event in events:
                    if event.type != ecodes.EV_LED or event.code != ecodes.LED_CAPSL:
                        continue
                    if bool(event.value) != state:
                        state = bool(event.value)
                        emit(state)


    if __name__ == "__main__":
        sys.exit(main())
  '';

  capsLock = pkgs.writeShellApplication {
    name = "caps-lock";
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.evdev ])) ];
    text = ''
      exec python3 ${capsLockWatch}
    '';
  };

  # `gamemode-status` used to live here, next to caps-lock, and is now in
  # ./gamemode.nix — exported as `niriGamemode.gamemodeStatus` rather than
  # `niriScripts.gamemodeStatus`. It moved when the session grew a GameMode of
  # its own: the pad answers for that mode as well as for the daemon, so the
  # script became a thin reading of `niri-gamemode status` and belongs beside
  # the thing it now asks.
in
{
  home.packages = [
    themeApply
    themeMode
    themeCycle
    themeRandom
    themeMenu
    wallpaperSet
    wallpaperMenu
    wallpaperRandom
    wallpaperRestore
    switchUser
    whenActive
    idleInhibit
    osd
    volume
    brightness
    powerProfile
    powerProfileOsd
    cavaBar
    capsLock
  ]
  ++ lib.optionals (!useNoctalia) [
    # Noctalia owns locking, blanking, idling, the session panel — and now
    # screen capture. Keeping these legacy entry points out of the profile is
    # what keeps their Hyprlock, Swaylock, wayfreeze/slurp/grim runtime
    # closures off a Noctalia system.
    screenshot
    lockSession
    lockNow
    lockBlank
    unlockSession
    sessionMenu
  ];

  _module.args.niriScripts = {
    inherit
      themeApply
      themeMode
      themeCycle
      themeRandom
      themeMenu
      wallpaperMenu
      wallpaperRandom
      wallpaperRestore
      screenshot
      screenshotAnnotate
      lockSession
      lockNow
      lockBlank
      unlockSession
      switchUser
      sessionMenu
      whenActive
      idleInhibit
      osd
      volume
      brightness
      powerProfile
      powerProfileOsd
      cavaBar
      capsLock
      ;

    # Not a script: the patched swaylock that lock-session wraps. Exported so
    # lock.nix installs the same build rather than the stock one, which would
    # otherwise put an unpatched `swaylock` on PATH beside it.
    inherit swaylock;
  };

  # The long-running half of `theme-mode auto`.
  #
  # It runs under both shells and whatever the preference is, because it has
  # two jobs and only one of them is about "auto". The first is to notice the
  # system's light/dark preference changing and move the palette to match,
  # which only happens in "auto" — `sync_mode` checks. The second is to
  # notice `org.gnome.desktop.interface`'s gtk-theme and icon-theme being
  # reset underneath the session, which happens on every `nixos-rebuild
  # switch`: home-manager's gtk module owns those two keys declaratively and
  # writes its build-time values into dconf on activation. Without something
  # watching, a light session would go back to Adwaita-dark widgets and dark
  # folder icons at the next rebuild and stay there until the next login.
  #
  # `sync_mode` at startup rather than only on change, so a session that
  # begins with the key already disagreeing lands in the right mode before
  # anything is drawn.
  systemd.user.services.niri-theme-auto = {
    Unit = {
      Description = "Follow the system light/dark preference";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe themeMode} --watch";
      # `dconf watch` exits if the session bus goes away, which on this
      # desktop means the session is going away too — but a restart costs
      # nothing and a watcher that has quietly died is invisible.
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
