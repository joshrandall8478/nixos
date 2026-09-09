{ lib }:

# Renders every palette in ./themes.nix into noctalia's own colour-scheme
# format, one JSON document per theme.
#
# This is the noctalia counterpart of theming.nix. Where that file renders a
# theme nine times — once per tool that needs its own config syntax — noctalia
# needs it exactly once: the shell paints itself from the palette and pushes
# the same colours out to kitty, GTK, Qt and the rest through its template
# system (see the `theme.templates` block in ./noctalia.nix). So themes.nix
# stays the single source of truth and this is the only translation step.
#
# The two colour models
# ---------------------
# themes.nix names colours by the job they do in *this* config — a background,
# a dimmer background, the accent, a dim accent. noctalia names them by
# Material Design 3 roles, which are pairs: every `mX` surface has an `mOnX`
# that is the text drawn on top of it. Ten roles map across directly:
#
#     bg        -> mSurface           bgAlt   -> mSurfaceVariant
#     fg        -> mOnSurface         fgDim   -> mOnSurfaceVariant
#     accent    -> mPrimary           warn    -> mTertiary
#     accentDim -> mSecondary         err     -> mError
#     border    -> mOutline
#
# The `mOn*` halves have no equivalent here, because this config never wrote
# them down: it assumed `bg` was the text on top of `accent`, which is what
# kitty's `selection_foreground` and waybar's active workspace both do. That
# assumption holds on the twenty-nine dark themes and inverts on the
# twenty-two light ones, where `bg` is the pale colour.
# So rather than hard-coding it, `textOn` below picks whichever of the theme's
# own two text colours is further from the surface in question. On a dark
# theme that returns `bg` — the existing behaviour, unchanged — and on a light
# one it returns `fg`, which is the answer the old assumption got wrong.
#
# `bgUrgent` has no noctalia role and is dropped. It existed for dunst's
# critical-notification background; noctalia draws urgent notifications from
# `mError` instead, so nothing is lost but the extra knob.
#
# Both variants are emitted, and they are the same palette
# ------------------------------------------------------
# A noctalia palette carries a `dark` and a `light` variant and the shell
# switches between them with `theme.mode`. A theme *here* is a complete
# palette that is already either light or dark — "gruvbox-light" is the light
# one — and picking it is the whole gesture. Writing the same variant into
# both slots keeps that: whatever mode noctalia is in, the theme you chose is
# the theme you get, rather than a second, hidden axis that could put a light
# theme's colours into dark mode's contrast assumptions.
#
# The cost is that noctalia's own dark/light switch does nothing, and that is
# still the right trade now that there *is* a light/dark switch here. It just
# is not that one. `theme-mode` (../niri/scripts.nix) switches modes by
# switching palettes — to the `counterpart` the current one names in
# themes.nix — so under noctalia it resolves to an ordinary
# `color-scheme-set custom <name>` and nothing about this file has to change.
#
# Filling the two slots with a family's two halves instead was the obvious
# alternative and does not work: `theme-apply` would then have to set
# `theme.mode` as well as the palette, or picking `gruvbox-light` by name
# while the shell sat in dark mode would silently hand back `gruvbox`.
let
  themeSet = import ./themes.nix { inherit lib; };
  inherit (themeSet) themes;

  hexValue = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  };

  # "#rrggbb" -> { r, g, b }, each 0-255. Every colour in themes.nix is six
  # digits with no alpha, which is also all noctalia accepts — it drops a
  # value it cannot parse and lets the role fall back silently, so an eight
  # digit colour would show up as a wrong colour rather than as an error.
  toRgb =
    hex:
    let
      h = lib.removePrefix "#" hex;
      nibble = i: hexValue.${builtins.substring i 1 h};
      byte = i: nibble i * 16 + nibble (i + 1);
    in
    {
      r = byte 0;
      g = byte 2;
      b = byte 4;
    };

  # Relative luminance, 0.0-1.0, on the way to a WCAG contrast ratio.
  #
  # The real sRGB transfer curve is a linear toe below 0.03928 and
  # ((v + 0.055) / 1.055) ^ 2.4 above it, and Nix has no float `pow` to write
  # that with. Squaring is the usual stand-in and it is accurate enough for
  # the one question asked here: across all 51 themes it picks the same winner
  # as the exact curve in 202 of 204 pairs, and both cases it calls
  # differently (gruvbox-light's `warn`, matcha's `accentDim`) still land
  # above 3:1 measured against the exact curve.
  luminance =
    hex:
    let
      c = toRgb hex;
      lin =
        v:
        let
          x = v / 255.0;
        in
        x * x;
    in
    0.2126 * lin c.r + 0.7152 * lin c.g + 0.0722 * lin c.b;

  # WCAG contrast ratio: 1.0 for a colour against itself, 21.0 for black on
  # white. Order of the arguments doesn't matter.
  contrast =
    a: b:
    let
      la = luminance a + 0.05;
      lb = luminance b + 0.05;
    in
    if la >= lb then la / lb else lb / la;

  # The text colour for something drawn on `surface`: whichever of the theme's
  # two text colours is more legible on it. See the header.
  #
  # Contrast ratio rather than a plain brightness comparison, because a
  # saturated mid-tone defeats the simpler test. gruvbox's `err` (#fb4934) has
  # a middling luma, so "pick the one furthest away in brightness" chose the
  # cream `fg` and got 2.51:1; the dark `bg` it should have chosen is 5.9:1.
  # Ranking by contrast directly takes the sub-3:1 pairs across the whole set
  # from seven down to one.
  textOn = t: surface: if contrast t.bg surface >= contrast t.fg surface then t.bg else t.fg;

  # Same fallback as theming.nix's `deriveAnsi`, and it exists for the same
  # reason: every theme in themes.nix defines `ansi`, and a new one that
  # forgets should come out flat rather than fail to evaluate. The roles hold
  # no blue, magenta or cyan, so those three borrow the accent.
  deriveAnsi = t: {
    black = t.bg;
    brightBlack = t.fgDim;
    red = t.err;
    brightRed = t.err;
    green = t.accent;
    brightGreen = t.accent;
    yellow = t.warn;
    brightYellow = t.warn;
    blue = t.accentDim;
    brightBlue = t.accent;
    magenta = t.accentDim;
    brightMagenta = t.accent;
    cyan = t.accentDim;
    brightCyan = t.accent;
    white = t.fg;
    brightWhite = t.fg;
  };

  variant =
    t:
    let
      a = t.ansi or (deriveAnsi t);

      # Computed once: it is the text on the accent in five different places
      # below, and they all have to agree or the accent stops being one thing.
      onAccent = textOn t t.accent;
    in
    {
      mPrimary = t.accent;
      mOnPrimary = onAccent;
      mSecondary = t.accentDim;
      mOnSecondary = textOn t t.accentDim;
      mTertiary = t.warn;
      mOnTertiary = textOn t t.warn;
      mError = t.err;
      mOnError = textOn t t.err;

      mSurface = t.bg;
      mOnSurface = t.fg;
      mSurfaceVariant = t.bgAlt;
      mOnSurfaceVariant = t.fgDim;

      mOutline = t.border;

      # Flat black rather than a tinted shadow. noctalia applies its own alpha
      # from `shell.shadow.alpha`, and the palette format takes no alpha
      # channel of its own — the `#00000070` the niri render uses is written
      # in that config's own syntax and cannot come through here.
      mShadow = "#000000";

      # Hover is the accent, matching the palettes noctalia ships. It is also
      # what this config already did: wofi's selected row and waybar's active
      # workspace are both the accent with `bg` on top.
      mHover = t.accent;
      mOnHover = onAccent;

      terminal = {
        normal = {
          inherit (a)
            black
            red
            green
            yellow
            blue
            magenta
            cyan
            white
            ;
        };
        bright = {
          black = a.brightBlack;
          red = a.brightRed;
          green = a.brightGreen;
          yellow = a.brightYellow;
          blue = a.brightBlue;
          magenta = a.brightMagenta;
          cyan = a.brightCyan;
          white = a.brightWhite;
        };

        # The same six kitty already got from renderKitty in theming.nix, so a
        # terminal looks identical either side of the migration.
        foreground = t.fg;
        background = t.bg;
        selectionBg = t.accent;
        selectionFg = onAccent;
        cursor = t.accent;
        cursorText = onAccent;
      };
    };
in
{
  # Keyed by the theme's id in themes.nix rather than by its `description`.
  # The id is the name the switcher already speaks — `theme-apply gruvbox` —
  # and it becomes the palette's filename, which is what noctalia shows in
  # Settings and what `noctalia msg color-scheme-set custom <name>` takes.
  # Keeping them the same string is what lets the keybinds stay one-liners.
  palettes = lib.mapAttrs (_name: t: {
    dark = variant t;
    light = variant t;
  }) themes;

  inherit (themeSet) default;
}
