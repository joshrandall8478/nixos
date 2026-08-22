{ config, lib, pkgs, ... }:

# Renders each palette in themes.nix into the config formats niri, waybar,
# wofi, dunst, kitty, KDE, VS Code and swaylock actually read, and exposes
# them as one store path per theme.
#
# How runtime switching stays declarative
# ---------------------------------------
# home-manager owns ~/.config/... as read-only symlinks into the store, so a
# switcher script can't rewrite them. Instead every theme is built ahead of
# time and the only mutable state is a single symlink:
#
#     ~/.local/state/niri-theme/active -> /nix/store/...-niri-theme-<name>
#
# Each tool is pointed at a file underneath that symlink:
#
#   niri     `include` node, live-reloaded when the target changes
#   waybar   started with `-s <path>`, restarted by the switcher
#   wofi     `style` key in its config, re-read on every launch. Two
#            stylesheets: `wofi.css` for the launcher and the menus, and
#            `wofi-emoji.css` — the same thing with bigger rows — which the
#            emoji picker asks for with `--style`
#   dunst    `services.dunst.configFile`, restarted by the switcher
#   swayosd  `services.swayosd.stylePath`, which becomes `--style <path>` on
#            the server; restarted by the switcher, since it reads the
#            stylesheet once at startup
#   kitty    `include` at the end of kitty.conf, reloaded on SIGUSR1
#   KDE apps `~/.config/kdeglobals` symlink, re-read at app startup
#   firefox  `chrome/userChrome.css` + `userContent.css` symlinks, read once
#            at startup
#   VS Code  a whole generated extension, symlinked into
#            ~/.vscode/extensions, scanned once at startup
#
# Note these are *complete* files, not colour fragments. An earlier version
# emitted only `@define-color` blocks and pulled them in with a GTK CSS
# `@import`; that adds a resolution step that can silently no-op, and the
# whole stylesheet is generated anyway, so there is nothing to gain from it.
let
  themeSet = import ./themes.nix { inherit lib; };
  inherit (themeSet) themes;

  useNoctalia = config.local.niri.shell == "noctalia";

  stateDir = "${config.home.homeDirectory}/.local/state/niri-theme";
  activeDir = "${stateDir}/active";

  # Where Noctalia writes the same set of files this module renders. It owns
  # `active` under that shell — see the activation block at the bottom.
  liveDir = "${stateDir}/noctalia-live";

  # niri KDL fragment: focus ring, borders, overview backdrop.
  renderNiri = name: t: ''
    // Generated from home/joshr/niri/themes.nix — theme "${name}".
    // Included by config.kdl; niri reloads automatically when this changes.
    layout {
        focus-ring {
            off
        }

        border {
   	    on
            width 3

            // A workspace-relative gradient shifts subtly as the scrolling
            // layout moves, without requiring a continuous animation.
            active-color "${t.accent}"

            // Unfocused windows retain a darker tint of the active accent.
            inactive-color "${t.accentDim}"
            urgent-color "${t.err}"
        } 
        shadow {
            on
            softness 24
            spread 3
            offset x=0 y=4
            color "#00000070"
        }

        insert-hint {
            color "${t.accent}80"
        }
    }

    overview {
        backdrop-color "${t.bg}"
    }
  '';

  # Complete waybar stylesheet. Layout and colour together, so a theme switch
  # is just "point waybar at a different file and restart it".
  renderWaybarCss = name: t: ''
    /* Generated from home/joshr/niri/themes.nix — theme "${name}". */
    @define-color bg         ${t.bg};
    @define-color bg-alt     ${t.bgAlt};
    @define-color bg-urgent  ${t.bgUrgent};
    @define-color fg         ${t.fg};
    @define-color fg-dim     ${t.fgDim};
    @define-color accent     ${t.accent};
    @define-color accent-dim ${t.accentDim};
    @define-color warn       ${t.warn};
    @define-color err        ${t.err};
    @define-color bordercol  ${t.border};

    * {
      font-family: "FiraCode Nerd Font", "Noto Sans", sans-serif;
      font-size: 13px;
      font-weight: 500;
      border: none;
      border-radius: 0;
      min-height: 0;
    }

    window#waybar {
      background: transparent;
      color: @fg;
    }

    /* Each group is its own floating pill rather than one long bar. */
    .modules-left,
    .modules-center,
    .modules-right {
      background-color: alpha(@bg, 0.88);
      border: 1px solid alpha(@accent-dim, 0.55);
      border-radius: 12px;
      padding: 0 6px;
    }

    /* The left group's three modules keep the gap they had before the bar's
       `spacing` was cut to 4 for the right-hand cluster's sake. Spacing is one
       number for the whole bar, so 1px either side here puts the left group
       back at the 6px it was drawn for. */
    #custom-user,
    #workspaces,
    #window {
      margin: 0 1px;
    }

    /* Username, first slot on the left. Wears the accent for the same reason
       the clock does — it is a label, not a control, so it reads as chrome
       rather than as something to click. */
    #custom-user {
      padding: 0 12px;
      color: @accent;
      font-weight: 700;
    }

    #workspaces {
      padding: 0 2px;
    }

    #workspaces button {
      padding: 0 9px;
      margin: 4px 2px;
      color: @fg-dim;
      background: transparent;
      border-radius: 8px;
      transition: background-color 160ms ease, color 160ms ease;
    }

    #workspaces button:hover {
      background-color: alpha(@accent, 0.15);
      color: @fg;
      box-shadow: none;
      text-shadow: none;
    }

    #workspaces button.active {
      background-color: @accent;
      color: @bg;
      font-weight: 700;
    }

    #workspaces button.urgent {
      background-color: @err;
      color: @bg;
    }

    #window {
      padding: 0 10px;
      color: @fg;
    }

    window#waybar.empty #window {
      padding: 0;
      margin: 0;
      background: transparent;
    }

    #clock {
      padding: 0 16px;
      color: @accent;
      font-weight: 700;
    }

    /* The right-hand cluster. Tighter than it was: 8px of padding rather than
       10, and no horizontal margin at all, which leaves the bar's own 4px
       `spacing` as the entire gap between two pills — 4px where it used to be
       8, and 20px of whitespace between neighbouring glyphs where it used to
       be 28. Twelve slots at their widest is a lot of bar to hold, and the
       hover backgrounds still read as separate at 4px. The 4px top and bottom
       stay: that is what insets the pills inside the group's 34px. */
    #tray,
    #backlight,
    #pulseaudio,
    #network,
    #privacy,
    #custom-microphone-privacy,
    #battery,
    #power-profiles-daemon,
    #bluetooth,
    #mpris,
    #custom-caps-lock,
    #custom-gamemode,
    #custom-idle-inhibitor,
    #custom-lock,
    #custom-session {
      padding: 0 8px;
      margin: 4px 0;
      border-radius: 8px;
      color: @fg;
    }

    #tray > .passive {
      -gtk-icon-effect: dim;
    }

    #tray > .needs-attention {
      -gtk-icon-effect: highlight;
      background-color: @err;
      border-radius: 8px;
    }

    #backlight:hover,
    #pulseaudio:hover,
    #network:hover,
    #battery:hover,
    #power-profiles-daemon:hover,
    #mpris:hover,
    #bluetooth:hover,
    #custom-microphone-privacy:hover,
    #custom-idle-inhibitor:hover,
    #custom-lock:hover {
      background-color: alpha(@accent, 0.14);
    }

    /* Visible only while a non-Cava client is capturing. Orange means live;
       clicking mutes the source device the active application actually uses. */
    #custom-microphone-privacy {
      font-size: 15px;
    }

    #custom-microphone-privacy.active {
      color: #ff9800;
    }

    #custom-microphone-privacy.muted {
      color: @fg-dim;
    }

    /* Dim when idling is normal, lit when the machine is being held awake —
       the inhibitor is a mode you can forget you left on, so it should be
       obvious at a glance. */
    #custom-idle-inhibitor {
      color: @fg-dim;
      font-size: 15px;
    }

    #custom-idle-inhibitor.activated {
      color: @warn;
    }

    /* Caps lock, one slot to the left. No off state to style: the module is
       on screen only while the lock is on and waybar hides it completely the
       rest of the time (see capsLockWatch in scripts.nix), so this is the lit
       colour and nothing else. No hover rule either, unlike its neighbours —
       there is nothing here to click. */
    #custom-caps-lock {
      color: @warn;
      font-size: 15px;
    }

    /* GameMode, next to it and hidden the same way, so again there is only a
       lit state to write. The accent rather than warn: it sits directly
       beside caps lock and the two can be on at once, so they are told apart
       by colour as much as by shape — and unlike caps lock, gamemode being on
       is a thing you asked for rather than something to warn you about. */
    #custom-gamemode {
      color: @accent;
      font-size: 15px;
    }

    #pulseaudio.muted {
      color: @fg-dim;
    }

    /* Bluetooth off is dim rather than red, unlike the network rule below:
       nothing is broken when the radio is down, it is a thing you turned
       off — the same reading the muted sink directly above gets.

       Two classes because there are two ways off and only one of them is
       the obvious one. `off` is the controller powered down, which is what
       blueman's toggle and `bluetoothctl power off` do; `disabled` is
       rfkill blocking the radio, the airplane-mode route. Styling
       `disabled` alone would leave the common case lit. */
    #bluetooth.disabled,
    #bluetooth.off {
      color: @fg-dim;
    }

    #network.disconnected {
      color: @err;
    }

    #battery.warning:not(.charging) {
      color: @warn;
    }

    #battery.critical:not(.charging) {
      color: @bg;
      background-color: @err;
    }

    /* Charge and power profile are one widget, not two. `group/power` in
       waybar.nix puts them in a box with no spacing of its own, so the two
       halves meet flush where every other neighbouring pair on the bar has
       the bar's 4px between them.

       The group carries the pill's vertical inset and nothing else. The 8px
       of side padding stays on the halves themselves, which is what keeps the
       profile looking like every other pill on the hosts with no battery
       beside it to draw — it is on its own there, and a group that had taken
       the padding over would have left it with 16px a side. Their own
       `margin: 4px 0` from the block above has to come back off, or it would
       be added to the group's and squeeze both halves to 18px in a 34px bar.

       Nothing is written for the case where neither half draws — no battery
       and no daemon. waybar 0.15.0's group has no `empty` class to hang it
       on (that landed after the release), so all that is left there is a
       zero-width box and one 4px gap. Every graphical host runs the daemon,
       so it is not a case that arises. */
    #power {
      margin: 4px 0;
    }

    #power #battery,
    #power #power-profiles-daemon {
      margin: 0;
    }

    /* The three profiles, in the bar's own vocabulary: the accent for the one
       you chose in order to be thrifty, plain @fg for the default, and warn
       for the one that costs battery and heat — the same register the idle
       inhibitor two slots over uses for a mode you can forget you left on.

       @fg-dim, the obvious pick for power-saver, is deliberately not used. On
       this bar dim means *off* — the muted sink, the powered-down bluetooth
       radio — and power-saver is a profile that is emphatically on.

       `balanced` is @fg, which it would inherit from the pill rule anyway. It
       is written out so all three read as one mapping in one place, and so
       that a fourth profile from some other daemon backend has somewhere
       obvious to be added: waybar sets a CSS class named after whatever the
       profile is called. */
    #power-profiles-daemon.power-saver {
      color: @accent;
    }

    #power-profiles-daemon.balanced {
      color: @fg;
    }

    #power-profiles-daemon.performance {
      color: @warn;
    }

    /* Audio visualiser, immediately left of the track name.
       Deliberately quiet: the dimmed accent rather than the accent, no pill
       of its own and no hover state. It is texture beside the mpris module,
       not a control — and it disappears completely when nothing is playing,
       so it never holds a slot open in the bar.
       Monospace is not cosmetic here: with a proportional font the glyphs
       would be different widths and the whole widget would jitter sideways
       as the music moved. */
    #custom-cava {
      font-family: "FiraCode Nerd Font", monospace;
      font-size: 15px;
      color: @accent-dim;
      padding: 0 8px;
      margin: 4px 0;
    }

    /* Lock and power are a matched pair at the end of the bar: same size,
       same padding, so they read as one group of session controls. They
       differ only on hover — the destructive one goes red. */
    #custom-lock,
    #custom-session {
      color: @accent;
      font-size: 15px;
      padding: 0 12px;
    }

    #custom-session:hover {
      background-color: @err;
      color: @bg;
    }

    tooltip {
      background-color: @bg;
      border: 1px solid @accent-dim;
      border-radius: 10px;
    }

    tooltip label {
      color: @fg;
      padding: 4px;
    }
  '';

  # Complete wofi stylesheet.
  #
  # `extra` is appended verbatim at the end, which is how the emoji picker
  # gets its own variant below: GTK CSS takes the last matching rule, so a
  # block down there overrides whatever the shared part already set. The two
  # stylesheets share one renderer rather than being two copies that slowly
  # stop matching each other.
  renderWofiCssWith =
    { extra ? "" }:
    name: t: ''
    /* Generated from home/joshr/niri/themes.nix — theme "${name}". */
    @define-color bg         ${t.bg};
    @define-color bg-alt     ${t.bgAlt};
    @define-color fg         ${t.fg};
    @define-color fg-dim     ${t.fgDim};
    @define-color accent     ${t.accent};
    @define-color bordercol  ${t.border};

    * {
      font-family: "FiraCode Nerd Font", "Noto Sans", sans-serif;
      font-size: 14px;
    }

    window {
      background-color: alpha(@bg, 0.96);
      border: 1px solid @accent;
      border-radius: 14px;
    }

    #outer-box {
      padding: 14px;
    }

    #input {
      background-color: @bg-alt;
      color: @fg;
      border: 1px solid @bordercol;
      border-radius: 10px;
      padding: 9px 12px;
      margin-bottom: 12px;
    }

    #input:focus {
      border-color: @accent;
    }

    #input image {
      color: @accent;
    }

    #scroll {
      margin: 0;
    }

    #inner-box {
      background-color: transparent;
    }

    #entry {
      padding: 8px 10px;
      border-radius: 9px;
      color: @fg;
      background-color: transparent;
    }

    #entry:selected {
      background-color: @accent;
      color: @bg;
      font-weight: 700;
    }

    #entry image {
      margin-right: 10px;
    }

    #text {
      color: inherit;
    }

    #text:selected {
      color: @bg;
    }

    #entry #text mark {
      background-color: transparent;
      color: @accent;
      font-weight: 700;
    }

    #entry:selected #text mark {
      color: @bg;
      text-decoration: underline;
    }
    ${extra}
  '';

  renderWofiCss = renderWofiCssWith { };

  # The emoji picker's stylesheet: everything above, plus rows that put Fluent
  # Emoji at the front of the font stack and draw them big enough to tell
  # apart at a glance.
  #
  # Only `#entry` is enlarged, not `*`. The search box keeps the normal 14px —
  # what you type there is a name like "grinning", not an emoji, and a 20px
  # input just makes the window taller for nothing.
  #
  # `#entry #text` is named alongside `#entry` rather than left to inherit,
  # because the `*` rule near the top matches that label directly and a direct
  # match beats an inherited value however far down the file the parent's rule
  # is. Setting only `#entry` would leave the rows at 14px.
  #
  # The text fonts stay in the stack behind Fluent Emoji because each row is
  # `😀 grinning face`: the glyph comes from the first family that has it, the
  # description from FiraCode as everywhere else. Naming the emoji font alone
  # would leave the names to whatever fontconfig picked.
  renderWofiEmojiCss = renderWofiCssWith {
    extra = ''
      #entry, #entry #text {
        font-family: "Fluent Emoji Color", "FiraCode Nerd Font", "Noto Sans", sans-serif;
        font-size: 20px;
      }
    '';
  };

  renderDunstrc = name: t: ''
    # Generated from home/joshr/niri/themes.nix — theme "${name}".
    [global]
        monitor = 0
        follow = mouse
        width = (300, 460)
        height = (0, 320)
        origin = top-right
        offset = (16, 16)
        scale = 0
        notification_limit = 6
        progress_bar = true
        progress_bar_height = 8
        progress_bar_frame_width = 1
        progress_bar_min_width = 150
        progress_bar_max_width = 400
        indicate_hidden = yes
        transparency = 8
        separator_height = 2
        padding = 14
        horizontal_padding = 16
        text_icon_padding = 12
        frame_width = 2
        frame_color = "${t.accentDim}"
        separator_color = frame
        sort = yes
        font = FiraCode Nerd Font 10
        line_height = 0
        markup = full
        format = "<b>%s</b>\n%b"
        alignment = left
        vertical_alignment = center
        show_age_threshold = 60
        ellipsize = middle
        ignore_newline = no
        stack_duplicates = true
        hide_duplicate_count = false
        show_indicators = yes
        enable_recursive_icon_lookup = true
        icon_theme = "Papirus-Dark"
        icon_position = left
        min_icon_size = 24
        max_icon_size = 48
        sticky_history = yes
        history_length = 40
        corner_radius = 10
        mouse_left_click = do_action, close_current
        mouse_middle_click = close_all
        mouse_right_click = close_current

    [urgency_low]
        background = "${t.bg}"
        foreground = "${t.fgDim}"
        frame_color = "${t.accentDim}"
        timeout = 5

    [urgency_normal]
        background = "${t.bg}"
        foreground = "${t.fg}"
        frame_color = "${t.accent}"
        timeout = 8

    [urgency_critical]
        background = "${t.bgUrgent}"
        foreground = "${t.fg}"
        frame_color = "${t.err}"
        timeout = 0
  '';

  # swayosd — the volume/brightness pop-up. See ./osd.nix.
  #
  # An override sheet, not a whole stylesheet: swayosd loads the one it ships
  # at GTK's APPLICATION priority and this one at USER priority, which is
  # higher, so only the parts that should look different are restated. The
  # layout — margins, the capsule ends on the bar, the dimming of a disabled
  # widget — stays upstream's.
  #
  # GTK4 node names, since swayosd 0.3 is a GTK4 application: `window#osd` is
  # the surface, `#container` the box inside it, and a progress bar is
  # `progressbar > trough > progress` — the track and then the fill.
  #
  # Colours follow the same rule as everything else here: the accent is what
  # the active thing wears, so it goes on the icon and the filled part of the
  # bar, with the track a dim wash of the secondary text colour. The frame is
  # waybar's pill exactly — same 1px, same dimmed accent at 0.55 — because the
  # two are on screen together and a near-miss reads worse than a match.
  #
  # 16px rather than upstream's 999px: a capsule is the stock look, but every
  # other surface in this session is a rounded rectangle (waybar 12, wofi 14,
  # windows 8), and the OSD is not the thing to make an exception for.
  renderSwayosdCss = name: t: ''
    /* Generated from home/joshr/niri/themes.nix — theme "${name}". */

    window#osd {
      background-color: ${rgba t.bg "0.92"};
      border: 1px solid ${rgba t.accentDim "0.55"};
      border-radius: 16px;
    }

    window#osd #container {
      margin: 16px 20px;
    }

    window#osd label {
      font-family: "FiraCode Nerd Font", "Noto Sans", sans-serif;
      font-size: 14px;
      font-weight: 500;
      color: ${t.fg};
    }

    window#osd image {
      color: ${t.accent};
    }

    window#osd progressbar {
      min-height: 8px;
    }

    /* The unfilled track. `trough` and `progress` inherit their height and
       corner radius from the bar above, so setting min-height there is enough
       for both. */
    window#osd trough {
      background-color: ${rgba t.fgDim "0.35"};
    }

    window#osd progress {
      background-color: ${t.accent};
    }
  '';

  # One channel of a "#rrggbb", as an integer 0–255. `start` is the byte
  # offset into the digits: 0 red, 2 green, 4 blue.
  channel =
    hex: start: lib.fromHexString (builtins.substring start 2 (lib.removePrefix "#" hex));

  # "#rrggbb" -> "r,g,b". KDE colour keys are decimal triples, not hex.
  rgb = hex: "${toString (channel hex 0)},${toString (channel hex 2)},${toString (channel hex 4)}";

  # "#rrggbb" -> "rgba(r, g, b, a)", for GTK stylesheets that need a colour
  # with transparency in it.
  #
  # waybar's and wofi's sheets reach for GTK's own `alpha(@name, a)` instead,
  # which they can because they define every `@name` themselves with
  # `@define-color`. swayosd's stylesheet is written against `@theme_bg_color`
  # and friends — GTK theme colours, which exist only if the loaded GTK theme
  # defines them — so its overrides spell the channels out rather than inherit
  # that dependency.
  rgba =
    hex: a:
    "rgba(${toString (channel hex 0)}, ${toString (channel hex 2)}, ${toString (channel hex 4)}, ${a})";

  # BT.601 luma of a "#rrggbb", 0–255.
  #
  # Only used to answer one question: is this palette light or dark? Firefox
  # draws scrollbars, checkboxes and dropdown arrows from CSS `color-scheme`
  # rather than from any colour we can set, so getting that backwards leaves
  # those widgets invisible against the themed chrome. Of the palettes here
  # only mono-light, gruvbox-light, rose-pine-dawn and sandstone come out
  # light; the threshold is nowhere near any of them, the darkest light one
  # being gruvbox-light at 239 and the lightest dark one catppuccin-frappé
  # at 53.
  luma = hex: (299 * (channel hex 0) + 587 * (channel hex 2) + 114 * (channel hex 4)) / 1000;

  colorScheme = t: if luma t.bg > 127 then "light" else "dark";

  # kdeglobals, so KDE apps — Dolphin in particular — follow the palette.
  #
  # KDE apps read their colour scheme from kdeglobals via KColorScheme
  # whether or not Plasma is running, so this works in a bare niri session
  # with no KDE desktop underneath it.
  renderKdeglobals = name: t: ''
    # Generated from home/joshr/niri/themes.nix — theme "${name}".
    [General]
    ColorScheme=niri-${name}
    AccentColor=${rgb t.accent}
    accentColorFromWallpaper=false
    TerminalApplication=${pkgs.kitty}/bin/kitty

    [Icons]
    Theme=Papirus-Dark

    [KDE]
    widgetStyle=Breeze

    [Colors:Window]
    BackgroundNormal=${rgb t.bg}
    BackgroundAlternate=${rgb t.bgAlt}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    ForegroundLink=${rgb t.accent}
    ForegroundVisited=${rgb t.accentDim}
    ForegroundNegative=${rgb t.err}
    ForegroundNeutral=${rgb t.warn}
    ForegroundPositive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:View]
    BackgroundNormal=${rgb t.bg}
    BackgroundAlternate=${rgb t.bgAlt}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    ForegroundLink=${rgb t.accent}
    ForegroundVisited=${rgb t.accentDim}
    ForegroundNegative=${rgb t.err}
    ForegroundNeutral=${rgb t.warn}
    ForegroundPositive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Button]
    BackgroundNormal=${rgb t.bgAlt}
    BackgroundAlternate=${rgb t.bg}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    ForegroundLink=${rgb t.accent}
    ForegroundVisited=${rgb t.accentDim}
    ForegroundNegative=${rgb t.err}
    ForegroundNeutral=${rgb t.warn}
    ForegroundPositive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Selection]
    BackgroundNormal=${rgb t.accent}
    BackgroundAlternate=${rgb t.accentDim}
    ForegroundNormal=${rgb t.bg}
    ForegroundInactive=${rgb t.bgAlt}
    ForegroundActive=${rgb t.bg}
    ForegroundLink=${rgb t.bg}
    ForegroundVisited=${rgb t.bgAlt}
    ForegroundNegative=${rgb t.err}
    ForegroundNeutral=${rgb t.warn}
    ForegroundPositive=${rgb t.bg}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Tooltip]
    BackgroundNormal=${rgb t.bgAlt}
    BackgroundAlternate=${rgb t.bg}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Complementary]
    BackgroundNormal=${rgb t.bg}
    BackgroundAlternate=${rgb t.bgAlt}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [Colors:Header]
    BackgroundNormal=${rgb t.bgAlt}
    BackgroundAlternate=${rgb t.bg}
    ForegroundNormal=${rgb t.fg}
    ForegroundInactive=${rgb t.fgDim}
    ForegroundActive=${rgb t.accent}
    DecorationFocus=${rgb t.accent}
    DecorationHover=${rgb t.accent}

    [WM]
    activeBackground=${rgb t.bg}
    activeForeground=${rgb t.fg}
    inactiveBackground=${rgb t.bgAlt}
    inactiveForeground=${rgb t.fgDim}
  '';

  # Fallback terminal palette for a theme with no `ansi` block.
  #
  # The ten roles have no blue, magenta or cyan in them, so those three have
  # to borrow the accent — the result is legible but flat, and anything that
  # colour-codes by hue (git diff, ls, syntax highlighting) loses most of its
  # distinctions. Every theme in themes.nix defines `ansi` for that reason;
  # this exists so adding one without it degrades instead of failing.
  deriveAnsi = t: {
    black = t.bg;          brightBlack = t.fgDim;
    red = t.err;           brightRed = t.err;
    green = t.accent;      brightGreen = t.accent;
    yellow = t.warn;       brightYellow = t.warn;
    blue = t.accentDim;    brightBlue = t.accent;
    magenta = t.accentDim; brightMagenta = t.accent;
    cyan = t.accentDim;    brightCyan = t.accent;
    white = t.fg;          brightWhite = t.fg;
  };

  # kitty colours. Only colours — kitty.nix keeps font, padding, opacity and
  # the rest, and this is `include`d after them so a theme switch can't
  # disturb any of that.
  renderKitty =
    name: t:
    let
      a = t.ansi or (deriveAnsi t);
    in
    ''
      # Generated from home/joshr/niri/themes.nix — theme "${name}".
      # Included by kitty.conf; reloaded in place on SIGUSR1.

      foreground           ${t.fg}
      background           ${t.bg}
      selection_foreground ${t.bg}
      selection_background ${t.accent}

      cursor               ${t.accent}
      cursor_text_color    ${t.bg}

      url_color            ${t.accent}

      # Window borders only show with more than one kitty split.
      active_border_color   ${t.accent}
      inactive_border_color ${t.border}
      bell_border_color     ${t.err}

      active_tab_foreground   ${t.bg}
      active_tab_background   ${t.accent}
      inactive_tab_foreground ${t.fgDim}
      inactive_tab_background ${t.bgAlt}
      tab_bar_background      ${t.bg}

      mark1_foreground ${t.bg}
      mark1_background ${t.accent}

      color0  ${a.black}
      color8  ${a.brightBlack}
      color1  ${a.red}
      color9  ${a.brightRed}
      color2  ${a.green}
      color10 ${a.brightGreen}
      color3  ${a.yellow}
      color11 ${a.brightYellow}
      color4  ${a.blue}
      color12 ${a.brightBlue}
      color5  ${a.magenta}
      color13 ${a.brightMagenta}
      color6  ${a.cyan}
      color14 ${a.brightCyan}
      color7  ${a.white}
      color15 ${a.brightWhite}
    '';

  # Firefox's browser chrome.
  #
  # Firefox has no supported way to take arbitrary colours from outside the
  # browser. A WebExtension theme could — that's the documented mechanism, and
  # it covers every surface — but installing an unsigned one needs
  # `xpinstall.signatures.required=false`, which release builds ignore. So
  # this is userChrome.css, overriding the internal custom properties the UI
  # is actually built out of.
  #
  # That makes it the one file here written against another program's
  # internals rather than its config format. The names below have been stable
  # since the Proton redesign, but they aren't API: if a Firefox release
  # renames one, that surface quietly falls back to the built-in dark theme
  # instead of breaking, and the fix is to diff against `browser.css` in the
  # new version.
  #
  # Requires `toolkit.legacyUserProfileCustomizations.stylesheets`, set in
  # home/joshr/firefox.nix. Firefox reads it once at startup, so a theme
  # switch lands the next time the browser starts — same as Dolphin and
  # kdeglobals.
  renderFirefoxUserChrome =
    name: t:
    ''
      /* Generated from home/joshr/niri/themes.nix — theme "${name}". */

      :root {
        /* Native widgets inside the chrome — scrollbars, checkboxes, the
           dropdown arrows — are drawn from this and nothing else. */
        color-scheme: ${colorScheme t};
        scrollbar-color: ${t.accentDim} ${t.bg};

        /* Window frame and tab strip. */
        --lwt-accent-color: ${t.bg} !important;
        --lwt-accent-color-inactive: ${t.bg} !important;
        --lwt-text-color: ${t.fg} !important;
        --tab-selected-bgcolor: ${t.bgAlt} !important;
        --tab-selected-textcolor: ${t.fg} !important;
        --tab-selected-outline-color: ${t.accent} !important;
        --tab-hover-background-color: ${t.accent}1f !important;
        --lwt-tab-line-color: ${t.accent} !important;

        /* Toolbars. */
        --toolbar-bgcolor: ${t.bgAlt} !important;
        --toolbar-color: ${t.fg} !important;
        --toolbarbutton-icon-fill: ${t.fg} !important;
        --toolbarbutton-icon-fill-attention: ${t.accent} !important;
        --toolbarbutton-hover-background: ${t.accent}26 !important;
        --toolbarbutton-active-background: ${t.accent}40 !important;
        --chrome-content-separator-color: ${t.border} !important;

        /* Address and search bars. */
        --toolbar-field-background-color: ${t.bg} !important;
        --toolbar-field-color: ${t.fg} !important;
        --toolbar-field-border-color: ${t.border} !important;
        --toolbar-field-focus-background-color: ${t.bg} !important;
        --toolbar-field-focus-color: ${t.fg} !important;
        --toolbar-field-focus-border-color: ${t.accent} !important;
        --toolbar-field-highlight: ${t.accent} !important;
        --toolbar-field-highlight-color: ${t.bg} !important;

        /* The identity / permissions block inside the address bar. */
        --urlbar-box-bgcolor: ${t.bgAlt} !important;
        --urlbar-box-focus-bgcolor: ${t.bgAlt} !important;
        --urlbar-box-hover-bgcolor: ${t.accent}26 !important;
        --urlbar-box-text-color: ${t.fg} !important;

        /* Menus, doorhangers and the address bar dropdown. */
        --arrowpanel-background: ${t.bg} !important;
        --arrowpanel-color: ${t.fg} !important;
        --arrowpanel-border-color: ${t.border} !important;
        --arrowpanel-dimmed: ${t.accent}1f !important;
        --panel-background: ${t.bg} !important;
        --panel-color: ${t.fg} !important;
        --panel-border-color: ${t.border} !important;
        --panel-separator-color: ${t.border} !important;
        --panel-item-hover-bgcolor: ${t.accent}26 !important;
        --panel-item-active-bgcolor: ${t.accent}40 !important;

        /* Buttons in chrome dialogs. */
        --button-bgcolor: ${t.bgAlt} !important;
        --button-color: ${t.fg} !important;
        --button-hover-bgcolor: ${t.accent}26 !important;
        --button-active-bgcolor: ${t.accent}40 !important;
        --button-primary-bgcolor: ${t.accent} !important;
        --button-primary-hover-bgcolor: ${t.accentDim} !important;
        --button-primary-active-bgcolor: ${t.accentDim} !important;
        --button-primary-color: ${t.bg} !important;

        --focus-outline-color: ${t.accent} !important;
        --link-color: ${t.accent} !important;
        --link-color-hover: ${t.accent} !important;

        /* Sidebar: bookmarks, history, synced tabs. */
        --sidebar-background-color: ${t.bg} !important;
        --sidebar-text-color: ${t.fg} !important;
        --sidebar-border-color: ${t.border} !important;

        /* Kept louder than the rest of the chrome, same as everywhere else. */
        --warning-color: ${t.warn} !important;
        --error-text-color: ${t.err} !important;
      }

      /* Some builds paint the toolbox rather than the frame, so both. */
      #navigator-toolbox {
        background-color: ${t.bg} !important;
        border-bottom: 1px solid ${t.border} !important;
      }

      #nav-bar {
        background-color: ${t.bgAlt} !important;
        color: ${t.fg} !important;
        box-shadow: none !important;
      }

      /* Selected tab: solid fill plus the accent line along its top edge —
         the same "active thing wears the accent" rule as waybar's workspaces
         and niri's focus ring. */
      .tab-background[selected="true"] {
        background-image: none !important;
        background-color: ${t.bgAlt} !important;
        outline-color: ${t.accent} !important;
      }

      .tabbrowser-tab:not([selected="true"]) .tab-label {
        color: ${t.fgDim} !important;
      }

      #urlbar > #urlbar-background,
      #searchbar {
        background-color: ${t.bg} !important;
        border-color: ${t.border} !important;
      }

      #urlbar[focused="true"] > #urlbar-background {
        border-color: ${t.accent} !important;
        outline-color: ${t.accent} !important;
      }

      .urlbarView-row:hover,
      .urlbarView-row[selected] {
        background-color: ${t.accent}26 !important;
      }

      menu[_moz-menuactive="true"],
      menuitem[_moz-menuactive="true"] {
        background-color: ${t.accent}26 !important;
        color: ${t.fg} !important;
      }

      findbar {
        background-color: ${t.bgAlt} !important;
        color: ${t.fg} !important;
        border-top-color: ${t.border} !important;
      }

      /* The little "loading…" / link target overlay at the bottom left. */
      #statuspanel-label {
        background-color: ${t.bgAlt} !important;
        color: ${t.fg} !important;
        border-color: ${t.border} !important;
      }
    '';

  # about: pages — Preferences, Add-ons, the new tab, the error pages.
  #
  # Web pages are deliberately untouched. Recolouring arbitrary sites from a
  # desktop palette breaks far more than it fixes, and Firefox already has
  # Reader View for the cases where it helps.
  renderFirefoxUserContent =
    name: t:
    ''
      /* Generated from home/joshr/niri/themes.nix — theme "${name}". */

      @-moz-document url-prefix("about:") {
        :root {
          color-scheme: ${colorScheme t} !important;
          scrollbar-color: ${t.accentDim} ${t.bg};

          --in-content-page-background: ${t.bg} !important;
          --in-content-page-color: ${t.fg} !important;
          --in-content-text-color: ${t.fg} !important;
          --in-content-deemphasized-text: ${t.fgDim} !important;
          --in-content-box-background: ${t.bgAlt} !important;
          --in-content-box-background-odd: ${t.bg} !important;
          --in-content-box-border-color: ${t.border} !important;
          --in-content-border-color: ${t.border} !important;
          --in-content-accent-color: ${t.accent} !important;
          --in-content-link-color: ${t.accent} !important;
          --in-content-link-color-hover: ${t.accent} !important;
          --in-content-focus-outline-color: ${t.accent} !important;
          --in-content-button-background: ${t.bgAlt} !important;
          --in-content-button-background-hover: ${t.accent}26 !important;
          --in-content-button-text-color: ${t.fg} !important;
          --in-content-primary-button-background: ${t.accent} !important;
          --in-content-primary-button-background-hover: ${t.accentDim} !important;
          --in-content-primary-button-text-color: ${t.bg} !important;

          --newtab-background-color: ${t.bg} !important;
          --newtab-background-color-secondary: ${t.bgAlt} !important;
          --newtab-text-primary-color: ${t.fg} !important;
          --newtab-primary-action-background: ${t.accent} !important;

          --link-color: ${t.accent} !important;
          --link-color-hover: ${t.accent} !important;
        }
      }
    '';

  # VS Code.
  #
  # VS Code has no "read my colours from this file" setting — a colour theme
  # can only arrive as an extension. So each palette renders a complete,
  # self-contained extension: a manifest contributing one theme called
  # "Niri", and the theme JSON itself. home/joshr/niri/vscode.nix drops the
  # whole directory into ~/.vscode/extensions as an out-of-store symlink, so
  # switching themes re-points it at a different build of the same extension
  # and the name in `workbench.colorTheme` never has to change.
  #
  # VS Code reads extensions once, at startup, so a theme switch lands the
  # next time the editor starts — same as Dolphin and Firefox.
  #
  # `uiTheme` is what VS Code falls back to for any colour key not listed
  # below, which is why it tracks the palette's own light/dark-ness rather
  # than being pinned to vs-dark.
  renderVscodeManifest =
    name: t:
    builtins.toJSON {
      name = "niri-theme";
      displayName = "niri theme";
      description = "Follows the active niri desktop palette (built from “${name}”).";
      version = "1.0.0";
      publisher = "niri";
      engines.vscode = "^1.70.0";
      categories = [ "Themes" ];
      contributes.themes = [
        {
          label = "Niri";
          uiTheme = if colorScheme t == "dark" then "vs-dark" else "vs";
          path = "./themes/niri-color-theme.json";
        }
      ];
    };

  # The theme itself. Written as Nix and converted rather than kept as a JSON
  # string, so the palette roles appear once each and a typo is an evaluation
  # error instead of a colour that silently doesn't apply.
  #
  # Syntax colours come from the theme's `ansi` block, for the same reason
  # kitty's do: the ten UI roles have no blue, magenta or cyan in them, and a
  # syntax palette built only out of the accent makes every token look alike.
  renderVscodeTheme =
    name: t:
    let
      a = t.ansi or (deriveAnsi t);

      # Selection, hover and "current line" tints. VS Code takes #RRGGBBAA,
      # so these are the accent at a few opacities rather than pre-blended
      # colours that would have to be recomputed per palette.
      faint = "${t.accent}14";
      soft = "${t.accent}26";
      medium = "${t.accent}40";
    in
    builtins.toJSON {
      name = "Niri (${name})";
      type = colorScheme t;
      semanticHighlighting = true;

      colors = {
        # --- editor ----------------------------------------------------
        "editor.background" = t.bg;
        "editor.foreground" = t.fg;
        "editorLineNumber.foreground" = t.fgDim;
        "editorLineNumber.activeForeground" = t.accent;
        "editorCursor.foreground" = t.accent;
        "editor.lineHighlightBackground" = faint;
        "editor.selectionBackground" = medium;
        "editor.selectionHighlightBackground" = soft;
        "editor.wordHighlightBackground" = soft;
        "editor.wordHighlightStrongBackground" = medium;
        "editor.findMatchBackground" = medium;
        "editor.findMatchHighlightBackground" = soft;
        "editor.hoverHighlightBackground" = soft;
        "editorWhitespace.foreground" = t.fgDim;
        "editorIndentGuide.background1" = t.border;
        "editorIndentGuide.activeBackground1" = t.accentDim;
        "editorRuler.foreground" = t.border;
        "editorBracketMatch.background" = soft;
        "editorBracketMatch.border" = t.accent;
        "editorError.foreground" = t.err;
        "editorWarning.foreground" = t.warn;
        "editorInfo.foreground" = t.accentDim;
        "editorGutter.addedBackground" = a.green;
        "editorGutter.modifiedBackground" = a.blue;
        "editorGutter.deletedBackground" = t.err;
        "editorOverviewRuler.border" = t.border;

        "editorWidget.background" = t.bgAlt;
        "editorWidget.border" = t.border;
        "editorSuggestWidget.background" = t.bgAlt;
        "editorSuggestWidget.border" = t.border;
        "editorSuggestWidget.selectedBackground" = medium;
        "editorSuggestWidget.highlightForeground" = t.accent;
        "editorHoverWidget.background" = t.bgAlt;
        "editorHoverWidget.border" = t.border;

        # --- chrome ----------------------------------------------------
        "foreground" = t.fg;
        "descriptionForeground" = t.fgDim;
        "errorForeground" = t.err;
        "focusBorder" = t.accent;
        "contrastBorder" = t.border;
        "widget.shadow" = "#00000070";
        "selection.background" = medium;

        "titleBar.activeBackground" = t.bg;
        "titleBar.activeForeground" = t.fg;
        "titleBar.inactiveBackground" = t.bg;
        "titleBar.inactiveForeground" = t.fgDim;
        "titleBar.border" = t.border;

        "activityBar.background" = t.bg;
        "activityBar.foreground" = t.accent;
        "activityBar.inactiveForeground" = t.fgDim;
        "activityBar.border" = t.border;
        "activityBar.activeBorder" = t.accent;
        "activityBarBadge.background" = t.accent;
        "activityBarBadge.foreground" = t.bg;

        "sideBar.background" = t.bg;
        "sideBar.foreground" = t.fg;
        "sideBar.border" = t.border;
        "sideBarTitle.foreground" = t.fgDim;
        "sideBarSectionHeader.background" = t.bgAlt;
        "sideBarSectionHeader.foreground" = t.fg;
        "sideBarSectionHeader.border" = t.border;

        "editorGroupHeader.tabsBackground" = t.bg;
        "editorGroupHeader.tabsBorder" = t.border;
        "editorGroup.border" = t.border;

        # The active tab wears the accent along its top edge — the same
        # "active thing gets the accent" rule as waybar's workspaces and
        # niri's focus ring.
        "tab.activeBackground" = t.bgAlt;
        "tab.activeForeground" = t.fg;
        "tab.activeBorderTop" = t.accent;
        "tab.inactiveBackground" = t.bg;
        "tab.inactiveForeground" = t.fgDim;
        "tab.border" = t.border;
        "tab.hoverBackground" = soft;
        "tab.unfocusedActiveBorderTop" = t.accentDim;

        "statusBar.background" = t.bgAlt;
        "statusBar.foreground" = t.fg;
        "statusBar.border" = t.border;
        "statusBar.noFolderBackground" = t.bgAlt;
        "statusBar.debuggingBackground" = t.warn;
        "statusBar.debuggingForeground" = t.bg;
        "statusBarItem.remoteBackground" = t.accent;
        "statusBarItem.remoteForeground" = t.bg;
        "statusBarItem.hoverBackground" = soft;
        "statusBarItem.errorBackground" = t.err;
        "statusBarItem.errorForeground" = t.bg;
        "statusBarItem.warningBackground" = t.warn;
        "statusBarItem.warningForeground" = t.bg;

        "panel.background" = t.bg;
        "panel.border" = t.border;
        "panelTitle.activeForeground" = t.fg;
        "panelTitle.activeBorder" = t.accent;
        "panelTitle.inactiveForeground" = t.fgDim;

        "menu.background" = t.bgAlt;
        "menu.foreground" = t.fg;
        "menu.border" = t.border;
        "menu.selectionBackground" = medium;
        "menu.selectionForeground" = t.fg;
        "menu.separatorBackground" = t.border;
        "menubar.selectionBackground" = soft;

        "quickInput.background" = t.bgAlt;
        "quickInput.foreground" = t.fg;
        "quickInputList.focusBackground" = medium;
        "quickInputList.focusForeground" = t.fg;
        "pickerGroup.border" = t.border;
        "pickerGroup.foreground" = t.accent;

        "list.activeSelectionBackground" = medium;
        "list.activeSelectionForeground" = t.fg;
        "list.inactiveSelectionBackground" = soft;
        "list.hoverBackground" = faint;
        "list.highlightForeground" = t.accent;
        "list.focusBackground" = medium;
        "list.errorForeground" = t.err;
        "list.warningForeground" = t.warn;
        "tree.indentGuidesStroke" = t.border;

        "input.background" = t.bgAlt;
        "input.foreground" = t.fg;
        "input.border" = t.border;
        "input.placeholderForeground" = t.fgDim;
        "inputOption.activeBorder" = t.accent;
        "inputValidation.errorBackground" = t.bgUrgent;
        "inputValidation.errorBorder" = t.err;
        "dropdown.background" = t.bgAlt;
        "dropdown.foreground" = t.fg;
        "dropdown.border" = t.border;

        "button.background" = t.accent;
        "button.foreground" = t.bg;
        "button.hoverBackground" = t.accentDim;
        "button.secondaryBackground" = t.bgAlt;
        "button.secondaryForeground" = t.fg;
        "badge.background" = t.accent;
        "badge.foreground" = t.bg;
        "progressBar.background" = t.accent;

        "scrollbar.shadow" = "#00000070";
        "scrollbarSlider.background" = "${t.accentDim}59";
        "scrollbarSlider.hoverBackground" = "${t.accentDim}80";
        "scrollbarSlider.activeBackground" = t.accent;

        "breadcrumb.foreground" = t.fgDim;
        "breadcrumb.focusForeground" = t.fg;
        "breadcrumb.activeSelectionForeground" = t.accent;
        "breadcrumbPicker.background" = t.bgAlt;

        "peekView.border" = t.accent;
        "peekViewEditor.background" = t.bgAlt;
        "peekViewResult.background" = t.bgAlt;
        "peekViewTitle.background" = t.bgAlt;
        "peekViewResult.selectionBackground" = medium;

        "notifications.background" = t.bgAlt;
        "notifications.foreground" = t.fg;
        "notifications.border" = t.border;
        "notificationLink.foreground" = t.accent;

        "diffEditor.insertedTextBackground" = "${a.green}26";
        "diffEditor.removedTextBackground" = "${t.err}26";
        "merge.currentHeaderBackground" = "${a.green}59";
        "merge.incomingHeaderBackground" = "${a.blue}59";

        "gitDecoration.modifiedResourceForeground" = a.yellow;
        "gitDecoration.deletedResourceForeground" = t.err;
        "gitDecoration.untrackedResourceForeground" = a.green;
        "gitDecoration.ignoredResourceForeground" = t.fgDim;
        "gitDecoration.conflictingResourceForeground" = t.warn;

        "textLink.foreground" = t.accent;
        "textLink.activeForeground" = t.accent;
        "textPreformat.foreground" = a.cyan;
        "textBlockQuote.background" = t.bgAlt;
        "textCodeBlock.background" = t.bgAlt;

        # --- integrated terminal --------------------------------------
        # The same 16 colours kitty gets, so a shell looks identical in
        # either terminal.
        "terminal.background" = t.bg;
        "terminal.foreground" = t.fg;
        "terminalCursor.foreground" = t.accent;
        "terminal.selectionBackground" = medium;
        "terminal.ansiBlack" = a.black;
        "terminal.ansiRed" = a.red;
        "terminal.ansiGreen" = a.green;
        "terminal.ansiYellow" = a.yellow;
        "terminal.ansiBlue" = a.blue;
        "terminal.ansiMagenta" = a.magenta;
        "terminal.ansiCyan" = a.cyan;
        "terminal.ansiWhite" = a.white;
        "terminal.ansiBrightBlack" = a.brightBlack;
        "terminal.ansiBrightRed" = a.brightRed;
        "terminal.ansiBrightGreen" = a.brightGreen;
        "terminal.ansiBrightYellow" = a.brightYellow;
        "terminal.ansiBrightBlue" = a.brightBlue;
        "terminal.ansiBrightMagenta" = a.brightMagenta;
        "terminal.ansiBrightCyan" = a.brightCyan;
        "terminal.ansiBrightWhite" = a.brightWhite;
      };

      tokenColors = [
        {
          scope = [ "comment" "punctuation.definition.comment" ];
          settings = {
            foreground = a.brightBlack;
            fontStyle = "italic";
          };
        }
        {
          scope = [ "string" "constant.other.symbol" ];
          settings.foreground = a.green;
        }
        {
          scope = [ "constant.character.escape" "string.regexp" ];
          settings.foreground = a.cyan;
        }
        {
          scope = [ "constant.numeric" "constant.language" "keyword.other.unit" ];
          settings.foreground = a.yellow;
        }
        {
          scope = [ "keyword" "storage" "storage.type" "keyword.control" ];
          settings.foreground = a.magenta;
        }
        {
          scope = [ "keyword.operator" "punctuation" "meta.brace" ];
          settings.foreground = t.fgDim;
        }
        {
          scope = [ "entity.name.function" "support.function" "meta.function-call" ];
          settings.foreground = a.blue;
        }
        {
          scope = [
            "entity.name.type"
            "entity.name.class"
            "entity.name.namespace"
            "support.type"
            "support.class"
          ];
          settings.foreground = a.brightCyan;
        }
        {
          scope = [ "variable" "meta.definition.variable" ];
          settings.foreground = t.fg;
        }
        {
          scope = [ "variable.parameter" "variable.other.member" ];
          settings.foreground = a.brightYellow;
        }
        {
          scope = [ "entity.name.tag" "meta.tag" ];
          settings.foreground = a.red;
        }
        {
          scope = [ "entity.other.attribute-name" ];
          settings.foreground = a.brightMagenta;
        }
        {
          scope = [ "invalid" "invalid.illegal" ];
          settings.foreground = t.err;
        }
        {
          scope = [ "markup.heading" "entity.name.section" ];
          settings = {
            foreground = t.accent;
            fontStyle = "bold";
          };
        }
        {
          scope = [ "markup.bold" ];
          settings.fontStyle = "bold";
        }
        {
          scope = [ "markup.italic" ];
          settings.fontStyle = "italic";
        }
        {
          scope = [ "markup.inserted" ];
          settings.foreground = a.green;
        }
        {
          scope = [ "markup.deleted" ];
          settings.foreground = t.err;
        }
        {
          scope = [ "markup.underline.link" ];
          settings.foreground = t.accent;
        }
      ];
    };

  # swaylock takes flags, not a config file, so its palette is a shell
  # fragment the lock script sources.
  renderSwaylockEnv = name: t: ''
    # Generated from home/joshr/niri/themes.nix — theme "${name}".
    LOCK_BG=${lib.removePrefix "#" t.bg}
    LOCK_ACCENT=${lib.removePrefix "#" t.accent}
    LOCK_ACCENT_DIM=${lib.removePrefix "#" t.accentDim}
    LOCK_FG=${lib.removePrefix "#" t.fg}
    LOCK_FG_DIM=${lib.removePrefix "#" t.fgDim}
    LOCK_ERR=${lib.removePrefix "#" t.err}
    LOCK_WARN=${lib.removePrefix "#" t.warn}
  '';

  # The on-screen keyboard's palette, in the same shape and for the same
  # reason: wvkbd takes its colours as command-line flags, so what it can be
  # given is a shell fragment the launcher sources (see ./osk.nix).
  #
  # The names are the keyboard's rather than a stylesheet's. `bg` is the panel
  # the keys sit on, `fg` is the key faces drawn on it, and the `-sp` half of
  # each pair is the special keys — modifiers, Return, the layout switcher.
  # Those take the border colour, which is what separates them from the letters
  # in every palette here.
  #
  # A held key is `accent` with `bg` written on it, which is the pairing
  # themes.nix already uses everywhere an accent serves as a background:
  # waybar's active workspace, wofi's selected row, kitty's selection. The
  # `--text-press` flags are what make it safe to use the light accents — left
  # unset, wvkbd draws a held key's label in its compiled-in white, and the
  # light theme in themes.nix would put that on a near-white key.
  renderWvkbdEnv = name: t: ''
    # Generated from home/joshr/niri/themes.nix — theme "${name}".
    OSK_BG=${lib.removePrefix "#" t.bg}
    OSK_FG=${lib.removePrefix "#" t.bgAlt}
    OSK_FG_SP=${lib.removePrefix "#" t.border}
    OSK_TEXT=${lib.removePrefix "#" t.fg}
    OSK_TEXT_SP=${lib.removePrefix "#" t.fg}
    OSK_PRESS=${lib.removePrefix "#" t.accent}
    OSK_TEXT_PRESS=${lib.removePrefix "#" t.bg}
    OSK_PRESS_SP=${lib.removePrefix "#" t.accentDim}
    OSK_TEXT_PRESS_SP=${lib.removePrefix "#" t.fg}
  '';

  # The lock screen's password field, as a picture of one.
  #
  # Hyprlock cannot change a colour while it is up. `reload_cmd` re-reads a
  # *path*, and there is no equivalent for a colour anywhere in its config —
  # so the only way for the field to follow the music is for its frame to *be*
  # an image, drawn under a field whose own outline and fill are transparent.
  # This is what draws that image, for a theme at build time and for an album
  # cover at lock time (scripts.nix), which is why it lives here as a shell
  # function rather than twice as a command.
  #
  # Every number in it is Hyprlock's, and has to stay Hyprlock's:
  #
  #   624x62      the field is 620x58 and its outline is drawn *outside* that
  #               (PasswordInputField.cpp draws outerBox at pos - thickness,
  #               size + thickness * 2), so its frame is 2px larger all round.
  #   20 and 18   roundingForBorderBox is `rounding + thickness` and
  #               roundingForBox is `rounding`, against the 18 in the config.
  #   dd and d6   the alphas the config used when those colours were static.
  #
  # Punched out and composited rather than stroked over a fill, so the ring and
  # the interior each come out exactly their own colour instead of one showing
  # through the other where they meet.
  lockFieldFrame = ''
    # <edge hex> <fill hex> <output path>
    lock_field_frame() {
      magick -size 624x62 xc:none \
        -fill "#$1dd" -draw 'roundrectangle 0,0 623,61 20,20' \
        \( -size 624x62 xc:none -fill white \
           -draw 'roundrectangle 2,2 621,59 18,18' \) \
        -alpha set -compose DstOut -composite \
        \( -size 624x62 xc:none -fill "#$2d6" \
           -draw 'roundrectangle 2,2 621,59 18,18' \) \
        -compose Over -composite \
        "png32:$3"
    }
  '';

  # sddm-astronaut's themeConfig, so the login screen matches.
  #
  # NOTE: nothing reads this. It is published in `_module.args.niriTheming`
  # below, but modules/nixos/niri.nix — the module that actually builds one
  # themed SDDM package per palette — is a *NixOS* module and cannot see
  # home-manager's args, so it carries its own copy of this function and uses
  # that. Editing the version here changes nothing on screen; the live one is
  # `sddmThemeConfig` in modules/nixos/niri.nix.
  #
  # Kept in step with that copy rather than deleted, so the two don't quietly
  # diverge if the dependency is ever wired up properly.
  sddmThemeConfig = t: {
    FullBlur = "false";
    PartialBlur = "true";
    BlurRadius = "60";
    DimBackground = "0.25";
    CropBackground = "true";

    HeaderText = "Welcome";
    # Qt format strings, not strftime — `h` plus an `AP` field gives a
    # 12-hour clock. Month before day. No comma in the date: SDDM reads theme
    # configs through QSettings, which splits an unquoted comma into a list
    # and loses the month. See the copy in modules/nixos/niri.nix, which is
    # the one the greeter is actually built from.
    HourFormat = "h:mm AP";
    DateFormat = "dddd · MMMM d";
    FormPosition = "center";

    HeaderTextColor = t.accent;
    DateTextColor = t.fg;
    TimeTextColor = t.accent;
    FormBackgroundColor = t.bg;
    BackgroundColor = t.bg;
    DimBackgroundColor = "#000000";
    LoginFieldBackgroundColor = t.bgAlt;
    PasswordFieldBackgroundColor = t.bgAlt;
    LoginFieldTextColor = t.fg;
    PasswordFieldTextColor = t.fg;
    UserIconColor = t.accent;
    PasswordIconColor = t.accent;
    PlaceholderTextColor = t.fgDim;
    WarningColor = t.err;
    LoginButtonTextColor = t.bg;
    LoginButtonBackgroundColor = t.accent;
    SystemButtonsIconsColor = t.accent;
    SessionButtonTextColor = t.fg;
    VirtualKeyboardButtonTextColor = t.fg;
    DropdownTextColor = t.fg;
    DropdownSelectedBackgroundColor = t.accentDim;
    DropdownBackgroundColor = t.bgAlt;
    HighlightTextColor = t.bg;
    HighlightBackgroundColor = t.accent;
    HighlightBorderColor = t.accent;
    HoverUserIconColor = t.fg;
    HoverSystemButtonsIconsColor = t.fg;

    Font = "FiraCode Nerd Font";
    FontSize = "11";
  };

  mkThemeDir =
    name: t:
    pkgs.runCommand "niri-theme-${name}"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        mkdir -p "$out"
        cp ${pkgs.writeText "niri.kdl" (renderNiri name t)}            "$out/niri.kdl"
        cp ${pkgs.writeText "waybar.css" (renderWaybarCss name t)}     "$out/waybar.css"
        cp ${pkgs.writeText "wofi.css" (renderWofiCss name t)}         "$out/wofi.css"
        cp ${pkgs.writeText "wofi-emoji.css" (renderWofiEmojiCss name t)} "$out/wofi-emoji.css"
        cp ${pkgs.writeText "dunstrc" (renderDunstrc name t)}          "$out/dunstrc"
        cp ${pkgs.writeText "swayosd.css" (renderSwayosdCss name t)}   "$out/swayosd.css"
        cp ${pkgs.writeText "swaylock.env" (renderSwaylockEnv name t)} "$out/swaylock.env"
        cp ${pkgs.writeText "wvkbd.env" (renderWvkbdEnv name t)}       "$out/wvkbd.env"
        cp ${pkgs.writeText "kdeglobals" (renderKdeglobals name t)}     "$out/kdeglobals"
        cp ${pkgs.writeText "kitty.conf" (renderKitty name t)}          "$out/kitty.conf"
        cp ${pkgs.writeText "userChrome.css" (renderFirefoxUserChrome name t)}   "$out/firefox-userChrome.css"
        cp ${pkgs.writeText "userContent.css" (renderFirefoxUserContent name t)} "$out/firefox-userContent.css"

        # The lock screen's password field in this theme's colours, for the
        # locks with no music behind them. Built here rather than drawn at lock
        # time so that it costs nothing on the path that has to lock the screen,
        # and so that it follows a theme switch the way every other file in this
        # directory does — by the symlink moving.
        ${lockFieldFrame}
        lock_field_frame \
          ${lib.removePrefix "#" t.accentDim} \
          ${lib.removePrefix "#" t.bg} \
          "$out/lock-field.png"

        # A whole VS Code extension rather than a single file: that is the only
        # shape VS Code will load a colour theme in. See renderVscodeManifest.
        mkdir -p "$out/vscode-extension/themes"
        cp ${pkgs.writeText "package.json" (renderVscodeManifest name t)} \
           "$out/vscode-extension/package.json"
        cp ${pkgs.writeText "niri-color-theme.json" (renderVscodeTheme name t)} \
           "$out/vscode-extension/themes/niri-color-theme.json"

        echo -n "${name}" > "$out/name"
      '';

  themeDirs = lib.mapAttrs mkThemeDir themes;

  # `name) target="/nix/store/..." ;;` arms for the activation script's case.
  themeCaseArms = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (n: d: "      ${n}) target=\"${d}\" ;;") themeDirs
  );
in
{
  _module.args.niriTheming = {
    inherit
      themeSet
      themes
      themeDirs
      stateDir
      activeDir
      sddmThemeConfig
      lockFieldFrame
      ;
    defaultTheme = themeSet.default;
    defaultThemeDir = themeDirs.${themeSet.default};
  };

  # Re-point the symlink at the *current generation's* store path for whichever
  # theme is selected, on every activation.
  #
  # This deliberately does more than seed-if-missing. Each rebuild produces new
  # store paths for the themes, but the symlink would still point into the old
  # generation — so edits to themes.nix (or to any of the renderers above)
  # would appear to do nothing until the theme was switched by hand, and would
  # break outright once the old path was garbage collected.
  #
  # The selected theme *name* is preserved; only the path it resolves to is
  # refreshed. An unknown or missing name falls back to the default.
  #
  # --- and why noctalia gets a different branch --------------------------
  #
  # Under noctalia the palette is not one of these prebuilt directories. The
  # shell renders its own into `noctalia-live` and repoints `active` there
  # itself, from the `colors_changed` and `started` hooks, and writes
  # `noctalia-live` into `current` as the sentinel the system path units wake
  # on.
  #
  # Running the case below on that was actively destructive, and it is the
  # reason Spotify, the greeter and the boot menu drifted. `noctalia-live`
  # matches no arm, so every `home-manager switch` — which is every
  # `nixos-rebuild switch` — fell through to the default: it pulled `active`
  # off the live directory, putting Dolphin and VS Code back on a build-time
  # palette, and it overwrote `current` with a themes.nix name, which is
  # exactly the string the Spotify launcher, the SDDM sync and the limine sync
  # were each keying off. The desktop stayed on the palette noctalia was
  # holding in memory; everything downstream quietly went somewhere else.
  #
  # Those three no longer read `current` at all. This still has to keep its
  # hands off it, because noctalia owns the file and there is nothing here to
  # decide.
  home.activation.linkNiriTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    if useNoctalia then
      ''
        $DRY_RUN_CMD mkdir -p "${stateDir}"

        # Idempotent with what the shell's own hook does, so activation and
        # the hook can run in either order. It may dangle until noctalia has
        # started once on a fresh machine, which costs Dolphin and VS Code
        # their colours for the length of one login and nothing more.
        $DRY_RUN_CMD ln -sfn "${liveDir}" "${activeDir}"
      ''
    else
      ''
        $DRY_RUN_CMD mkdir -p "${stateDir}"

        current="$(cat "${stateDir}/current" 2>/dev/null || true)"
        case "$current" in
${themeCaseArms}
          *) target="${themeDirs.${themeSet.default}}"; current="${themeSet.default}" ;;
        esac

        $DRY_RUN_CMD ln -sfn "$target" "${activeDir}"
        $DRY_RUN_CMD sh -c "printf %s '$current' > '${stateDir}/current'"
      ''
  );
}
