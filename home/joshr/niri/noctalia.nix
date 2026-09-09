{
  config,
  lib,
  pkgs,
  niriScripts,
  niriGamemode,
  ...
}:

# noctalia: the whole session shell in one process, as an alternative to the
# waybar stack.
#
# What this replaces
# ------------------
# The niri session is a compositor and nothing else, so everything around it
# had to be assembled from single-purpose daemons — waybar for the bar, dunst
# for notifications, swayosd for the volume/brightness pop-up, wofi for the
# launcher and every menu, cliphist for clipboard history, swayidle for the
# idle timers, swaylock/hyprlock for the lock screen, awww for the wallpaper.
# Eight programs, eight config formats, and a theme switcher whose job was
# largely to restart them all in the right order.
#
# noctalia is all of those in one process reading one TOML file:
#
#     waybar    -> [bar.main] and the widget list below
#     dunst     -> [notification]
#     swayosd   -> [osd]
#     wofi      -> [shell.launcher]
#     cliphist  -> [shell] clipboard_*
#     swayidle  -> [idle.behavior.*]
#     hyprlock  -> [lockscreen] and [lockscreen_widgets]
#     awww      -> [wallpaper]
#
# No home-manager module, and no flake input
# ------------------------------------------
# The shell starts from `pkgs.noctalia` and everything below is written out by
# hand. `local.niri.noctaliaSourcePatches` chooses between the ordinary cached
# package and a locally compiled derivation carrying the source-only extras,
# whose source is pinned to the release those patches were cut against —
# `noctaliaVersion` in the `let` below is the one place a version is named.
# The generated configuration, palettes, templates, plugins and hooks are the
# same on both sides of that choice.
# Upstream ships a home-manager module in its flake, and this used to use it,
# but it only generates the three files at the bottom of this comment and its
# flake publishes no substituter — so having it in `inputs` meant an extra
# lock entry, and any accidental reference to `packages.default` meant
# compiling a Qt/C++ project locally. What it generates is small enough to own:
#
#     ~/.config/noctalia/config.toml       from `settings`
#     ~/.config/noctalia/palettes/*.json   one per theme, from themes.nix
#     the systemd user service
#
# **Watch the attribute name.** nixpkgs carries both majors and they read
# backwards: `pkgs.noctalia` is the v5 line, which is what everything here is
# written against, and `pkgs.noctalia-shell` is 4.7.7 — it kept the
# repository's old name, which upstream changed to `noctalia` at v5. The v4
# config schema is different enough that the wrong one comes up with most of
# this ignored.
let
  useNoctalia = config.local.niri.shell == "noctalia";

  # The upstream release the three patches below are cut against.
  #
  # **This is the version to edit**, and the hash with it — nothing else here
  # names a version. `nix flake update` must not be able to move it, because
  # the patches are unified diffs against these exact files and a bump lands
  # as a failed `patchPhase` in the middle of an otherwise unrelated update.
  # Pinning turns "the flake update broke the desktop shell" into a separate
  # errand that can be done deliberately, which is worth more than being a
  # release or two ahead of a beta.
  #
  # Both values come from nixpkgs' own expression for this version
  # (pkgs/by-name/no/noctalia/package.nix). To move the pin: change the
  # version, set the hash to `lib.fakeHash`, build once, and put the hash the
  # error prints here — then expect to rebase the patches, which is the real
  # work. `tag` rather than `rev` matches upstream's packaging; the hash is
  # what actually pins the content, so a moved tag fails loudly rather than
  # quietly building something else.
  noctaliaVersion = "5.0.0-beta.7";
  noctaliaHash = "sha256-9RlJNIy2DFVm9SB2vwGEBsbHc1r3dIB+K+b+nd6Bdho=";

  # Only the patched side is pinned.
  #
  # `noctaliaSourcePatches = false` exists to get the package off the binary
  # cache's shelf and skip compiling a Qt/C++ project; overriding `src` there
  # would defeat exactly that and cost the laptop a local build for nothing —
  # it carries no patches for a version bump to break. The cost of the
  # asymmetry is that the two hosts can end up on different noctalia
  # releases, and `noctalia config validate` is what says so: it runs against
  # whichever package the host selected, so a key this config generates that
  # the laptop's newer stock package has renamed fails the laptop's build.
  # That failure is the signal to move the pin, not a reason to unpin.
  #
  # Note this pins the *source*, not the build recipe: buildInputs, meson
  # flags and the wrapper all still come from whatever nixpkgs currently
  # says. That is the right way round while the gap is small — it keeps
  # nixpkgs' packaging fixes — but it is also why the pin is not meant to sit
  # here for a year.
  noctaliaPackage =
    if config.local.niri.noctaliaSourcePatches then
      pkgs.noctalia.overrideAttrs (old: {
        version = noctaliaVersion;

        src = pkgs.fetchFromGitHub {
          owner = "noctalia-dev";
          repo = "noctalia";
          tag = "v${noctaliaVersion}";
          hash = noctaliaHash;
        };

        patches = (old.patches or [ ]) ++ [
          ./noctalia-lock-transition.patch
          ./noctalia-user-media.patch
          ./noctalia-clock-shadow-offset.patch
        ];
      })
    else
      pkgs.noctalia;
  noctalia = lib.getExe noctaliaPackage;

  paletteSet = import ./noctalia-palettes.nix { inherit lib; };

  tomlFormat = pkgs.formats.toml { };
  jsonFormat = pkgs.formats.json { };

  # The same directories the scripts in ./scripts.nix use, spelled the same
  # way. `resolvedThemeFile` in particular is the fan-out point: the SDDM sync
  # in modules/nixos/niri.nix and the Limine sync in modules/nixos/boot.nix
  # both watch it and both read their palette out of it, and it is the one
  # description of a colour scheme that survives leaving this user's session.
  stateDir = "${config.home.homeDirectory}/.local/state/niri-theme";
  resolvedThemeFile = "${stateDir}/noctalia-resolved";
  liveThemeDir = "${stateDir}/noctalia-live";
  activeThemeDir = "${stateDir}/active";
  spotifyThemeDir = "${config.home.homeDirectory}/.local/state/noctalia-spotify";
  wallpaperDir = "${config.home.homeDirectory}/.local/share/wallpapers";
  screenshotDir = "${config.home.homeDirectory}/Pictures/Screenshots";

  # The bar's visualiser is a per-host opt-in, exactly as it was on waybar. The
  # lock screen's is a separate opt-in of its own (local.niri.cavaInLockscreen,
  # read by lockWidgets further down) — under waybar there was only ever the
  # bar to ask about, and noctalia having both is no reason to make them one
  # answer.
  #
  # cava itself is gone from the picture: waybar had no visualiser, so
  # `custom/cava` was a script feeding it one frame of glyphs per line, where
  # noctalia draws its own from the PipeWire stream. The script and the package
  # stay for the full-size terminal version.
  # The widget type is spelled once because three places need it: the bar lane
  # below, the lock screen's own visualizer entries, and the GameMode overlay
  # near the bottom of this file, which finds both by this name and switches
  # them off.
  visualiserWidget = "audio_visualizer";

  visualiser = lib.optional config.local.waybar.cavaInBar visualiserWidget;

  # --- the GameMode indicator -------------------------------------------
  #
  # The one bar slot that has no noctalia widget behind it, as a local Luau
  # plugin in ./noctalia-plugins/gamemode-indicator. Its two files are built
  # rather than copied verbatim for the reason every `command` in this file is
  # an absolute store path: the widget shells out to `niri-gamemode`, and the
  # shell runs as a systemd user service, whose PATH is the user manager's
  # rather than the one a login shell assembles from the profile. Substituting
  # the script in makes "is it on PATH" not a question this depends on.
  #
  # **It is the indicator for the whole mode**, not only for the daemon.
  # `niri-gamemode status` answers in one word — `game`, `manual`, `daemon` or
  # `off` — so the pad is lit by a Mod+G with nothing running exactly as it is
  # by a game, and the tooltip is what says which. Before ./gamemode.nix
  # existed this polled `gamemode-status` and could only ever mean "a game
  # holds gamemode".
  #
  # Installing it is only half of it — see `plugins.enabled` in the settings
  # below, without which the registry finds this and skips it.
  #
  # `--replace-fail` rather than `--subst-var-by`: a widget.luau that has lost
  # the placeholder should stop the build, not ship a plugin quietly trying to
  # execute the literal string.
  gamemodeIndicator = pkgs.runCommand "noctalia-plugin-gamemode-indicator" { } ''
    mkdir -p "$out"
    cp ${./noctalia-plugins/gamemode-indicator/plugin.toml} "$out/plugin.toml"
    substitute ${./noctalia-plugins/gamemode-indicator/widget.luau} "$out/widget.luau" \
      --replace-fail '@niriGamemode@' ${lib.getExe niriGamemode.niriGamemode}
  '';

  # --- hooks ------------------------------------------------------------
  #
  # Carry changes noctalia made outward to the pieces of the session that do
  # not read its palette directly.

  # Wallpaper -> the login screen.
  #
  # modules/nixos/niri.nix watches ~/.local/state/niri-theme/wallpaper with a
  # systemd path unit and copies whatever it names somewhere the greeter's own
  # user can read, converting it to PNG on the way. Under the waybar stack
  # `wallpaper-set` wrote that file; noctalia owns the wallpaper now and knows
  # nothing about the greeter, so this is the one line that keeps the login
  # screen wearing the same image as the desktop.
  #
  # Written through a temporary file and renamed, because the reader is woken
  # by the write: `PathChanged` fires on close, and a half-written path would
  # be read as a filename that doesn't exist.
  sddmWallpaperSync = pkgs.writeShellApplication {
    name = "noctalia-sddm-wallpaper-sync";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      path="''${NOCTALIA_WALLPAPER_PATH:-}"
      [ -n "$path" ] || exit 0
      [ -f "$path" ] || exit 0

      mkdir -p ${lib.escapeShellArg stateDir}
      tmp="${stateDir}/wallpaper.tmp"
      printf %s "$path" > "$tmp"
      mv -f "$tmp" "${stateDir}/wallpaper"
    '';
  };

  # Noctalia palette -> niri overview backdrop.
  #
  # The builtin niri template already resolves Noctalia's live `surface`
  # colour into ~/.config/niri/noctalia.kdl, but it only themes borders,
  # shadows and hints. The overview backdrop is absent, so it keeps the colour
  # from theming.nix even when Noctalia changes to a builtin, wallpaper, or
  # community palette that has no corresponding theme directory.
  #
  # Run after the templates and read the same manifest SDDM and Limine read.
  # It is rendered directly from Noctalia's colour roles, so this no longer
  # depends on the formatting of the builtin niri template. Replacing the
  # file atomically gives niri one complete config change to live-reload
  # instead of a partially appended KDL block.
  niriOverviewSync = pkgs.writeShellApplication {
    name = "noctalia-niri-overview-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      fragment=${lib.escapeShellArg "${config.xdg.configHome}/niri/noctalia.kdl"}
      [ -f "$fragment" ] || exit 0

      surface="$(sed -n \
        's/^bg=\(#[0-9A-Fa-f]\{6\}\)$/\1/p' \
        ${lib.escapeShellArg resolvedThemeFile} | head -n1 || true)"
      [ -n "$surface" ] || exit 0

      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT

      sed \
        '/^\/\/ >>> NOCTALIA NIRI OVERVIEW >>>$/,/^\/\/ <<< NOCTALIA NIRI OVERVIEW <<<$/d' \
        "$fragment" > "$tmp"

      printf '%s\n' \
        "" \
        '// >>> NOCTALIA NIRI OVERVIEW >>>' \
        'overview {' \
        "    backdrop-color \"$surface\"" \
        '}' \
        '// <<< NOCTALIA NIRI OVERVIEW <<<' >> "$tmp"

      mv -f "$tmp" "$fragment"
      trap - EXIT
    '';
  };

  # Make the generated Vencord theme active without replacing any other local
  # themes. Vencord and Vesktop use the same settings schema but keep separate
  # data directories. Their theme watcher repaints a running client when the
  # enabled file changes; the first deployment needs one client restart so its
  # in-memory settings pick up the added filename.
  vencordThemeEnable = pkgs.writeShellApplication {
    name = "noctalia-vencord-theme-enable";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      config_home="''${XDG_CONFIG_HOME:-${config.xdg.configHome}}"

      for data_dir in "$config_home/Vencord" "$config_home/vesktop"; do
        settings="$data_dir/settings/settings.json"
        mkdir -p "$(dirname "$settings")"

        if [ -s "$settings" ]; then
          if ! updated="$(jq '
            if type == "object" then . else {} end
            | .enabledThemes = (((.enabledThemes // []) + ["noctalia.theme.css"]) | unique)
          ' "$settings")"; then
            echo "noctalia: not changing invalid Vencord settings: $settings" >&2
            continue
          fi
        else
          updated='{"enabledThemes":["noctalia.theme.css"]}'
        fi

        tmp="$(mktemp "$(dirname "$settings")/.settings.json.XXXXXX")"
        printf '%s\n' "$updated" > "$tmp"
        if [ -f "$settings" ] && cmp -s "$settings" "$tmp"; then
          rm -f "$tmp"
        else
          mv -f "$tmp" "$settings"
        fi
      done
    '';
  };

  # Colour scheme -> everything that is not the shell.
  #
  # The previous version reverse-engineered Kitty, btop and niri output. That
  # made three unrelated builtin templates an accidental API, and one missing
  # or slightly reformatted value prevented the manifest from being written at
  # all. Noctalia now renders the manifest and each app file directly from its
  # colour roles. This post-hook only validates those outputs and publishes the
  # completed live directory.
  #
  # Repointing `active` is the load-bearing half: kdeglobals — and so Dolphin
  # and every other Qt app in the session — plus the local VS Code theme
  # extension follow that symlink. Merely writing `current=noctalia-live`, as
  # an earlier hook did, woke the system path units while leaving those
  # applications on a prebuilt Nix palette.
  themeResync = pkgs.writeShellApplication {
    name = "noctalia-theme-resync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.dbus
      vencordThemeEnable
    ];
    text = ''
      manifest=${lib.escapeShellArg resolvedThemeFile}

      required_outputs=(
        "$manifest"
        ${lib.escapeShellArg "${liveThemeDir}/kdeglobals"}
        ${lib.escapeShellArg "${liveThemeDir}/vscode-extension/package.json"}
        ${lib.escapeShellArg "${liveThemeDir}/vscode-extension/themes/niri-color-theme.json"}
        ${lib.escapeShellArg "${liveThemeDir}/wofi.css"}
        ${lib.escapeShellArg "${liveThemeDir}/wofi-emoji.css"}
        ${lib.escapeShellArg "${spotifyThemeDir}/colors.css"}
        ${lib.escapeShellArg "${config.xdg.configHome}/Vencord/themes/noctalia.theme.css"}
        ${lib.escapeShellArg "${config.xdg.configHome}/vesktop/themes/noctalia.theme.css"}
      )

      for output in "''${required_outputs[@]}"; do
        if [ ! -s "$output" ]; then
          echo "noctalia: refusing to publish an incomplete theme; missing $output" >&2
          exit 1
        fi
      done

      for key in bg bg_alt fg fg_dim accent accent_dim warn err border \
                 color0 color1 color2 color3 color4 color5 color6 color7 \
                 color8 color9 color10 color11 color12 color13 color14 color15; do
        if ! grep -Eq "^$key=#[0-9A-Fa-f]{6}$" "$manifest"; then
          echo "noctalia: invalid or missing '$key' in $manifest" >&2
          exit 1
        fi
      done

      mkdir -p ${lib.escapeShellArg stateDir}
      ln -sfn ${lib.escapeShellArg liveThemeDir} ${lib.escapeShellArg activeThemeDir}
      noctalia-vencord-theme-enable

      # `current` is a sentinel now and nothing more.
      #
      # Nothing selects anything from it: SDDM and Limine read the manifest,
      # Spotify reads the live CSS through its private mount namespace, and
      # none of the three can be described by a palette *name* in the first
      # place. What is left is a
      # marker that says which of the two shells last wrote this directory —
      # which is what keeps the waybar branch of theming.nix's activation from
      # mistaking a noctalia session for a stale prebuilt theme.
      current_tmp="$(mktemp ${lib.escapeShellArg "${stateDir}/current.XXXXXX"})"
      printf '%s\n' noctalia-live > "$current_tmp"
      mv -f "$current_tmp" "${stateDir}/current"

      # KDE's palette-changed broadcast, which is what Plasma itself sends
      # when a colour scheme is applied. Qt clients that listen — anything
      # loading plasma-integration, which is everything in this session —
      # repaint now, and the rest read kdeglobals on their next launch.
      dbus-send --session --type=signal \
        /KGlobalSettings org.kde.KGlobalSettings.notifyChange \
        int32:0 int32:0 >/dev/null 2>&1 || true
    '';
  };

  # --- lock screen ------------------------------------------------------
  #
  # The desktop session panel and lock screen normally read one shared action
  # list. Noctalia only filters `lock` and `lock_and_suspend` while locked, so
  # putting reboot and power-off back in the desktop panel would put them on
  # the lock screen too. There is no per-surface action list in v5.
  #
  # Keep the desktop panel complete, hide the login box's shared action row,
  # and draw two lockscreen button widgets instead: Suspend and Switch user.
  # The login box, those buttons, and the clock are positioned from the mode
  # already declared in `local.niri.outputs`; a monitor change therefore moves
  # the whole composition rather than leaving fixed coordinates behind.
  #
  # **Battery is not here, and cannot be.** noctalia has no battery widget for
  # the lock screen or the desktop — the widget types are clock, label,
  # button, sysmon, media_player, weather, sticker, volume, the two
  # visualisers and login_box, and sysmon's stats are CPU, GPU, RAM, swap and
  # network with nothing for the power supply. There is no official plugin for
  # it either. The charge remains on the bar and in the control centre.

  # "2560x1440@180.000" -> { w = 2560; h = 1440; }, null if it doesn't parse.
  parseMode =
    mode:
    let
      m = builtins.match "([0-9]+)x([0-9]+)(@.*)?" mode;
    in
    if m == null then
      null
    else
      {
        w = lib.toInt (builtins.elemAt m 0);
        h = lib.toInt (builtins.elemAt m 1);
      };

  # Outputs that get a clock. `local.niri.outputs` is the good case — it
  # carries the mode, so the clock lands in the middle of the display. A host
  # that leaves the layout to niri's auto-detection (the laptop) has no modes
  # to read, so `local.niri.lockClockOutputs` names the connectors and the
  # position falls back to a 1080p centre, which clamping then pulls onto
  # whatever the panel actually is.
  lockOutputs =
    if config.local.niri.lockClockOutputs != [ ] then
      map (name: {
        inherit name;
        mode = null;
        scale = null;
        off = false;
      }) config.local.niri.lockClockOutputs
    else
      map (o: {
        inherit (o) name mode off;
        scale = o.scale;
      }) config.local.niri.outputs;

  # With local.niri.cavaInLockscreen on, one full-output audio visualizer; then
  # a compact login box, an auto-hiding media player, two lock-safe buttons,
  # and two clock widgets per output.
  #
  # A clock widget has one font size, so "time bigger than the date" cannot be
  # done inside a single `format` string — it needs two widgets sized
  # independently. And the *only* size control noctalia exposes for a lock
  # screen widget is the box: with both `box_width` and `box_height` set the
  # widget scales its content to fill them, aspect-preserved
  # (`contentScaleForBox`), and the clock's font is
  # `fontSizeBody * 4 * contentScale`. There is no `font_size` setting, and no
  # `scale` key on a widget in this version. So the boxes below *are* the type
  # scale, and they are fractions of the output rather than fixed pixels so
  # the proportions hold on a 1080p panel and a 1440p one alike.
  #
  # The clock pair sits above the login box. The two buttons sit below it and
  # replace the shared session-action row that is disabled on the login box.
  lockWidgets = lib.listToAttrs (
    lib.concatMap (
      o:
      let
        parsed = if o.mode == null then null else parseMode o.mode;
        scale = if o.scale == null then 1 else o.scale;

        # Logical pixels, which is the space widgets are positioned in — a
        # scaled output occupies mode / scale, the same arithmetic the
        # `position` fields in local.niri.outputs are written in.
        w = builtins.floor ((if parsed == null then 1920 else parsed.w) / (scale + 0.0));
        h = builtins.floor ((if parsed == null then 1080 else parsed.h) / (scale + 0.0));

        timeW = builtins.floor (w * 0.30);
        timeH = builtins.floor (h * 0.13);
        dateW = builtins.floor (w * 0.22);
        dateH = builtins.floor (h * 0.045);

        cx = w / 2;
        timeCy = builtins.floor (h * 0.26);

        # The native compact layout is one control-height row plus padding.
        # Keep its upstream 400px width cap.
        loginW = lib.min 400 (w - 48);
        loginH = 72;
        loginCy = h - 84 - (loginH / 2);

        # The login box draws a prompt line — "Please enter your password" —
        # *above* the row it declares, so that text is outside `loginH` and
        # the box's own geometry says nothing about it. Media sitting a plain
        # gap above `loginCy - loginH/2` therefore landed on top of the
        # prompt. This clears the prompt's line box (body text plus its
        # leading) and then leaves the same visual gap above it, which is what
        # puts the player above the message rather than across it.
        promptClearance = 30;

        # The same width as the login box below it, so the two panels read as
        # one column rather than as a narrow slab floating over a wider one.
        mediaW = loginW;
        mediaPad = 10;
        mediaInnerW = mediaW - (2 * mediaPad);

        # Upstream's horizontal media_player at content scale 1: a 120px cover,
        # 6px of spacing, and a text column one and a half covers wide. The
        # cover is the full height of that layout — the title, artist and
        # transport controls all live in the column beside it — so the widget's
        # natural content box is 306x120 and its height *is* the album art.
        mediaArt = 120.0;
        mediaNaturalW = mediaArt + 6.0 + (mediaArt * 1.5);

        # Which is what makes the height worth deriving rather than writing
        # down. A boxed widget paints its panel at the full box, but scales its
        # content to fit inside it aspect-preserved, at
        # `min(innerW / naturalW, innerH / naturalH)` over the box less its
        # background padding on each edge (`contentScaleForBox`). So the
        # smaller of those two ratios sizes the cover, and a fixed height
        # against a box this wide is the smaller one every time: 132 under the
        # width above scales the content to 0.93 and centres it in a panel
        # 57px wider than it on either side, which is the squeezed art.
        #
        # Solving for the height that makes the *width* bind instead gives a
        # cover of `innerW * 120 / 306` and content that fills the padded box
        # on both axes. Ceiling rather than rounding, so the height is never
        # the fractional pixel short that would hand the fit back to it.
        mediaH = builtins.ceil (mediaInnerW * mediaArt / mediaNaturalW) + (2 * mediaPad);
        mediaCy = loginCy - (loginH / 2) - promptClearance - 32 - (mediaH / 2);

        buttonW = 170;
        buttonH = 42;
        buttonGap = 12;
        buttonOffset = (buttonW + buttonGap) / 2;
        buttonCy = h - 42;

        # Baselines touch rather than overlap: half of each box plus a small
        # gap. Derived from the boxes above so changing the type scale moves
        # the date with it instead of leaving a hole.
        dateCy = timeCy + builtins.floor (timeH * 0.5) + builtins.floor (dateH * 0.5) + builtins.floor (h * 0.012);

        # The date's drop shadow, in the units noctalia measures one in.
        #
        # A clock widget's shadow is drawn at `shadow_offset * contentScale`
        # with no blur (`applyShadow`, desktop_clock_widget.cpp), and
        # contentScale is exactly what the box does to the type. So the
        # `shadow = true` both clocks share buys the time a shadow several
        # pixels clear of its glyphs, and the date — whose box is about three
        # times smaller — one hard pixel at 60% black: on, and invisible. That
        # is what this fixes. The setting was never missing; it was scaled away.
        #
        # Multiplying by the boxes' ratio cancels the content scale out, so the
        # date's shadow falls the same distance in real pixels as the time's
        # and the two read as one composition. Derived from the boxes rather
        # than written down as 4.3 so it follows the type scale if those move:
        # both widgets fit on height (a label's natural height doesn't depend
        # on its text, and neither box is narrow enough for width to bind
        # first), which makes their content scales the ratio of the heights.
        #
        # `shadow_offset` is ours — ./noctalia-clock-shadow-offset.patch, since
        # upstream hardcodes 1.5 and exposes no way to reach it. Emitted only
        # where that patch is: `noctalia config validate` runs against whichever
        # package the host selected, so on `noctaliaSourcePatches = false` an
        # unknown key would fail the build rather than be ignored, and the
        # laptop keeps upstream's proportional-and-invisible shadow.
        dateShadow = lib.optionalAttrs config.local.niri.noctaliaSourcePatches {
          shadow_offset = 1.5 * timeH / dateH;
        };

        common = {
          type = "clock";
          output = o.name;

          settings = {
            clock_style = "digital";
            center_text = true;

            # Poppins for both. It is a geometric sans with a tall x-height,
            # which is what makes a very large time read as deliberate rather
            # than as the UI font blown up — and the shell's own
            # FiraCode Nerd Font is a monospace, which at this size looks like
            # a terminal rather than a clock.
            font_family = "Poppins";

            # No panel behind either. A slab of surface colour under a clock
            # on top of a wallpaper is the least elegant thing the widget can
            # do, and it is also the expensive one — it drops a rounded rect
            # and an alpha layer per widget per output per frame.
            background = false;

            # Which makes the text shadow load-bearing rather than
            # decorative: with no panel behind it, it is the only thing
            # keeping the time legible over a pale wallpaper.
            #
            # Enough on its own only for the time. The date is small enough
            # that the same setting draws a shadow nobody can see, and it needs
            # the offset below as well — see dateShadow.
            shadow = true;
          };
        };

        lockButton = {
          type = "button";
          output = o.name;
          cy = buttonCy;
          box_width = buttonW;
          box_height = buttonH;

          settings = {
            background = true;
            font_family = "Poppins";
            variant = "secondary";
          };
        };
      in
      (lib.optionals config.local.niri.cavaInLockscreen [
        # First in widget_order below, so it paints behind every other custom
        # lock-screen widget. The login panel is a later root layer too. With
        # no background or padding the spectrum fills the entire logical
        # output, and show_when_idle=false fades it away when playback stops.
        (lib.nameValuePair "audio_visualizer_${o.name}" {
          type = visualiserWidget;
          output = o.name;
          cx = cx;
          cy = h / 2;
          box_width = w;
          box_height = h;

          settings = {
            bands = 64;
            mirrored = true;
            centered = false;
            show_when_idle = false;
            color_1 = "primary";
            color_2 = "secondary";
            background = false;
            background_padding = 0;
          };
        })
      ])
      ++ [
        (lib.nameValuePair "login_box_${o.name}" {
          type = "login_box";
          output = o.name;
          cx = cx;
          cy = loginCy;
          box_width = loginW;
          box_height = loginH;

          settings = {
            layout = "compact";
            show_session_buttons = false;
            show_weather = false;
            show_media = false;
          };
        })
        (lib.nameValuePair "media_player_${o.name}" {
          type = "media_player";
          output = o.name;
          cx = cx;
          cy = mediaCy;
          box_width = mediaW;
          box_height = mediaH;

          settings = {
            vertical = false;
            hide_when_no_media = true;
            background = true;
            background_opacity = 0.82;
            background_radius = 16;
            background_padding = mediaPad;
            shadow = true;
          };
        })
        (lib.nameValuePair "clock_time_${o.name}" (
          lib.recursiveUpdate common {
            cx = cx;
            cy = timeCy;
            box_width = timeW;
            box_height = timeH;
            settings.format = "{:%-I:%M %p}";
          }
        ))
        (lib.nameValuePair "clock_date_${o.name}" (
          lib.recursiveUpdate common {
            cx = cx;
            cy = dateCy;
            box_width = dateW;
            box_height = dateH;
            settings = {
              format = "{:%A, %B %-d}";
            }
            // dateShadow;
          }
        ))
        (lib.nameValuePair "lock_suspend_${o.name}" (
          lib.recursiveUpdate lockButton {
            cx = cx - buttonOffset;
            settings = {
              glyph = "moon";
              label = "Suspend";
              command = "${pkgs.systemd}/bin/systemctl suspend";
            };
          }
        ))
        (lib.nameValuePair "lock_switch_user_${o.name}" (
          lib.recursiveUpdate lockButton {
            cx = cx + buttonOffset;
            settings = {
              glyph = "users";
              label = "Switch user";
              command = lib.getExe niriScripts.switchUser;
            };
          }
        ))
      ]
    ) (lib.filter (o: !o.off) lockOutputs)
  );

  # This is paint order as well as editor order: the lock-screen host appends
  # widget scene nodes in this sequence. Keep the full-screen visualizer first
  # and list every widget, because an explicit order is authoritative.
  lockWidgetOrder = lib.concatMap (
    o:
    lib.optional config.local.niri.cavaInLockscreen "audio_visualizer_${o.name}"
    ++ [
      "clock_time_${o.name}"
      "clock_date_${o.name}"
      "media_player_${o.name}"
      "lock_suspend_${o.name}"
      "lock_switch_user_${o.name}"
      "login_box_${o.name}"
    ]
  ) (lib.filter (o: !o.off) lockOutputs);

  settings = {
    shell = {
      # The bar's font under waybar, kept so the glyphs in the widget labels
      # have the same metrics they did. noctalia has one font family for all
      # shell text and no separate mono field.
      font_family = "FiraCode Nerd Font";

      time_format = "{:%I:%M %p}";
      date_format = "%a, %b %d";

      # A polkit agent already runs in this session — modules/nixos/niri.nix
      # starts polkit-kde-agent as a user service, because the disk tools in
      # modules/nixos/disk-managements.nix need one. Two agents racing for the
      # same authority is the failure this avoids.
      polkit_agent = false;

      # How a typed password is masked, in every noctalia password field —
      # which on this session means the lock screen's login box and nothing
      # else, since the polkit agent above is off.
      #
      # `"default"` draws one filled circle per character. `"random"` cycles a
      # seven-glyph set — circle, pentagon, star, rounded square, guitar pick,
      # blob, triangle — indexed by the character's position, so the row of
      # shapes is fixed for a given length rather than reshuffled per
      # keystroke. That is the point of it over uniform dots: a varied row
      # gives the eye something to count against, so a typo is visible as a
      # wrong-length pattern from further away than a run of identical dots
      # is, without any of the characters becoming recoverable.
      #
      # Upstream key, present on both sides of `noctaliaSourcePatches` — the
      # gating that ./noctalia-clock-shadow-offset.patch's `shadow_offset`
      # needs does not apply here.
      password_style = "random";

      # Clipboard history, replacing cliphist. 300 entries is the cap the
      # cliphist unit carried, chosen there because images are stored too and
      # an entry can cost a screenshot's worth of disk rather than a line's.
      clipboard_enabled = true;
      clipboard_history_max_entries = 300;

      niri_overview_type_to_launch_enabled = true;
      settings_show_advanced = true;

      privacy = {
        # cava opens a PipeWire source to read the *output* stream, which is
        # not a microphone in use — without this the privacy indicator sits
        # lit whenever the visualiser is running. Same exclusion the old
        # `waybar-microphone-privacy` helper made in jq (see ./privacy.nix),
        # now one setting.
        mic_filter_regex = "cava";
      };

      launcher = {
        categories = true;
        show_icons = true;
        sort_by_usage = true;

        # No currency rates. This config pins its inputs and the shell should
        # not reach out to a third-party API on its own; the calculator
        # provider still does arithmetic offline.
        fetch_exchange_rates = false;
      };

      # Region and full-screen capture, replacing the wayfreeze/slurp/grim
      # script this session used to bind Print to (it survives for the waybar
      # shell; see ./scripts.nix). noctalia captures through wlr-screencopy
      # itself, which removes the part of the old script that was hardest to
      # keep working: nothing has to map a freeze surface and then a selection
      # surface above it in the right order any more, because the overlay that
      # dims and selects *is* the frozen frame.
      screenshot = {
        directory = screenshotDir;

        # The same month-day-year, 12-hour stamp as the old script and as
        # niri's own `screenshot-path` — see the comment there before changing
        # it, since the three are meant to agree. noctalia appends ".png".
        filename_pattern = "screenshot_%m-%d-%Y_%I-%M-%S-%p";

        # Everything a capture becomes goes through satty, so noctalia does
        # neither of the two things it would otherwise do with the PNG. Saving
        # here would write the unannotated shot and then satty would write the
        # annotated one over it — or beside it, if the editor was cancelled,
        # leaving a file the old script never produced. Copying here would put
        # the unannotated image on the clipboard and then satty's own
        # `--copy-command` would replace it on save, so the clipboard's
        # contents between those two moments would be a picture nobody asked
        # for.
        save_to_file = false;
        copy_to_clipboard = false;

        # `pipe_command` alone does nothing: noctalia gates it on this flag,
        # so the pair has to be set together.
        pipe_to_command = true;
        pipe_command = lib.getExe niriScripts.screenshotAnnotate;

        # Same setting, same reasoning, now enforced by the shell rather than
        # by wayfreeze — see local.niri.screenshotFreeze.
        freeze_screen = config.local.niri.screenshotFreeze;

        # What `Shift+Print` used to be a separate script mode for. The overlay
        # opens with the previous region already selected and waiting on Enter,
        # so re-shooting the same frame is the key and then Enter, and drawing
        # a new box is the key and then a drag — one command covering both,
        # where slurp could not pre-fill a selection at all.
        remember_last_region = true;

        # A drawn selection is confirmed with Enter rather than captured on
        # mouse-up. It costs a keypress on every shot and buys the nudge: the
        # box stays live after the drag, so an edge that landed a few pixels
        # off is dragged back into place instead of being a shot to throw away
        # and redo. It is also what makes the two paths one gesture — a
        # remembered region arrives already in this state, so "adjust, then
        # Enter" is the same ending either way.
        confirm_region = true;

        # grim did not draw the pointer either.
        show_cursor = false;
      };

      # --- where the panels open ----------------------------------------
      #
      # Attached rather than floating: a panel that hangs off the bar reads as
      # belonging to the widget that opened it, where a floating one appears
      # in the middle of the screen with nothing connecting the two.
      #
      # `open_near_click_*` is what puts them on the *right*. Attached panels
      # are otherwise centred on the bar, so the control centre — whose widget
      # is at the far right end — opened in the middle of the screen and had
      # to be tracked back to the icon that produced it. With this they drop
      # directly under what was clicked, which for everything in the
      # right-hand cluster means the right-hand side.
      #
      # The launcher is deliberately not in that list. It is a search box
      # rather than a menu belonging to a widget, it is opened from the
      # keyboard as often as from the bar, and centred is where a search box
      # is expected.
      panel = {
        transparency_mode = "soft";
        borders = true;
        shadow = true;

        launcher_placement = "floating";
        launcher_position = "center";

        control_center_placement = "attached";
        session_placement = "attached";
        wallpaper_placement = "attached";
        clipboard_placement = "attached";

        open_near_click_control_center = true;
        open_near_click_session = true;
        open_near_click_wallpaper = true;
        open_near_click_clipboard = true;
      };

      # --- what the desktop session panel offers --------------------------
      #
      # Noctalia has one shared action list, but the lock screen only needs
      # Suspend and Switch user. Its shared row is disabled above and replaced
      # with those two explicit lockscreen widgets, leaving this desktop list
      # free to carry the complete set of requested actions.
      #
      # **Switch user is a `command`.** The action vocabulary is lock,
      # logout, suspend, lock_and_suspend, reboot, shutdown and command —
      # there is no switch-user verb, because switching users is a greeter
      # operation rather than a session one. `switch-user` from ./scripts.nix
      # is the script that already knows how to do it (it asks logind for a
      # greeter on a spare VT and leaves this session running), which is the
      # same one the waybar session menu called.
      session.show_shortcuts = true;
      session.actions = [
        {
          action = "lock";
          label = "Lock";
          shortcut = "1";
        }
        {
          action = "lock_and_suspend";
          label = "Suspend";
          glyph = "moon";
          shortcut = "2";
        }
        {
          action = "command";
          label = "Switch user";
          glyph = "users";
          command = lib.getExe niriScripts.switchUser;
          shortcut = "3";
        }
        {
          action = "logout";
          label = "Log out";
          # A bare number, not a string: countdown_seconds binds to a plain
          # double in noctalia's schema (config_schema.cpp), read through
          # finiteDouble() — which accepts a TOML int or float node and
          # nothing else. A quoted "3" fails that read silently (no
          # diagnostic, no error), leaving the field at its default of 0,
          # which arms no countdown at all.
          countdown_seconds = 3;
          shortcut = "4";
        }
        {
          action = "reboot";
          label = "Reboot";
          countdown_seconds = 5;
          shortcut = "5";
        }
        {
          action = "shutdown";
          label = "Power off";
          variant = "destructive";
          countdown_seconds = 10;
          shortcut = "6";
        }
      ];
    };

    # --- bar ------------------------------------------------------------
    #
    # The waybar layout, slot for slot. Its geometry came from
    # `programs.waybar.settings.main` and its look from the generated
    # stylesheet; both are settings here because noctalia has no stylesheet.
    #
    #   height 34        -> thickness
    #   margin-top 6     -> margin_edge
    #   margin-left 10   -> margin_ends
    #   border-radius 12 -> radius
    #   alpha(@bg, 0.88) -> background_opacity
    #
    # `widget_spacing` and `padding` are the two that deliberately do *not*
    # match waybar. waybar's 4px gap was chosen to claw back room from a
    # twelve-slot right-hand cluster that had grown too wide; that cluster is
    # three slots shorter now, so the gap can go back to something that reads
    # as separate controls rather than one run-on strip.
    bar.main = {
      position = "top";
      thickness = 34;
      widget_spacing = 8;
      padding = 16;
      margin_edge = 6;
      margin_ends = 10;
      radius = 12;
      background_opacity = 0.88;
      shadow = true;
      reserve_space = true;

      start = [
        "launcher_button"
        "workspaces"
        "active_window"
      ];

      center = [ "clock" ];

      # Right-hand cluster, in waybar's order, minus two that were doing a
      # job something else already does:
      #
      #   lock       the session panel next door offers it, and Mod+L is the
      #              reflex anyway
      #   lock_keys  the caps-lock OSD says it louder, and this only ever had
      #              anything to show while a key was actually held on
      #
      # Clipboard sits immediately to the right of Notifications and opens
      # the attached clipboard-history panel near the button.
      end =
        visualiser
        ++ [
          "media"
          "tray"
          "notifications"
          "clipboard"
          "brightness"
          "volume"
          "bluetooth"
          "network"
          "privacy"
          "joshr/gamemode-indicator:status"

          # Caffeine takes the slot that previously showed the power profile.
          # Keep it and the battery as ordinary bar widgets: a capsule group
          # paints its own background, which made Caffeine look unlike the
          # buttons around it.
          "battery"
          "caffeine"

          "wallpaper"
          "control-center"
          "session"
        ];
    };

    widget = {
      # --- the left cluster -------------------------------------------------
      #
      # One icon, one row of pills, one line of text, in that order, and each
      # doing a different job. What it used to be was three text-bearing
      # objects of three different weights sitting next to each other — a
      # glyph with "joshr" beside it, pills scaled up 25% past everything else
      # on the bar, and a window title with a placeholder standing in for it
      # whenever nothing was focused. Elegance here is mostly subtraction:
      # every one of the changes below removes something that was on screen
      # permanently while saying nothing that changed.

      # The launcher, first thing on the bar, as the NixOS snowflake.
      #
      # This slot has been through three shapes. Under waybar it was
      # `custom/user`: static text with no `exec` and no action, printing the
      # username. It became a glyph that opens the launcher — which is the
      # entry point wofi never had a bar slot for at all — and the username
      # moved to the tooltip. Now it says what it *does* rather than who it
      # belongs to, which is the only one of the three that a stranger could
      # read correctly.
      #
      # The mark itself is U+F313, `nf-linux-nixos` from the Nerd Fonts logo
      # set, and it is in `label` rather than in `glyph` on purpose.
      #
      # `glyph` is not a character: noctalia resolves the name against the
      # Tabler icon set it ships (`GlyphRegistry::lookup`), which has no NixOS
      # mark, and the `U+XXXX` literal that field also accepts is a codepoint
      # *in that font* — the private-use area both Tabler and the Nerd Fonts
      # occupy, so asking for F313 there answers with whichever Tabler icon
      # happens to live at F313. A label is drawn in the shell's own
      # `font_family`, which is FiraCode Nerd Font, so this is the one field
      # on the widget where a Nerd Font codepoint means what it says.
      #
      # `glyph = ""` is load-bearing rather than tidy. The widget's default is
      # `heart` and it draws the glyph beside the label, so leaving it unset
      # puts a heart next to the snowflake.
      #
      # This replaces the `nixos-icons` SVG that was here through
      # `custom_image`. No colour is lost with it: an image drawn with
      # `custom_image_colorize` and a label are both painted from the widget's
      # own foreground chain, so the mark is the bar's text colour either way
      # and follows a colour-scheme change with everything else. What it drops
      # is a store path in the bar config, a PNG rasterised per repaint, and
      # the SVG's own two blues as a thing that could come back.
      launcher_button = {
        type = "custom_button";
        custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
        custom_image_colorize = true;
        tooltip = "Applications — ${config.home.username}";
        command = "noctalia msg panel-toggle launcher";
      };

      workspaces = {
        # 1.25 made the pills the tallest thing on a 34px bar and left them
        # visibly out of scale with the tray and the buttons either side.
        # 1.1 still reads at a glance without becoming the loudest element in
        # the session.
        scale = 1.1;

        # Numbers only where a number is worth having.
        #
        # niri creates and destroys workspaces as you use them, so the last
        # one in the row is always the empty one waiting to be moved into.
        # Numbering it is numbering a placeholder. With this, an occupied
        # workspace is a labelled pill and an empty one is a plain dot, which
        # says the same thing with less ink and makes "where are my windows"
        # answerable without reading.
        labels_only_when_occupied = true;
        display = "none";
      };

      clock = {
        format = "{:%I:%M %p   %a, %b %d}";
        tooltip_format = "{:%A, %B %d, %Y}";
      };

      active_window = {
        display = "icon_and_text";
        max_length = 300;

        # Shrink to the title rather than reserving a slot for one.
        #
        # The default is 80px of floor, which on a short title leaves a gap
        # between the workspaces and the centred clock that reads as something
        # failing to render. At 0 the cluster is exactly as wide as what is in
        # it.
        min_length = 0;

        # And draw nothing at all when nothing is focused, instead of a
        # placeholder label. Together with `min_length` the widget disappears
        # cleanly on an empty workspace.
        show_empty_label = false;

        # A truncated title is a title you cannot read. Scrolling it under the
        # pointer costs nothing while the mouse is elsewhere — which is the
        # whole time — and means `max_length` is a layout choice rather than
        # an information limit.
        title_scroll = "always";

        # The app icon at 16px against the 13px body text: enough that the
        # icon leads and the title follows, which is the reading order the
        # `icon_and_text` display implies.
        icon_size = 16;
      };

      # Now playing.
      #
      # `max_length` is a width in pixels, capped at 800 by the widget itself,
      # and the same unit `active_window` above uses — not a count of glyphs.
      # At 200 it was cutting "Artist · Title" down to about the artist. The
      # bar's right-hand cluster lost four slots in the move off waybar, so
      # there is room to let this run on, and `hide_when_no_media` means it
      # costs that width only while something is playing.
      #
      # `title_scroll` is the other half of the answer and the more useful
      # one: no fixed width fits every track, so anything past 270px scrolls
      # continuously rather than being lost to an ellipsis. There is
      # deliberately no custom wheel action here: scrolling must not change
      # the MPRIS player's volume.
      media = {
        max_length = 200;
        min_length = 0;
        title_scroll = "always";
        hide_when_no_media = true;
      };

      network = {
        show_label = false;
      };

      # Camera, microphone and screen-share indicators, and only while one of
      # them is actually open.
      #
      # This is the behaviour waybar's pair of modules had and lost in the
      # move: `custom/microphone-privacy` printed an empty line when nothing
      # held the mic, and waybar hides a custom module with no text, so the
      # slot cost nothing the rest of the time. noctalia draws all three
      # glyphs greyed out by default, which is three permanent icons saying
      # "not recording" — the state you are in essentially always.
      privacy = {
        hide_inactive = true;
      };
    };

    # --- plugins ----------------------------------------------------------
    #
    # **Installed is not enabled**, and that distinction is the whole reason
    # the GameMode slot was missing rather than merely empty. The registry
    # scans ~/.local/share/noctalia/plugins as an implicit local source and
    # parses every manifest it finds there, then drops the ones whose id is not
    # in this list — "discovered but not enabled", one log line, no widget. A
    # bar lane naming an entry of a plugin that never loaded is not an error
    # either: `noctalia config validate` checks the *shape* of a lane list and
    # has no registry to check the names against, so nothing upstream of the
    # running shell notices.
    #
    # Toggling the plugin off in the Settings window writes an app-owned
    # `[plugins].enabled` into ~/.local/state/noctalia/settings.toml, and that
    # override wins over this until it is removed — the same read-after-config
    # ordering the activation step below reconciles for widget placements.
    #
    # `auto_update` is off because nothing in this session comes from a git
    # source. The two built-in sources ship enabled, and the default `true`
    # fetches every one of them at startup and again every six hours, for
    # plugins nothing here loads.
    plugins = {
      enabled = [ "joshr/gamemode-indicator" ];
      auto_update = false;
    };

    # --- colour -----------------------------------------------------------
    #
    # `custom` rather than `builtin` or `wallpaper`: the palettes are the ones
    # in themes.nix, written out by ./noctalia-palettes.nix.
    #
    # `mode = "dark"` is not really a mode here. Each theme in themes.nix is a
    # finished palette that is already light or dark — gruvbox-light is the
    # light one — so both variants of each generated palette hold the same
    # colours and this only picks which of two identical halves gets read.
    #
    # The session's actual light/dark switch is `theme-mode`, which moves
    # between palettes rather than between these two slots: every theme names
    # a `counterpart` in the other mode and switching modes applies it. That
    # arrives here as an ordinary `color-scheme-set custom <name>`, which is
    # why this line can stay a constant. See ./noctalia-palettes.nix.
    theme = {
      mode = "dark";
      source = "custom";
      custom_palette = paletteSet.default;

      # --- and how it reaches everything that is not the shell -------------
      #
      # Noctalia is now the source of the live system palette, not merely the
      # shell consumer of a finite Nix theme. Its user templates write one
      # complete live directory plus the files consumed directly by Spotify
      # and Vencord. The final manifest template publishes that directory and
      # wakes SDDM and Limine. This works unchanged for custom, builtin,
      # wallpaper-derived and community palettes because the templates see
      # resolved colour roles rather than a palette name.
      #
      # The builtin kcolorscheme remains off. Its post-action writes
      # ~/.config/kdeglobals itself, while ./default.nix deliberately owns that
      # path as a symlink. The user template below instead writes the target
      # inside `noctalia-live`; repointing `active` switches KDE, Dolphin and
      # VS Code together without two writers fighting over kdeglobals.
      #
      # Every builtin template renders the palette into a *side* file the app
      # can include — `kitty/themes/noctalia.conf`, `btop/themes/noctalia.theme`
      # — and then runs a hook that makes the app read it. It is the hook, not
      # the render, that is awkward on NixOS: it edits the app's main config,
      # which home-manager owns here as a read-only symlink into the store.
      #
      # Every one of those hooks is idempotent, though — each checks for its
      # own line before writing anything. So the way to make them work is to
      # declare that line on the home-manager side and let the hook find its
      # job already done. That is what the `programs.*` settings and the
      # `xdg.configFile` entries in the config block below are for, and each
      # is commented with the hook it is satisfying. The store file stays
      # declarative, the hook stays a no-op, and neither has to know about the
      # other.
      #
      #   kitty      `include themes/noctalia.conf`, via programs.kitty.extraConfig
      #   btop       `color_theme = "noctalia"`, via programs.btop.settings
      #   cava       `[color] theme = "noctalia"`, via xdg.configFile
      #   niri       `include "noctalia.kdl"`, written into config.kdl by niri.nix
      #   gtk3/gtk4  nothing — gtk.css is not managed here, and their hook
      #              already replaces a read-only symlink with a real file
      #   qt         nothing — plain side files for qt5ct/qt6ct, no hook
      #   alacritty  nothing — alacritty is not installed and its config is
      #              not managed, so the hook creates the file it wants
      #   starship   the exception: see the starship block in the config
      #              below. Its hook has to inject the palette *into*
      #              starship.toml, so there is no line to pre-declare
      templates = {
        enable_builtin_templates = true;
        builtin_ids = [
          "alacritty"
          "btop"
          "cava"
          "gtk3"
          "gtk4"
          "kitty"
          "niri"
          "qt"
          # "starship"
        ];

        # --- community templates ------------------------------------------
        #
        # noctalia-dev/community-templates, fetched from api.noctalia.dev on
        # first use and cached under ~/.cache/noctalia. That is a runtime
        # fetch, which is against the grain of a config that pins every input
        # in flake.lock — the tradeoff is taken deliberately, because these
        # are the apps whose theming would otherwise have to be reimplemented
        # here one renderer at a time, and upstream maintains them against
        # each app's actual config format.
        #
        # What it means in practice: the templates apply from the second run
        # onwards on a machine with no network, and a template whose upstream
        # entry changes shape changes what lands in `~/.config` without a
        # rebuild. Nothing in the *session* depends on them — the shell, the
        # terminal, GTK, Qt and the greeter are all builtin or user templates
        # above — so a failed fetch costs these apps their colours and
        # nothing else.
        #
        # `community_ids` takes catalog ids (the directory names in that
        # repository), not the individual `[templates.*]` entry names:
        # `vscode` covers Code, Codium and Antigravity.
        #
        #   blender        renders a theme script and runs it headless;
        #                  gated on ~/.config/blender existing
        #   discord        Vencord/Vesktop/BetterDiscord variants. Extra
        #                  selectable themes beside the `vencord` user
        #                  template below, which stays the enabled one
        #   fastfetch      merges colours into ~/.config/fastfetch/config.jsonc,
        #                  which has to exist and be strict JSON — see the
        #                  seed in the activation block
        #   inkscape       ui/user.css; gated on ~/.config/inkscape existing
        #   obs            the Matugen .obt theme, which ../obs.nix selects
        #   papirus-icons  recolours the folder icons in place, which needs a
        #                  writable copy of the icon theme — see the seed below
        #   prismlauncher  a "Matugen" theme under its data directory
        #   vscode         a NoctaliaTheme extension; ../vscode.nix ships the
        #                  manifest the rendered theme file belongs to
        #   zellij         a theme file; needs `theme "noctalia"` in zellij's
        #                  own config, which is not managed here
        #   zen-browser    userChrome/userContent, applied into every Zen
        #                  profile it finds. A no-op with Zen not installed
        enable_community_templates = true;
        community_ids = [
          "blender"
          "discord"
          "fastfetch"
          "inkscape"
          "obs"
          "papirus-icons"
          "prismlauncher"
          "vscode"
          "zellij"
          "zen-browser"
          "libreoffice"
        ];

        # These are local user templates, so Noctalia itself resolves every
        # palette source and writes all downstream formats. Indices make the
        # state manifest last: its post-hook can only publish a complete set.
        user = {
          kde = {
            input_path = "${config.xdg.configHome}/noctalia/templates/kdeglobals";
            output_path = "${liveThemeDir}/kdeglobals";
            index = 100;
          };
          vscode_package = {
            input_path = "${config.xdg.configHome}/noctalia/templates/vscode-package.json";
            output_path = "${liveThemeDir}/vscode-extension/package.json";
            index = 110;
          };
          vscode = {
            input_path = "${config.xdg.configHome}/noctalia/templates/vscode.json";
            output_path = "${liveThemeDir}/vscode-extension/themes/niri-color-theme.json";
            index = 120;
          };
          # wofi is not the launcher any more, but `theme-menu`,
          # `wallpaper-menu` and `session-menu` in ./scripts.nix all still
          # drive it as a plain `--dmenu`, and ./emoji.nix passes it a second
          # stylesheet with bigger rows. Both are named under `active` by
          # those modules, which under this shell is the live directory — so
          # without these two the menus would come up in wofi's own default
          # look while everything around them followed the palette.
          wofi = {
            input_path = "${config.xdg.configHome}/noctalia/templates/wofi.css";
            output_path = "${liveThemeDir}/wofi.css";
            index = 125;
          };
          wofi_emoji = {
            input_path = "${config.xdg.configHome}/noctalia/templates/wofi-emoji.css";
            output_path = "${liveThemeDir}/wofi-emoji.css";
            index = 126;
          };
          spotify = {
            input_path = "${config.xdg.configHome}/noctalia/templates/spotify.css";
            output_path = "${spotifyThemeDir}/colors.css";
            index = 130;
          };
          vencord = {
            input_path = "${config.xdg.configHome}/noctalia/templates/vencord.css";
            output_path = [
              "${config.xdg.configHome}/Vencord/themes/noctalia.theme.css"
              "${config.xdg.configHome}/vesktop/themes/noctalia.theme.css"
            ];
            index = 140;
          };
          # The one correction to the builtin `niri` template, as a second
          # include rather than a second writer of its file.
          #
          # That template paints an unfocused window's border in `surface` —
          # the theme's background — which on these palettes is a border
          # against the desktop that nothing can pick out. Overwriting
          # noctalia.kdl to fix one line would mean owning the whole file,
          # including the four colours and three sections the builtin gets
          # right; writing a second file and including it after instead leaves
          # every one of those where it is, because niri merges duplicate
          # sections property by property with the later definition winning.
          #
          # Rendered by noctalia rather than written from themes.nix for the
          # reason the whole template mechanism exists here: under this shell
          # the palette is live — wallpaper-derived and community schemes
          # included — and a colour written into config.kdl would be the
          # generation's idea of the theme rather than the session's.
          niri_borders = {
            input_path = "${config.xdg.configHome}/noctalia/templates/niri-borders.kdl";
            output_path = "${config.xdg.configHome}/niri/noctalia-borders.kdl";
            index = 150;
          };
          system_palette = {
            input_path = "${config.xdg.configHome}/noctalia/templates/system-palette.conf";
            output_path = resolvedThemeFile;
            post_hook = "${lib.getExe themeResync} && ${lib.getExe niriOverviewSync}";
            index = 900;
          };
        };
      };
    };

    # --- wallpaper --------------------------------------------------------
    #
    # Replaces awww and the `wallpaper-set` / `wallpaper-random` /
    # `wallpaper-restore` trio in ./scripts.nix. noctalia remembers the
    # selection itself, so the `spawn-at-startup` that restored it at login has
    # nothing left to do.
    wallpaper = {
      enabled = true;

      # ~/.local/share/wallpapers — the tree home/joshr/home.nix links the
      # dotfiles' images into and home/joshr/wallhaven.nix drops the locked
      # top 20 into, under WallhavenFlake/.
      directory = wallpaperDir;

      fill_mode = "crop";
      transition = [ "disc" ];
      transition_duration = 1500;
      transition_on_startup = true;

      # Recursive, and this is what makes the wallhaven set pickable rather
      # than only shufflable: the same flag drives the picker's scan and the
      # automation's random draw, so without it the panel would list the
      # handful of images sitting directly in the directory and none of the
      # twenty in WallhavenFlake/.
      automation.recursive = true;

      default.path = "${wallpaperDir}/nixos.png";
    };

    # --- notifications ----------------------------------------------------
    #
    # dunst's placement, kept: top-right with a 16px margin. The urgency
    # timeouts dunst carried (5s low, 8s normal, never for critical) are
    # noctalia's own behaviour and have no setting.
    notification = {
      enable_daemon = true;
      show_app_name = true;
      show_actions = true;
      offset_x = 16;
      offset_y = 16;
    };

    # --- OSD --------------------------------------------------------------
    #
    # swayosd, whose whole reason for existing was that niri has no OSD and a
    # volume or brightness key was otherwise silent. Placed where swayosd put
    # it: low and centred, clear of the bar at the top.
    osd = {
      position = "bottom_center";
      background_opacity = 0.97;
      offset_x = 20;
      offset_y = 8;

      kinds = {
        volume = true;
        brightness = true;

        # Which is what lets `lock_keys` come off the bar: the caps-lock state
        # is worth a pop-up at the moment it changes and worth nothing as a
        # permanent slot.
        lock_keys = true;
        privacy = true;
      };
    };

    # --- brightness -------------------------------------------------------
    #
    # ddcutil is **on**, and the earlier reasoning for leaving it off was
    # wrong in a way worth writing down.
    #
    # modules/nixos/ddcci.nix loads ddcci-backlight, which speaks DDC/CI in
    # the kernel and registers each external monitor as an ordinary
    # /sys/class/backlight/ddcci* device. The argument was that noctalia would
    # then reach the desk's monitors through sysfs exactly as it reaches a
    # laptop panel, with no second DDC/CI implementation involved. It does not:
    # `enumerateBacklights` only keeps a backlight it can tie to a live
    # Wayland output, and it does that by canonicalising <device> and checking
    # it sits under /sys/class/drm/card*-<CONNECTOR>. A ddcci backlight hangs
    # off its i2c adapter instead, so it matches nothing — and the one
    # fallback in that code path is hardcoded to connectors starting `eDP`.
    #
    # So the laptop's internal panel works through sysfs and every external
    # monitor is silently dropped, which is a brightness widget that does
    # nothing on the desk. `enable_ddcutil` is the supported route for those:
    # noctalia shells out to `ddcutil detect` and drives them from userspace.
    #
    # Two things it needs, both already true here. `hardware.i2c` — enabled by
    # ddcci.nix — loads i2c-dev and puts a uaccess tag on /dev/i2c-*, so this
    # runs as the user rather than needing root. And `ddcutil` has to be on
    # PATH: nixpkgs' noctalia wrapper only prefixes gitMinimal, and the code
    # gates the whole backend on `commandExists("ddcutil")`, so it is added to
    # home.packages below.
    #
    # Noctalia is the only writer under this shell. The old 240-second idle
    # action called the legacy `brightness` helper through ddcci-backlight,
    # racing this ddcutil backend to the same monitor register. It is gone;
    # Noctalia's own pre-action overlay supplies the idle darkening below.
    brightness.enable_ddcutil = true;

    # --- weather ----------------------------------------------------------
    #
    # `auto_locate` resolves coordinates from the machine's public IP rather
    # than from a place name, which is the "automatically" part: nothing to
    # write down, and it follows a laptop that moves.
    #
    # It is worth being explicit that this is the one thing in this config
    # that talks to the network on its own. Weather comes from Open-Meteo and
    # the coordinates come from an IP lookup, so leaving this on means the
    # shell makes an outbound request on a schedule. `[location]` is also what
    # `theme.mode = "auto"` and the night light would use for sunrise/sunset,
    # neither of which is on here.
    weather = {
      enabled = true;
      unit = "imperial";
      refresh_minutes = 30;
    };

    location.auto_locate = true;

    # --- idle -------------------------------------------------------------
    #
    # Noctalia owns this pipeline outright: its fullscreen pre-action overlay
    # darkens the outputs before the native lock and screen-off actions. There
    # is deliberately no separate brightness command and therefore no second
    # DDC/CI writer to save and restore a physical level.
    idle = {
      pre_action_fade_seconds = 2;
      behavior = {
        lock = {
          enabled = true;
          timeout = 300;
          action = "lock";
        };

        screen-off = {
          enabled = true;
          timeout = 600;
          action = "screen_off";
        };
      };
    };

    # Desktop disable widgets
    desktop_widgets = {
      enabled = false;
    };

    # --- lock screen ------------------------------------------------------
    #
    # `blurred_desktop = false` is the performance-conscious half of this. The
    # alternative takes a wlr-screencopy snapshot of every output at the moment
    # of locking and blurs that; using the wallpaper skips the capture entirely
    # and blurs an image that is already resident on the GPU. It also survives
    # locking from a blanked screen, where there is nothing to snapshot.
    lockscreen = {
      enabled = true;
      blurred_desktop = false;
      blur_intensity = 0.5;
      tint_intensity = 0.3;
    };

    lockscreen_widgets = {
      enabled = lockWidgets != { };
      widget = lockWidgets;
      widget_order = lockWidgetOrder;
    };

    # --- hooks ------------------------------------------------------------
    hooks = {
      started = [
        (lib.getExe themeResync)
        (lib.getExe niriOverviewSync)
      ];
      wallpaper_changed = lib.getExe sddmWallpaperSync;
      colors_changed = [
        (lib.getExe themeResync)
        (lib.getExe niriOverviewSync)
      ];
    };

    # Sampling for the control centre's system tab. Nothing here is on the
    # bar, so the cost is only paid while the panel is open — except that it
    # isn't: `enabled` starts a sampling thread that reads /proc every two
    # seconds and dlopen's libnvidia-ml to ask the card for its temperature and
    # VRAM every five, whether or not anything is displaying the answer. That
    # is a second NVML client on the card while a game is on it, which is why
    # ./gamemode.nix turns this off for the duration rather than leaving it to
    # the panel being closed.
    system.monitor.enabled = true;
  };

  # The lock screen's audio visualizers — one per output that has one — picked
  # out of the widget set declared above rather than by rebuilding their
  # `audio_visualizer_<connector>` ids, so this is not a second place that
  # knows how those are made. Empty on every host with
  # `local.niri.cavaInLockscreen` off, which is what leaves the overlay below
  # without a `lockscreen_widgets` section at all.
  lockVisualisers = lib.filterAttrs (_: w: (w.type or "") == visualiserWidget) lockWidgets;

  # --- and what this shell looks like in GameMode -------------------------
  #
  # The noctalia half of ./gamemode.nix, and it lives here rather than there
  # for one reason: two of the things GameMode switches off are entries in
  # lists declared above, and a second copy of those lists kept in another file
  # would drift from them the first time the bar is reordered. Everything below
  # is *derived* from `settings` and `lockWidgets` instead of restating them,
  # so there is nothing to keep in step.
  #
  # `niri-gamemode` copies this into ~/.config/noctalia/gamemode.toml on the
  # way in and deletes it on the way out. noctalia parses every `*.toml` in its
  # config directory and deep-merges them in sorted filename order, so
  # `gamemode` lands after `config` and wins; tables merge key by key, which is
  # why this only has to name what changes. See ./gamemode.nix for the rest of
  # the arrangement — the niri half, the state, and how gamemoderun gets here.
  #
  # Grouped by what each one costs:
  #
  #   shell.animation      every widget, panel, OSD and toast noctalia draws
  #                        runs through one motion service; `enabled = false`
  #                        makes it deliver the end state immediately instead
  #                        of interpolating to it.
  #   *.background_opacity a translucent surface is one the compositor has to
  #                        blend against what is behind it rather than
  #                        overwrite. Fully opaque is the cheap case, and on
  #                        the bar it is also what makes the missing blur look
  #                        deliberate rather than broken.
  #   panel.transparency_mode
  #                        the same thing one level in: "solid" stops in-panel
  #                        cards being drawn translucent over the panel.
  #   *.shadow             a shadow is a second copy of the surface's shape
  #                        rendered with a large SDF softness — the bar's is
  #                        redrawn with the bar.
  #   the two visualizers  the only things here that are drawn from a live
  #                        audio stream, which means a PipeWire spectrum read
  #                        and a repaint every frame for as long as something
  #                        is playing. See the note on each below.
  #   system.monitor       the one that is not about drawing at all. Its
  #                        sampling thread reads /proc every two seconds and
  #                        dlopen's libnvidia-ml to ask the card for its
  #                        temperature and VRAM every five, which is a second
  #                        NVML client on the card the game is using.
  #                        `enabled = false` joins that thread and releases the
  #                        GPU readers rather than merely hiding the numbers.
  gamemodeSettings = {
    shell = {
      animation.enabled = false;
      panel = {
        transparency_mode = "solid";
        shadow = false;
      };
    };

    # The opacities are written `1` rather than `1.0` because that is what
    # actually lands: `pkgs.formats.toml` goes through `builtins.toJSON`, which
    # renders a whole-numbered Nix float as an integer, and json2toml has
    # nothing left to tell it otherwise. noctalia reads every float field
    # through `finiteDouble`, which takes a TOML int or float alike, so an
    # integer is the honest spelling of what the file will contain.
    notification.background_opacity = 1;
    osd.background_opacity = 1;

    system.monitor.enabled = true; # If system monitor causes problems, set it to false.

    bar.main = {
      background_opacity = 1;
      shadow = false;
    }
    # The bar's visualizer, dropped from the lane rather than switched off in
    # place: a bar widget is an entry in an array with no `enabled` of its own
    # (WidgetConfig carries a type and a settings map, nothing else), and a
    # deep merge replaces an array wholesale. So the lane has to be restated —
    # but restated *from the lane above*, which is what keeps the two from
    # parting company. Only emitted where there is a visualizer to drop, so the
    # desk hosts' overlay does not carry a copy of a list it does not change.
    // lib.optionalAttrs config.local.waybar.cavaInBar {
      end = lib.filter (w: w != visualiserWidget) settings.bar.main.end;
    };
  }
  # And the lock screen's, which is the opposite case and gets the easier
  # treatment. A lock-screen widget is a placed object rather than a lane
  # entry, and it has an `enabled` of its own (DesktopWidgetState) that the
  # host checks before it builds anything — so this can switch the visualizer
  # off by name and leave `widget_order` completely alone. That matters:
  # `widget_order` is the definitive membership list, and an overlay that
  # restated it would be one stale entry away from dropping the login box.
  #
  # Found by type rather than by rebuilding `audio_visualizer_<connector>`,
  # which is the same reasoning as the lane above: the ids are generated per
  # output and this should not be a second place that knows how.
  #
  # `type` is repeated in the override because the overlay is validated on its
  # own, and a widget table with no type reads as type "" — an unrecognised
  # lock-screen widget, and a warning on every build.
  //
    lib.optionalAttrs (lockVisualisers != { }) {
      lockscreen_widgets.widget = lib.mapAttrs (_: w: {
        inherit (w) type;
        enabled = false;
      }) lockVisualisers;
    };

  configFile = tomlFormat.generate "noctalia-config.toml" settings;

  # Checked at build time rather than discovered at login.
  #
  # `noctalia config validate` is the shell's own schema check, and running it
  # here is what turns a key that has been renamed upstream into a build
  # failure naming the line, instead of a setting that silently stops applying.
  # It is cheap — the binary comes from the binary cache, and this only reads a
  # file.
  validatedConfig = pkgs.runCommand "noctalia-config.toml" { } ''
    ${noctalia} config validate ${configFile}
    cp ${configFile} $out
  '';

  # The overlay gets the same treatment, and it is worth as much: a key renamed
  # upstream would otherwise turn into a GameMode that quietly stops turning
  # something off. `validate` takes a single file and checks it against the
  # schema, so a partial one is fine — that is exactly what this is.
  gamemodeFile = tomlFormat.generate "noctalia-gamemode.toml" gamemodeSettings;

  validatedGamemodeFile = pkgs.runCommand "noctalia-gamemode.toml" { } ''
    ${noctalia} config validate ${gamemodeFile}
    cp ${gamemodeFile} $out
  '';

  # Move aside a state file written by a *newer* noctalia than the one now
  # installed.
  #
  # config.toml is generated above and Nix owns it. ~/.local/state/noctalia/
  # settings.toml is the other half: noctalia's own overrides file, holding
  # whatever has been changed from the Settings window, and it is written by
  # the shell rather than by this config. It carries a `config_version`, and
  # noctalia refuses to start on one it does not understand —
  #
  #     config version 12 is newer than supported version 8
  #
  # — which is a *downgrade* symptom, not an upgrade one. Going forwards is
  # handled: there is a migration per version and they run on load. Going
  # backwards has nothing to run, so the shell stops.
  #
  # It is reachable from here because the package moved. An earlier revision
  # of this config took noctalia from its own flake, where `main` is 5.0.0 and
  # writes config_version 12; nixpkgs is on the 5.0.0-beta.7 tag, which knows
  # up to 8. Anyone who ran the flake build once has a state file the packaged
  # build cannot read, on every host they ran it on.
  #
  # **No version number is written down here, on purpose.** The check asks the
  # installed binary instead, with two probes: an empty config, which must
  # pass, and the same thing carrying the version the state file claims. Only
  # when the first passes and the second fails is the version the reason —
  # which keeps this from throwing the file away over some unrelated
  # validation failure, and keeps it correct when nixpkgs moves to a build
  # that does understand 12.
  #
  # Renamed rather than deleted. The overrides are small and mostly duplicate
  # what `settings` above already declares, but they are the user's, and a
  # config that silently deletes state is worse than one that leaves a file
  # to look at.
  reconcileOverrides = ''
    stateFile="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"

    if [ -f "$stateFile" ]; then
      claimed="$(${pkgs.gnused}/bin/sed -n \
        's/^[[:space:]]*config_version[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
        "$stateFile" | ${pkgs.coreutils}/bin/head -n1)"

      if [ -n "$claimed" ]; then
        probeDir="$(${pkgs.coreutils}/bin/mktemp -d)"
        : > "$probeDir/empty.toml"
        printf 'config_version = %s\n' "$claimed" > "$probeDir/claimed.toml"

        if ${noctalia} config validate "$probeDir/empty.toml" >/dev/null 2>&1 \
          && ! ${noctalia} config validate "$probeDir/claimed.toml" >/dev/null 2>&1; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv -f "$stateFile" "$stateFile.too-new"
          echo "noctalia: ~/.local/state/noctalia/settings.toml claims config_version $claimed," >&2
          echo "noctalia: which this build does not support. Moved to settings.toml.too-new." >&2
        fi

        ${pkgs.coreutils}/bin/rm -rf "$probeDir"
      fi
    fi

    # --- and drop the widget placements it persists ------------------------
    #
    # The overrides file is read *after* config.toml and wins, which is right
    # for something the user changed in the Settings window and wrong for the
    # two sections below, because noctalia writes those itself without being
    # asked. `setLockscreenWidgetsState` / `setDesktopWidgetsState` serialise
    # the whole placement — every widget *and* a `widget_order` — and the
    # shell seeds a login box into it on its own.
    #
    # `widget_order` is what makes this a silent override rather than a merge:
    # the reader treats an order list as the definitive membership list, so a
    # stale one naming `clock_DP-3` drops the login box, lock buttons,
    # `clock_time_DP-3`, and `clock_date_DP-3` declared here entirely. The
    # complete lockscreen composition would then look like it did nothing.
    #
    # Only these two sections. Everything else in that file is a real
    # preference, and the wallpaper in particular is genuine runtime state:
    # noctalia records the current image per monitor under `wallpaper.…` and
    # dropping it would reset the desktop to `wallpaper.default.path` on every
    # `home-manager switch`.
    if [ -f "$stateFile" ]; then
      trimmed="$(${pkgs.coreutils}/bin/mktemp)"

      # Delete each `[section]` and `[section.sub]` block by tracking which
      # table the current line belongs to: a header switches tables, and
      # everything until the next header belongs to the one just seen.
      ${pkgs.gawk}/bin/awk '
        /^[[:space:]]*\[\[?[a-zA-Z0-9_.-]+\]?\]/ {
          drop = ($0 ~ /^[[:space:]]*\[\[?(lockscreen_widgets|desktop_widgets)([].[])/)
        }
        !drop
      ' "$stateFile" > "$trimmed"

      if ! ${pkgs.diffutils}/bin/cmp -s "$stateFile" "$trimmed"; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -f "$trimmed" "$stateFile"
        echo "noctalia: dropped persisted widget placements from settings.toml;" >&2
        echo "noctalia: the ones declared in config.toml apply again." >&2
      fi

      ${pkgs.coreutils}/bin/rm -f "$trimmed"
    fi
  '';
in
{
  config = lib.mkIf useNoctalia {
    home.packages = [
      noctaliaPackage

      # `ddcutil` has to be findable by name: noctalia gates its whole DDC/CI
      # backend on `commandExists("ddcutil")` and nixpkgs' wrapper only
      # prefixes gitMinimal onto its PATH. See the brightness block above.
      pkgs.ddcutil
      pkgs.procps

      # The community fastfetch hook is jq from end to end — it parses the
      # config, merges the rendered colours in and writes it back — and jq is
      # not one of the tools NixOS puts in the system profile by default.
      # Everything else those hooks reach for (bash, sed, awk, coreutils,
      # findutils) already is.
      pkgs.jq

      # Poppins, for the lock screen clock. A font referenced by family name
      # in a config file has to actually be installed for fontconfig to
      # resolve it — otherwise the clock silently falls back to the default
      # sans and the setting looks like it did nothing.
      pkgs.poppins
    ];

    # --- satisfying the template hooks -------------------------------------
    #
    # Each of these declares the exact line the matching builtin template's
    # `apply.sh` looks for, so the hook finds its work already done and leaves
    # the store-managed file alone. See the `templates` note in `settings`.

    # kitty/apply.sh rewrites kitty.conf to contain `include
    # themes/noctalia.conf` exactly once, then writes it back only `if ! cmp -s`
    # — so with the line already present its rewrite is a no-op and it never
    # touches the read-only symlink.
    #
    # mkAfter for the same reason ./default.nix uses it: `extraConfig` is a
    # `lines` option and kitty takes the last value for any key.
    programs.kitty.extraConfig = lib.mkAfter ''

      include themes/noctalia.conf
    '';

    # btop/apply.sh greps for `^color_theme\s*=\s*"noctalia"` and does nothing
    # when it matches. Set here rather than in home/common/btop.nix because
    # that module is shared with root and the server, where noctalia never
    # runs and the theme file would never be written.
    #
    # mkForce because btop.nix names `tokyo-night` outright; two plain
    # definitions of one option is a conflict rather than an override, and
    # that host's btop should follow the session's palette rather than a
    # theme picked once.
    programs.btop.settings.color_theme = lib.mkForce "noctalia";

    # starship is the exception, and the only place a declarative file has to
    # become a mutable one.
    #
    # Every other template renders a *side* file and the app is pointed at it
    # with one line — which is why declaring that line up front makes the hook
    # a no-op. starship has no include mechanism at all, so its hook has to
    # splice the palette bodily into starship.toml between two markers, and
    # the spliced content changes with every theme. There is no line to
    # pre-declare, and a store symlink cannot be written.
    #
    # So on a noctalia host home-manager stops owning the file and seeds a
    # real one instead. `home/common/files/starship.toml` stays the source of
    # truth — the activation below re-seeds whenever it changes — and the hook
    # owns only what is between its markers.
    home.activation.noctaliaStarshipSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      starshipTarget="${config.xdg.configHome}/starship.toml"
      starshipSeed=${../../common/files/starship.toml}

      if [ ! -e "$starshipTarget" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm644 "$starshipSeed" "$starshipTarget"
      else
        # Compare what the seed owns, not what the hook owns: strip the
        # palette block before diffing so a theme change never looks like the
        # file drifting from the source.
        stripped="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.gnused}/bin/sed \
          '/^# >>> NOCTALIA STARSHIP PALETTE >>>$/,/^# <<< NOCTALIA STARSHIP PALETTE <<<$/d' \
          "$starshipTarget" > "$stripped"

        if ! ${pkgs.diffutils}/bin/diff -q \
          <(${pkgs.gnused}/bin/sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$stripped") \
          <(${pkgs.gnused}/bin/sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$starshipSeed") >/dev/null; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm644 "$starshipSeed" "$starshipTarget"
          echo "noctalia: re-seeded starship.toml from home/common/files/starship.toml;" >&2
          echo "noctalia: its palette block returns on the next colour-scheme change." >&2
        fi

        ${pkgs.coreutils}/bin/rm -f "$stripped"
      fi
    '';

    # --- satisfying the community template hooks ---------------------------
    #
    # The two that need something to exist before they can do anything. Both
    # are seed-if-missing rather than store symlinks, for the starship reason
    # above: the hook edits the file in place, and a symlink into the store
    # cannot be written.

    # fastfetch/apply.sh refuses to run without ~/.config/fastfetch/config.jsonc
    # ("run fastfetch once to generate a default config first"), then parses it
    # with `jq empty` and refuses again if it is JSONC rather than strict JSON.
    # It merges the rendered `logo` and `display` objects into whatever else is
    # there, so the seed only has to be a valid config — the colours arrive on
    # the first theme change.
    #
    # Deliberately not the same file as the fish greeting's. That one is
    # ~/.smallfetch.jsonc (home/common/shell.nix), it is shared with root and
    # the servers where noctalia never runs, and it carries comments — all
    # three of which rule it out as the thing this hook rewrites.
    home.activation.noctaliaFastfetchSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      fastfetchTarget="${config.xdg.configHome}/fastfetch/config.jsonc"

      if [ ! -e "$fastfetchTarget" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm644 \
          ${./fastfetch-config.json} "$fastfetchTarget"
      fi
    '';

    # papirus-icons/apply.sh picks the palette entry closest to the accent and
    # hands it to the bundled `papirus-folders`, which recolours the folder
    # icons *in place*. It looks for a writable copy at
    # ~/.local/share/icons/Papirus and, not finding one, copies /usr/share/icons
    # /Papirus — a path that does not exist on NixOS, so the hook fails on every
    # colour change with "Papirus Icons are not installed".
    #
    # This is the copy it is looking for. Three theme directories rather than
    # one because papirus-folders recolours whichever of them it finds, and the
    # session names Papirus-Dark (../niri/default.nix, and `[Icons] Theme` in
    # the kdeglobals template); a recoloured Papirus with an untouched
    # Papirus-Dark beside it would be work nothing ever displays.
    #
    # -R rather than -a: the -Dark and -Light trees are almost entirely
    # relative symlinks into Papirus, and dereferencing them would turn a
    # hundred megabytes into several times that. --no-preserve=mode because
    # the store is read-only and the whole point is a tree that can be written.
    #
    # Only when missing. This runs on every activation and re-copying an icon
    # theme each time would be minutes of I/O for nothing — and it would also
    # throw away the recolouring the hook has already done.
    home.activation.noctaliaPapirusSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      iconRoot="${config.xdg.dataHome}/icons"

      for variant in Papirus Papirus-Dark Papirus-Light; do
        if [ ! -d "$iconRoot/$variant" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$iconRoot"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -R --no-preserve=mode \
            "${pkgs.papirus-icon-theme}/share/icons/$variant" "$iconRoot/$variant"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod -R u+w "$iconRoot/$variant"
        fi
      done
    '';

    # Before the unit is (re)started, so a stale overrides file is dealt with
    # rather than crashing the shell on the way in. See reconcileOverrides.
    home.activation.noctaliaReconcileOverrides = lib.hm.dag.entryAfter [ "writeBoundary" ] reconcileOverrides;

    # The extension manifest the community VS Code template's output belongs
    # to. That template renders only the colour theme —
    # `~/.vscode/extensions/noctalia.noctaliatheme-0.0.5/themes/NoctaliaTheme-color-theme.json`
    # — because upstream assumes the matching marketplace extension is
    # installed. Without a package.json beside it that directory is not an
    # extension at all, and VS Code logs a parse failure for it on every start.
    #
    # Fifteen lines of manifest is cheaper than the marketplace round trip, and
    # it is also what makes the id in `community_ids` mean something: with this
    # here, "NoctaliaTheme" is a theme that can be picked from the palette.
    # ./vscode.nix keeps "Niri" — the local template, which follows
    # `theme.mode` into a light uiTheme where this one is fixed dark — as the
    # one actually selected.
    home.file.".vscode/extensions/noctalia.noctaliatheme-0.0.5/package.json".text = builtins.toJSON {
      name = "noctaliatheme";
      displayName = "Noctalia Theme";
      description = "The live Noctalia palette, rendered by the community VS Code template.";
      version = "0.0.5";
      publisher = "noctalia";
      engines.vscode = "^1.70.0";
      categories = [ "Themes" ];
      contributes.themes = [
        {
          label = "NoctaliaTheme";
          uiTheme = "vs-dark";
          path = "./themes/NoctaliaTheme-color-theme.json";
        }
      ];
    };

    # One assignment, because these cannot be split.
    #
    # `xdg.configFile."a".text = …` and `xdg.configFile = { … }` are two
    # definitions of the same attribute as far as the Nix language is
    # concerned — not the module system, which would merge them — so writing
    # the static entries in path form and the generated ones as a set is
    # "attribute 'xdg.configFile' already defined". The palettes have to be
    # built with `mapAttrs'`, so everything joins them in the set.
    xdg.configFile = {
      # cava/apply.sh wants a `[color]` section already naming the theme, and
      # exits 1 with an error if the config file is missing entirely. cava is
      # installed for the bar visualiser (see ./default.nix) but its config was
      # never managed, so this is both the file it needs and the line it checks.
      "cava/config".text = ''
        # Managed by home/joshr/niri/noctalia.nix.
        #
        # The palette is not here: noctalia renders it to
        # ~/.config/cava/themes/noctalia and this points cava at it. The theme
        # file is rewritten on every colour-scheme change.
        [color]
        theme = "noctalia"
      '';

      # Hand starship.toml over to the activation step below, which seeds a
      # real file the template hook can splice into.
      "starship.toml".enable = lib.mkForce false;

      "noctalia/config.toml".source = validatedConfig;
      "noctalia/templates/kdeglobals".source = ./noctalia-templates/kdeglobals;
      "noctalia/templates/niri-borders.kdl".source = ./noctalia-templates/niri-borders.kdl;
      "noctalia/templates/spotify.css".source = ./noctalia-templates/spotify.css;
      "noctalia/templates/system-palette.conf".source = ./noctalia-templates/system-palette.conf;
      "noctalia/templates/vencord.css".source = ./noctalia-templates/vencord.css;
      "noctalia/templates/vscode-package.json".source = ./noctalia-templates/vscode-package.json;
      "noctalia/templates/vscode.json".source = ./noctalia-templates/vscode.json;
      "noctalia/templates/wofi.css".source = ./noctalia-templates/wofi.css;
      "noctalia/templates/wofi-emoji.css".source = ./noctalia-templates/wofi-emoji.css;
    }
    // lib.mapAttrs' (
      name: palette:
      lib.nameValuePair "noctalia/palettes/${name}.json" {
        source = jsonFormat.generate "noctalia-palette-${name}.json" palette;
      }
    ) paletteSet.palettes;

    # Local v5 plugin: the slot collapses completely unless GameMode has an
    # active client. It sits immediately after Privacy in the bar list above,
    # and is enabled by `plugins.enabled` there — this only puts it where the
    # registry's implicit local source will find it.
    xdg.dataFile."noctalia/plugins/gamemode-indicator" = {
      source = gamemodeIndicator;
      recursive = true;
    };

    # The GameMode overlay, parked where `niri-gamemode` can copy it from.
    #
    # It is deliberately *not* in ~/.config/noctalia: everything named `*.toml`
    # in that directory is loaded and merged, so a file kept there would be a
    # GameMode that is always on. This is the prepared copy; the script places
    # it under the name noctalia reads when the mode is entered and removes it
    # again when the mode ends.
    #
    # Handing it over by path rather than by store path is what lets the two
    # halves of this feature live in the files they belong to. ./gamemode.nix
    # owns the mode and the niri overlay, which need nothing from here; the
    # overlay above needs the bar lane and the lock widgets, which are declared
    # here — and a module argument in that direction would be a cycle, since
    # this file already consumes the one that file publishes. `dataHome` is the
    # same string on both sides, and it is a path rather than a data structure,
    # which is the sort of agreement this repository already makes for the
    # theme state directories.
    xdg.dataFile."niri-gamemode/noctalia.toml".source = validatedGamemodeFile;

    # As a user service rather than a niri `spawn-at-startup`, matching how
    # waybar was run and for a better reason than waybar had: naming the
    # generated config in `X-Restart-Triggers` means a `home-manager switch`
    # that changes any of it restarts the shell on its own. Under
    # `spawn-at-startup` a config change would sit there until the next login.
    systemd.user.services.noctalia = {
      Unit = {
        Description = "noctalia — Wayland desktop shell";
        Documentation = "https://docs.noctalia.dev/v5/";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        X-Restart-Triggers = [ "${validatedConfig}" ];
      };

      Service = {
        ExecStart = noctalia;
        Restart = "on-failure";
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    # --- what noctalia takes over -----------------------------------------
    #
    # Each of these is a daemon whose job is now a section of the config above.
    # `mkForce` rather than plain `false` because the modules that enable them
    # set it directly, and this has to win over that without those files
    # needing to know this one exists.
    #
    # Two of them would actively fight noctalia rather than merely duplicate
    # it: dunst and noctalia both claim org.freedesktop.Notifications on the
    # session bus, and cliphist and noctalia both watch the Wayland selection,
    # so every copy would be recorded twice.
    services.dunst.enable = lib.mkForce false;
    services.swayosd.enable = lib.mkForce false;
    services.cliphist.enable = lib.mkForce false;
    services.swayidle.enable = lib.mkForce false;

    # waybar is disabled in ./waybar.nix rather than here — it also sets an
    # `ExecStart` override on its own systemd unit, and a unit definition left
    # behind by a disabled module would still be written out as a fragment.

    # wofi stays enabled, and is no longer the launcher. `theme-menu`,
    # `wallpaper-menu` and `session-menu` in ./scripts.nix all use it as a
    # plain `--dmenu` and keep working; only Mod+D moves.

    # GameMode is represented by the local plugin above, installed *and*
    # enabled. The old waybar signal hooks remain harmless; the plugin polls
    # `niri-gamemode status`, which reads a state file and only asks gamemoded
    # anything once it has established the daemon is already running — so the
    # poll never starts the D-Bus-activated daemon itself.
    #
    # What the mode *does* to this config while it is on is a second TOML file
    # dropped beside the generated one — ~/.config/noctalia/gamemode.toml, which
    # sorts after config.toml and therefore wins the merge. See ./gamemode.nix
    # for the whole arrangement; the keys it overrides are `shell.animation`,
    # the bar/panel/notification/OSD opacities, `panel.transparency_mode`, both
    # shadows, and the `system.monitor` block in `settings` above.
  };
}
