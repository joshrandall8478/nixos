{ lib, ... }:

# Single source of truth for the desktop palette.
#
# Every themed surface — niri's focus ring, waybar, wofi, dunst, swaylock and
# the SDDM login screen — reads its colours from here. A theme is defined once
# and rendered into each tool's own config format by theming.nix.
#
# Keys, all required:
#
#   bg        window / bar background
#   bgAlt     raised surfaces (input fields, menu rows, tray)
#   bgUrgent  background for critical notifications
#   fg        primary text
#   fgDim     secondary text, inactive items
#   accent    the theme colour: active workspace, focus ring, prompt
#   accentDim inactive/unfocused variant of the accent
#   warn      warning text (low battery, cleared password field)
#   err       errors, urgent windows, wrong password
#   border    window and panel borders — usually the same as accentDim
#
#   counterpart
#             the id of the palette to switch to when the light/dark toggle
#             flips. Every palette here names one, and every pair is a
#             round trip: `gruvbox`'s counterpart is `gruvbox-light` and
#             `gruvbox-light`'s is `gruvbox`. Where a family has more than
#             one dark contrast the mapping is deliberately asymmetric —
#             `gruvbox-hard` and `gruvbox-soft` both point at
#             `gruvbox-light`, and it points back at plain `gruvbox`,
#             because a toggle has to pick *one* answer and the medium
#             contrast is the family's canonical dark. Toggling twice from
#             `gruvbox-hard` therefore lands on `gruvbox`, which is the
#             least surprising of the available wrong answers.
#
# Optional:
#
#   ansi      the 16 terminal colours, for kitty. Eight hues plus a bright
#             variant of each: black/red/green/yellow/blue/magenta/cyan/white
#             and brightBlack/brightRed/… Omit it and theming.nix derives one
#             from the roles above, which is legible but flat — the roles have
#             no blue, magenta or cyan in them, so a derived palette has to
#             reuse the accent for all three and syntax highlighting loses
#             most of its distinctions. Themes with a published terminal
#             palette use it verbatim; the rest are hand-picked.
#
# Derived, so nothing here writes it down:
#
#   mode      "light" or "dark", from the luma of `bg`. The switcher uses it
#             to show only the palettes that match the session's current
#             light/dark preference, and theming.nix uses it for the two
#             places a renderer has to know which way round a palette is —
#             Firefox's CSS `color-scheme` and the Papirus icon variant.
#             Computed rather than declared because a declared one can go
#             stale against the colours beside it, and there is no palette
#             here whose bg is anywhere near the threshold: the darkest
#             light palette is gruvbox-light at luma 239 and the lightest
#             dark one is catppuccin-frappé at 53.
#
# Light palettes
# ---------------
# Every family here has one, because the light/dark toggle has to have
# somewhere to go from every palette in the list. They are not the dark ones
# inverted, and two roles in particular have to be thought about again:
#
#   accent    is a *dark* colour, not a bright one, because it still has to
#             take the background colour as text on top of it. A pastel
#             accent on a pale background leaves the active workspace and the
#             selected menu row unreadable.
#
#   accentDim is a *lighter* colour than the accent rather than a darker one.
#             It draws inactive borders and scrollbar thumbs — things whose
#             job is to recede into the page, and a dark border recedes from
#             nothing.
#
# The ANSI bright slots run darker than the normal ones for the same reason
# the accent does: on paper, emphasis is a step towards the ink. That applies
# only where a palette distinguishes the two at all — Rosé Pine Dawn and
# Catppuccin Latte publish one value per hue and both slots take it, and
# Kanagawa Lotus publishes sixteen with its brights running lighter, which is
# upstream's call about its own palette and is kept.
#
# Adding a theme is adding one attrset here — and its counterpart in the
# other mode, so the light/dark toggle has somewhere to go. Nothing else
# needs touching.
let
  # "#rrggbb" -> the channel starting at digit `i`, 0-255. The same two-line
  # parse theming.nix and noctalia-palettes.nix each carry; it is duplicated
  # rather than shared because those two are consumers of this file and a
  # helper module all three imported would be a third file to keep in step.
  hexValue = {
    "0" = 0; "1" = 1; "2" = 2; "3" = 3;
    "4" = 4; "5" = 5; "6" = 6; "7" = 7;
    "8" = 8; "9" = 9; "a" = 10; "b" = 11;
    "c" = 12; "d" = 13; "e" = 14; "f" = 15;
  };
  channel =
    hex: i:
    let
      h = lib.removePrefix "#" hex;
      digit = n: hexValue.${builtins.substring n 1 h};
    in
    digit i * 16 + digit (i + 1);

  # BT.601 luma, 0-255, and the one question it answers. The threshold is the
  # midpoint; see the note on `mode` above for how far every palette here sits
  # from it.
  luma = hex: (299 * (channel hex 0) + 587 * (channel hex 2) + 114 * (channel hex 4)) / 1000;

  modeOf = t: if luma t.bg > 127 then "light" else "dark";

  palettes = {
    # ---- house -----------------------------------------------------------

    # joshrandall.net's colours: dark neutral grey and a pastel green.
    #
    # The green is deliberately soft rather than the phosphor green `matrix`
    # wears. accent is used as a *background* in several places — waybar's
    # active workspace, wofi's selected row, kitty's selection — with `bg` as
    # the text on top of it, so a pastel reads as a calm highlight where a
    # saturated green reads as a highlighter pen.
    #
    # The greys carry no hue on purpose: with one pastel accent, any tint in
    # the background turns the whole session slightly sick-looking. So the
    # bar, the panels and the terminal chrome stay neutral, and the only
    # colours on screen are the green, the warning amber and the error rose
    # — of which only the green is there to be looked at.
    joshrandall-net = {
      description = "joshrandall.net — dark grey and pastel green";
      counterpart = "joshrandall-net-light";
      bg = "#1b1d1c";
      bgAlt = "#262a28";
      bgUrgent = "#33201f";
      fg = "#e4e8e5";
      fgDim = "#8b938e";
      accent = "#a8e6a3";
      accentDim = "#4a6f4a";
      warn = "#e8d9a0";
      err = "#e8a0a0";
      border = "#4a6f4a";
      # The whole ANSI set is pastel, not just the green — a saturated red or
      # blue beside a pastel accent looks like a different theme leaking in.
      # Each hue is a light tint at roughly the accent's lightness, which
      # keeps them distinguishable from each other and legible on the grey.
      ansi = {
        black = "#1b1d1c";       brightBlack = "#4a514d";
        red = "#e8a0a0";         brightRed = "#f2bcbc";
        green = "#a8e6a3";       brightGreen = "#c3f0bf";
        yellow = "#e8d9a0";      brightYellow = "#f2e8bf";
        blue = "#a0c8e8";        brightBlue = "#bfdcf2";
        magenta = "#d4b8e8";     brightMagenta = "#e4d1f2";
        cyan = "#a0e6dc";        brightCyan = "#bff0ea";
        white = "#e4e8e5";       brightWhite = "#f4f7f5";
      };
    };

    # The same two colours the other way up: neutral paper, and a green dark
    # enough to be read as ink rather than as a highlighter.
    #
    # The dark one's pastel #a8e6a3 cannot come across unchanged. It is used
    # as a *background* with the page colour written on top, and a pastel on
    # white leaves the active workspace as pale-on-pale. So the accent goes
    # down to a forest green at roughly the same distance from the background
    # that the pastel is from #1b1d1c, and the greys stay as hueless here as
    # they are there.
    joshrandall-net-light = {
      description = "joshrandall.net — warm white and deep green (light)";
      counterpart = "joshrandall-net";
      bg = "#f5f7f5";
      bgAlt = "#e6eae7";
      bgUrgent = "#f8dedb";
      fg = "#1e211f";
      fgDim = "#616a65";
      accent = "#2f6b36";
      accentDim = "#c3d2c6";
      warn = "#8a6a10";
      err = "#a5312f";
      border = "#c3d2c6";
      ansi = {
        black = "#e6eae7";       brightBlack = "#616a65";
        red = "#a5312f";         brightRed = "#83201f";
        green = "#2f6b36";       brightGreen = "#1f4d25";
        yellow = "#8a6a10";      brightYellow = "#6b520a";
        blue = "#2b5f8f";        brightBlue = "#1c4670";
        magenta = "#7a4382";     brightMagenta = "#5e3165";
        cyan = "#1e6f68";        brightCyan = "#145650";
        white = "#1e211f";       brightWhite = "#0b0d0c";
      };
    };

    # ---- greens ----------------------------------------------------------

    matrix = {
      description = "Phosphor green on black";
      counterpart = "matrix-light";
      bg = "#0a0e0a";
      bgAlt = "#111811";
      bgUrgent = "#2a0f0f";
      fg = "#c8f5c8";
      fgDim = "#5c7a5c";
      accent = "#39ff14";
      accentDim = "#1f8b0d";
      warn = "#f5d76e";
      err = "#ff5555";
      border = "#1f8b0d";
      # Green-forward, but the other six hues stay genuinely distinct — a
      # terminal where magenta is also green makes diffs and syntax
      # highlighting unreadable. The chrome carries the theme; these just
      # have to be legible on near-black.
      ansi = {
        black = "#0a0e0a";       brightBlack = "#2a3a2a";
        red = "#ff5555";         brightRed = "#ff7b7b";
        green = "#39ff14";       brightGreen = "#7dff5e";
        yellow = "#d4e157";      brightYellow = "#e6f58a";
        blue = "#22d3ee";        brightBlue = "#67e8f9";
        magenta = "#b57edc";     brightMagenta = "#cfa3ec";
        cyan = "#2ee6a8";        brightCyan = "#6ff0c6";
        white = "#c8f5c8";       brightWhite = "#eaffea";
      };
    };

    # A phosphor terminal in a lit room rather than a dark one: green ink on
    # a paper that has kept a trace of the tint.
    #
    # #39ff14 has no light-mode equivalent — it is a colour that only exists
    # by glowing — so this does not try to reproduce it. It reproduces the
    # *relationship*: one green carrying every emphasis, on a ground with a
    # breath of the same hue in it, and nothing else on screen competing.
    matrix-light = {
      description = "Green ink on pale phosphor (light)";
      counterpart = "matrix";
      bg = "#eef5ee";
      bgAlt = "#ddebdd";
      bgUrgent = "#f7dcdc";
      fg = "#0d2610";
      fgDim = "#4f6b52";
      accent = "#0b7a1a";
      accentDim = "#bcd9bd";
      warn = "#7a6a12";
      err = "#a32020";
      border = "#bcd9bd";
      ansi = {
        black = "#ddebdd";       brightBlack = "#4f6b52";
        red = "#a32020";         brightRed = "#7d1616";
        green = "#0b7a1a";       brightGreen = "#075c13";
        yellow = "#7a6a12";      brightYellow = "#5e520c";
        blue = "#16637a";        brightBlue = "#0f4a5c";
        magenta = "#6b3a86";     brightMagenta = "#522c68";
        cyan = "#0f6b5c";        brightCyan = "#0a5247";
        white = "#0d2610";       brightWhite = "#041206";
      };
    };

    forest = {
      description = "Deep forest green";
      counterpart = "forest-light";
      bg = "#0b0f0c";
      bgAlt = "#131a15";
      bgUrgent = "#2a0f0f";
      fg = "#cfe8d4";
      fgDim = "#5f7a66";
      accent = "#4ade80";
      accentDim = "#22683c";
      warn = "#e3c07b";
      err = "#e06c75";
      border = "#22683c";
      ansi = {
        black = "#0b0f0c";       brightBlack = "#2b3a2f";
        red = "#e06c75";         brightRed = "#ef8f97";
        green = "#4ade80";       brightGreen = "#86efac";
        yellow = "#e3c07b";      brightYellow = "#f0d5a0";
        blue = "#56b6c2";        brightBlue = "#7fd1db";
        magenta = "#b57edc";     brightMagenta = "#cfa3ec";
        cyan = "#4fd6a8";        brightCyan = "#83e6c6";
        white = "#cfe8d4";       brightWhite = "#eaf6ed";
      };
    };

    forest-light = {
      description = "Forest green on birch (light)";
      counterpart = "forest";
      bg = "#f2f5f0";
      bgAlt = "#e2e9dd";
      bgUrgent = "#f7dedb";
      fg = "#1f2a21";
      fgDim = "#5c6b5f";
      accent = "#256b3f";
      accentDim = "#c3d3c0";
      warn = "#8a6410";
      err = "#a33a3a";
      border = "#c3d3c0";
      ansi = {
        black = "#e2e9dd";       brightBlack = "#5c6b5f";
        red = "#a33a3a";         brightRed = "#822c2c";
        green = "#256b3f";       brightGreen = "#17502d";
        yellow = "#8a6410";      brightYellow = "#6b4d0a";
        blue = "#2a6472";        brightBlue = "#1c4b57";
        magenta = "#75407f";     brightMagenta = "#5b3163";
        cyan = "#1f6f5c";        brightCyan = "#145546";
        white = "#1f2a21";       brightWhite = "#0d130e";
      };
    };

    mint = {
      description = "Cool mint green";
      counterpart = "mint-light";
      bg = "#080d0d";
      bgAlt = "#101a1a";
      bgUrgent = "#2a0f0f";
      fg = "#c4f0e4";
      fgDim = "#578079";
      accent = "#2ee6a8";
      accentDim = "#14806a";
      warn = "#ecd08a";
      err = "#ef6b73";
      border = "#14806a";
      ansi = {
        black = "#080d0d";       brightBlack = "#24393a";
        red = "#ef6b73";         brightRed = "#f79098";
        green = "#2ee6a8";       brightGreen = "#6ff0c6";
        yellow = "#ecd08a";      brightYellow = "#f5e2b4";
        blue = "#4dc4e0";        brightBlue = "#82daee";
        magenta = "#b18ae0";     brightMagenta = "#cbaeed";
        cyan = "#34d3c4";        brightCyan = "#74e5da";
        white = "#c4f0e4";       brightWhite = "#e6faf4";
      };
    };

    mint-light = {
      description = "Cool mint on frost (light)";
      counterpart = "mint";
      bg = "#f0f7f5";
      bgAlt = "#dcece8";
      bgUrgent = "#f7dcdc";
      fg = "#14302b";
      fgDim = "#547069";
      accent = "#0f7a63";
      accentDim = "#bcdcd4";
      warn = "#8a6a10";
      err = "#a5333c";
      border = "#bcdcd4";
      ansi = {
        black = "#dcece8";       brightBlack = "#547069";
        red = "#a5333c";         brightRed = "#83232b";
        green = "#0f7a63";       brightGreen = "#0a5c4a";
        yellow = "#8a6a10";      brightYellow = "#6b520a";
        blue = "#12688a";        brightBlue = "#0d4f69";
        magenta = "#6f3f96";     brightMagenta = "#563075";
        cyan = "#0e7a72";        brightCyan = "#095c56";
        white = "#14302b";       brightWhite = "#071614";
      };
    };

    # Matcha, and the fourth green here, which needs justifying: `matrix` is a
    # glowing green, `forest` a blue-leaning conifer green, `mint` a cold
    # teal-green and `joshrandall-net` a pastel on neutral grey. All four are
    # cool. Matcha is the warm one — a yellow-green, the colour of the powder
    # rather than of a leaf — and it sits on a background that is warm too,
    # an olive-tinted charcoal rather than the neutral or blue-black the other
    # greens use. Beside `forest` the difference is obvious; that is the test
    # a new palette here has to pass.
    #
    # The other hues follow the accent's warmth part of the way but not all
    # of it: the blue and cyan slots are muted, dusty versions rather than
    # saturated ones, so a terminal reads as one palette instead of a warm
    # theme with cold syntax highlighting in the middle of it.
    matcha = {
      description = "Matcha green on roasted charcoal";
      counterpart = "matcha-light";
      bg = "#16180f";
      bgAlt = "#21241a";
      bgUrgent = "#33201a";
      fg = "#e8e6d6";
      fgDim = "#8a8b72";
      accent = "#a3c65a";
      accentDim = "#5c7530";
      warn = "#e0b95c";
      err = "#e07a63";
      border = "#5c7530";
      ansi = {
        black = "#16180f";       brightBlack = "#454833";
        red = "#e07a63";         brightRed = "#ec9c8a";
        green = "#a3c65a";       brightGreen = "#bfda85";
        yellow = "#e0b95c";      brightYellow = "#ecd08c";
        blue = "#6fa8a0";        brightBlue = "#98c5bf";
        magenta = "#b795c4";     brightMagenta = "#cfb5d8";
        cyan = "#7fc09a";        brightCyan = "#a4d4b8";
        white = "#e8e6d6";       brightWhite = "#f6f5ec";
      };
    };

    # The same tea on rice paper. Warm off-white rather than the neutral one
    # `joshrandall-net-light` uses, and a green pulled well down towards
    # olive so it can carry the page colour as text.
    matcha-light = {
      description = "Matcha green on warm rice paper (light)";
      counterpart = "matcha";
      bg = "#f6f4e8";
      bgAlt = "#e9e5d3";
      bgUrgent = "#f5ded0";
      fg = "#2b2d1f";
      fgDim = "#6f7059";
      accent = "#55701f";
      accentDim = "#cfd3ae";
      warn = "#96700f";
      err = "#a8412c";
      border = "#cfd3ae";
      ansi = {
        black = "#e9e5d3";       brightBlack = "#6f7059";
        red = "#a8412c";         brightRed = "#863123";
        green = "#55701f";       brightGreen = "#405417";
        yellow = "#96700f";      brightYellow = "#75570b";
        blue = "#2f6b6b";        brightBlue = "#204c4c";
        magenta = "#7a4780";     brightMagenta = "#5f3764";
        cyan = "#2b7255";        brightCyan = "#1e5540";
        white = "#2b2d1f";       brightWhite = "#15160e";
      };
    };

    # ---- monochrome ------------------------------------------------------

    # No hue anywhere. The accent is plain white, so emphasis comes from
    # contrast rather than colour — the active workspace and focus ring go
    # white-on-black, and the usual green/amber/red for battery and errors
    # become greys. warn and err are kept fractionally lighter than fgDim so
    # a critical notification still reads as louder than a normal one without
    # introducing a colour.
    mono = {
      description = "Monochrome, black and white";
      counterpart = "mono-light";
      bg = "#000000";
      bgAlt = "#141414";
      bgUrgent = "#2b2b2b";
      fg = "#f2f2f2";
      fgDim = "#8a8a8a";
      accent = "#ffffff";
      accentDim = "#4a4a4a";
      warn = "#c8c8c8";
      err = "#ffffff";
      border = "#4a4a4a";
      # No hue in the terminal either, which is the point of the theme — but
      # it costs something real: a red/green diff can only be told apart by
      # lightness. So the eight hues are spread across the grey ramp rather
      # than collapsed onto one value, darkest for red through lightest for
      # white. Distinguishable, just not at a glance.
      ansi = {
        black = "#000000";       brightBlack = "#4a4a4a";
        red = "#6e6e6e";         brightRed = "#9a9a9a";
        green = "#8a8a8a";       brightGreen = "#b0b0b0";
        yellow = "#a0a0a0";      brightYellow = "#c8c8c8";
        blue = "#5c5c5c";        brightBlue = "#8a8a8a";
        magenta = "#787878";     brightMagenta = "#a4a4a4";
        cyan = "#949494";        brightCyan = "#bcbcbc";
        white = "#f2f2f2";       brightWhite = "#ffffff";
      };
    };

    # The inverse: black on white, for bright rooms.
    mono-light = {
      description = "Monochrome, white and black (light)";
      counterpart = "mono";
      bg = "#fafafa";
      bgAlt = "#ebebeb";
      bgUrgent = "#d4d4d4";
      fg = "#0d0d0d";
      fgDim = "#6b6b6b";
      accent = "#000000";
      accentDim = "#b8b8b8";
      warn = "#4a4a4a";
      err = "#000000";
      border = "#b8b8b8";
      # The same ramp inverted: dark text on a light background, so the
      # ordering runs darkest-for-emphasis instead.
      ansi = {
        black = "#0d0d0d";       brightBlack = "#4a4a4a";
        red = "#8a8a8a";         brightRed = "#6e6e6e";
        green = "#6b6b6b";       brightGreen = "#4f4f4f";
        yellow = "#5c5c5c";      brightYellow = "#404040";
        blue = "#9a9a9a";        brightBlue = "#7a7a7a";
        magenta = "#808080";     brightMagenta = "#626262";
        cyan = "#737373";        brightCyan = "#555555";
        white = "#d4d4d4";       brightWhite = "#ebebeb";
      };
    };

    # ---- reds ------------------------------------------------------------

    blackred = {
      description = "Black and red";
      counterpart = "blackred-light";
      bg = "#0d0000";
      bgAlt = "#1a0606";
      bgUrgent = "#3a0a0a";
      fg = "#f0d5d5";
      fgDim = "#7a5555";
      accent = "#ff2b2b";
      accentDim = "#8b0d0d";
      warn = "#f5a623";
      err = "#ff6b6b";
      border = "#8b0d0d";
      ansi = {
        black = "#0d0000";       brightBlack = "#3a1a1a";
        red = "#ff2b2b";         brightRed = "#ff6b6b";
        green = "#6bbf59";       brightGreen = "#8fd97f";
        yellow = "#f5a623";      brightYellow = "#ffc457";
        blue = "#4a90d9";        brightBlue = "#74aee6";
        magenta = "#c678dd";     brightMagenta = "#dda0ec";
        cyan = "#56b6c2";        brightCyan = "#7fd1db";
        white = "#f0d5d5";       brightWhite = "#fdf0f0";
      };
    };

    blackred-light = {
      description = "White and red (light)";
      counterpart = "blackred";
      bg = "#faf5f5";
      bgAlt = "#efe2e2";
      bgUrgent = "#f7d5d5";
      fg = "#1f1414";
      fgDim = "#6b5555";
      accent = "#a80f0f";
      accentDim = "#dfc4c4";
      warn = "#96660c";
      err = "#cc2b2b";
      border = "#dfc4c4";
      ansi = {
        black = "#efe2e2";       brightBlack = "#6b5555";
        red = "#a80f0f";         brightRed = "#820b0b";
        green = "#3f7020";       brightGreen = "#2e5417";
        yellow = "#96660c";      brightYellow = "#755008";
        blue = "#245f96";        brightBlue = "#184672";
        magenta = "#7a3a7f";     brightMagenta = "#5e2c62";
        cyan = "#16706b";        brightCyan = "#0f5450";
        white = "#1f1414";       brightWhite = "#0d0808";
      };
    };

    crimson = {
      description = "Muted crimson on charcoal";
      counterpart = "crimson-light";
      bg = "#14090b";
      bgAlt = "#1f1114";
      bgUrgent = "#3a0f14";
      fg = "#eddcdf";
      fgDim = "#8a6a70";
      accent = "#e0384f";
      accentDim = "#7d1f2c";
      warn = "#e0a458";
      err = "#ff5d6c";
      border = "#7d1f2c";
      ansi = {
        black = "#14090b";       brightBlack = "#3d2429";
        red = "#e0384f";         brightRed = "#ff5d6c";
        green = "#7fb069";       brightGreen = "#9fc98c";
        yellow = "#e0a458";      brightYellow = "#edc186";
        blue = "#5a9ec7";        brightBlue = "#84badb";
        magenta = "#b87eb0";     brightMagenta = "#d0a3ca";
        cyan = "#5fb3b3";        brightCyan = "#88cccc";
        white = "#eddcdf";       brightWhite = "#fbf2f4";
      };
    };

    crimson-light = {
      description = "Muted crimson on bone (light)";
      counterpart = "crimson";
      bg = "#f7f2f3";
      bgAlt = "#ece0e3";
      bgUrgent = "#f5d7db";
      fg = "#241a1d";
      fgDim = "#6f5c62";
      accent = "#a3243a";
      accentDim = "#dcc7cc";
      warn = "#96650f";
      err = "#c43c4c";
      border = "#dcc7cc";
      ansi = {
        black = "#ece0e3";       brightBlack = "#6f5c62";
        red = "#a3243a";         brightRed = "#7f1a2c";
        green = "#4a6f2f";       brightGreen = "#375322";
        yellow = "#96650f";      brightYellow = "#754f0b";
        blue = "#2b5f8a";        brightBlue = "#1d456a";
        magenta = "#7c3f74";     brightMagenta = "#603059";
        cyan = "#1f6d6a";        brightCyan = "#145251";
        white = "#241a1d";       brightWhite = "#100b0d";
      };
    };

    # ---- catppuccin ------------------------------------------------------

    catppuccin-mocha = {
      description = "Catppuccin Mocha";
      counterpart = "catppuccin-latte";
      bg = "#1e1e2e";
      bgAlt = "#313244";
      bgUrgent = "#45213a";
      fg = "#cdd6f4";
      fgDim = "#a6adc8";
      accent = "#cba6f7";
      accentDim = "#6c5a92";
      warn = "#f9e2af";
      err = "#f38ba8";
      border = "#6c5a92";
      # Catppuccin's published terminal palette. Surface1/Surface2 for the
      # blacks, Subtext1/Subtext0 for the whites, and no separate bright
      # variants for the six hues — that's upstream's choice, not an omission.
      ansi = {
        black = "#45475a";       brightBlack = "#585b70";
        red = "#f38ba8";         brightRed = "#f38ba8";
        green = "#a6e3a1";       brightGreen = "#a6e3a1";
        yellow = "#f9e2af";      brightYellow = "#f9e2af";
        blue = "#89b4fa";        brightBlue = "#89b4fa";
        magenta = "#f5c2e7";     brightMagenta = "#f5c2e7";
        cyan = "#94e2d5";        brightCyan = "#94e2d5";
        white = "#bac2de";       brightWhite = "#a6adc8";
      };
    };

    catppuccin-macchiato = {
      description = "Catppuccin Macchiato";
      counterpart = "catppuccin-latte";
      bg = "#24273a";
      bgAlt = "#363a4f";
      bgUrgent = "#4a2436";
      fg = "#cad3f5";
      fgDim = "#a5adcb";
      accent = "#c6a0f6";
      accentDim = "#6b568f";
      warn = "#eed49f";
      err = "#ed8796";
      border = "#6b568f";
      ansi = {
        black = "#494d64";       brightBlack = "#5b6078";
        red = "#ed8796";         brightRed = "#ed8796";
        green = "#a6da95";       brightGreen = "#a6da95";
        yellow = "#eed49f";      brightYellow = "#eed49f";
        blue = "#8aadf4";        brightBlue = "#8aadf4";
        magenta = "#f5bde6";     brightMagenta = "#f5bde6";
        cyan = "#8bd5ca";        brightCyan = "#8bd5ca";
        white = "#b8c0e0";       brightWhite = "#a5adcb";
      };
    };

    catppuccin-frappe = {
      description = "Catppuccin Frappé";
      counterpart = "catppuccin-latte";
      bg = "#303446";
      bgAlt = "#414559";
      bgUrgent = "#4d2c3a";
      fg = "#c6d0f5";
      fgDim = "#a5adce";
      accent = "#ca9ee6";
      accentDim = "#6e567f";
      warn = "#e5c890";
      err = "#e78284";
      border = "#6e567f";
      ansi = {
        black = "#51576d";       brightBlack = "#626880";
        red = "#e78284";         brightRed = "#e78284";
        green = "#a6d189";       brightGreen = "#a6d189";
        yellow = "#e5c890";      brightYellow = "#e5c890";
        blue = "#8caaee";        brightBlue = "#8caaee";
        magenta = "#f4b8e4";     brightMagenta = "#f4b8e4";
        cyan = "#81c8be";        brightCyan = "#81c8be";
        white = "#b5bfe2";       brightWhite = "#a5adce";
      };
    };

    # Latte, Catppuccin's own light flavour and the counterpart all three dark
    # ones toggle to. Mauve for the accent, as they have.
    #
    # `warn` is the one adjustment. Latte's yellow #df8e1d is meant to be read
    # on Base as a highlight, and as warning text it comes out at 2.3:1; it is
    # taken down to #9d6b0c, which is 4.1:1 and the same amber. The published
    # value stays in the terminal's yellow slot.
    catppuccin-latte = {
      description = "Catppuccin Latte (light)";
      counterpart = "catppuccin-mocha";
      bg = "#eff1f5";
      bgAlt = "#ccd0da";
      bgUrgent = "#f2d5dc";
      fg = "#4c4f69";
      fgDim = "#6c6f85";
      accent = "#8839ef";
      accentDim = "#bcc0cc";
      warn = "#9d6b0c";
      err = "#d20f39";
      border = "#bcc0cc";
      # Catppuccin's published Latte terminal palette, and the one light
      # palette here whose "black" is a dark colour rather than a pale tint:
      # upstream fills the two black slots with Subtext1/Subtext0 and the two
      # white slots with Surface2/Surface1, which is the inversion done
      # properly rather than an oversight.
      ansi = {
        black = "#5c5f77";       brightBlack = "#6c6f85";
        red = "#d20f39";         brightRed = "#d20f39";
        green = "#40a02b";       brightGreen = "#40a02b";
        yellow = "#df8e1d";      brightYellow = "#df8e1d";
        blue = "#1e66f5";        brightBlue = "#1e66f5";
        magenta = "#ea76cb";     brightMagenta = "#ea76cb";
        cyan = "#179299";        brightCyan = "#179299";
        white = "#acb0be";       brightWhite = "#bcc0cc";
      };
    };

    # ---- rosé pine -------------------------------------------------------

    rose-pine = {
      description = "Rosé Pine";
      counterpart = "rose-pine-dawn";
      bg = "#191724";
      bgAlt = "#1f1d2e";
      bgUrgent = "#3d1f2c";
      fg = "#e0def4";
      fgDim = "#6e6a86";
      accent = "#c4a7e7";
      accentDim = "#5d4d73";
      warn = "#f6c177";
      err = "#eb6f92";
      border = "#5d4d73";
      # Rosé Pine's own mapping, which is idiosyncratic on purpose: "green"
      # is Pine (a teal-blue) and "cyan" is Rose. Kept as published — the
      # palette is designed as a whole and substituting a literal green
      # breaks it.
      ansi = {
        black = "#26233a";       brightBlack = "#6e6a86";
        red = "#eb6f92";         brightRed = "#eb6f92";
        green = "#31748f";       brightGreen = "#31748f";
        yellow = "#f6c177";      brightYellow = "#f6c177";
        blue = "#9ccfd8";        brightBlue = "#9ccfd8";
        magenta = "#c4a7e7";     brightMagenta = "#c4a7e7";
        cyan = "#ebbcba";        brightCyan = "#ebbcba";
        white = "#e0def4";       brightWhite = "#e0def4";
      };
    };

    rose-pine-moon = {
      description = "Rosé Pine Moon";
      counterpart = "rose-pine-dawn";
      bg = "#232136";
      bgAlt = "#2a273f";
      bgUrgent = "#42233a";
      fg = "#e0def4";
      fgDim = "#6e6a86";
      accent = "#9ccfd8";
      accentDim = "#3e6b73";
      warn = "#f6c177";
      err = "#eb6f92";
      border = "#3e6b73";
      ansi = {
        black = "#393552";       brightBlack = "#6e6a86";
        red = "#eb6f92";         brightRed = "#eb6f92";
        green = "#3e8fb0";       brightGreen = "#3e8fb0";
        yellow = "#f6c177";      brightYellow = "#f6c177";
        blue = "#9ccfd8";        brightBlue = "#9ccfd8";
        magenta = "#c4a7e7";     brightMagenta = "#c4a7e7";
        cyan = "#ea9a97";        brightCyan = "#ea9a97";
        white = "#e0def4";       brightWhite = "#e0def4";
      };
    };

    # Dawn, upstream's light palette, and the counterpart both dark ones
    # toggle to. Its terminal palette carries the same idiosyncrasy Rosé
    # Pine's does — "green" is a pine-teal and "cyan" a rose — and one
    # value per hue, brights included, exactly as published.
    rose-pine-dawn = {
      description = "Rosé Pine Dawn (light)";
      counterpart = "rose-pine";
      bg = "#faf4ed";
      bgAlt = "#fffaf3";
      bgUrgent = "#f2e0e2";
      fg = "#575279";
      fgDim = "#9893a5";
      accent = "#907aa9";
      accentDim = "#c4b8d0";
      warn = "#ea9d34";
      err = "#b4637a";
      border = "#c4b8d0";
      ansi = {
        black = "#f2e9e1";       brightBlack = "#9893a5";
        red = "#b4637a";         brightRed = "#b4637a";
        green = "#286983";       brightGreen = "#286983";
        yellow = "#ea9d34";      brightYellow = "#ea9d34";
        blue = "#56949f";        brightBlue = "#56949f";
        magenta = "#907aa9";     brightMagenta = "#907aa9";
        cyan = "#d7827e";        brightCyan = "#d7827e";
        white = "#575279";       brightWhite = "#575279";
      };
    };

    # ---- classics --------------------------------------------------------

    nord = {
      description = "Nord";
      counterpart = "nord-light";
      bg = "#2e3440";
      bgAlt = "#3b4252";
      bgUrgent = "#4a2f34";
      fg = "#eceff4";
      fgDim = "#7b88a1";
      accent = "#88c0d0";
      accentDim = "#4c6b78";
      warn = "#ebcb8b";
      err = "#bf616a";
      border = "#4c6b78";
      ansi = {
        black = "#3b4252";       brightBlack = "#4c566a";
        red = "#bf616a";         brightRed = "#bf616a";
        green = "#a3be8c";       brightGreen = "#a3be8c";
        yellow = "#ebcb8b";      brightYellow = "#ebcb8b";
        blue = "#81a1c1";        brightBlue = "#81a1c1";
        magenta = "#b48ead";     brightMagenta = "#b48ead";
        cyan = "#88c0d0";        brightCyan = "#8fbcbb";
        white = "#e5e9f0";       brightWhite = "#eceff4";
      };
    };

    # Nord's light half. The palette is published as four groups — Polar
    # Night, Snow Storm, Frost and Aurora — and the dark theme above is Polar
    # Night carrying Frost and Aurora on top of it. This is Snow Storm
    # carrying the same two, which is what upstream intends by shipping the
    # greys in both directions.
    #
    # Except that it cannot be done literally, and that is the interesting
    # part. Frost and Aurora are tuned to sit on Polar Night: nord13 #ebcb8b
    # is a pale sand that reads as a warning against #2e3440 and as nothing
    # at all against #eceff4, and nord11 #bf616a has the same problem one
    # step less badly. So `warn` and `err` here are those two hues taken down
    # to where they carry on paper. The accent is nord10 #5e81ac — the
    # darkest Frost, and the only one of the four that is a candidate at all
    # — taken down one further step to #4c6b8f, which is where it stops being
    # 3.5:1 against the background written on top of it and becomes 4.8:1.
    nord-light = {
      description = "Nord Snow Storm (light)";
      counterpart = "nord";
      bg = "#eceff4";
      bgAlt = "#d8dee9";
      bgUrgent = "#f0d9dc";
      fg = "#2e3440";
      fgDim = "#4c566a";
      accent = "#4c6b8f";
      accentDim = "#c6d0de";
      warn = "#a1690f";
      err = "#a4343d";
      border = "#c6d0de";
      ansi = {
        black = "#d8dee9";       brightBlack = "#4c566a";
        red = "#a4343d";         brightRed = "#83262e";
        green = "#4f7a3a";       brightGreen = "#3c5c2c";
        yellow = "#a1690f";      brightYellow = "#7e510b";
        blue = "#5e81ac";        brightBlue = "#43608a";
        magenta = "#8a5c85";     brightMagenta = "#6c4767";
        cyan = "#3d7a80";        brightCyan = "#2c5c61";
        white = "#2e3440";       brightWhite = "#232833";
      };
    };

    # Gruvbox ships three background contrasts — medium, hard and soft — over
    # one set of hues, plus a light mode. All four are transcribed from
    # morhetz/gruvbox's own palette: dark0_hard #1d2021, dark0 #282828,
    # dark0_soft #32302f and light0 #fbf1c7 for the backgrounds, light1
    # #ebdbb2 for text on the dark ones, gray #928374 for dimmed text, and
    # bright_orange #fe8019 as the accent on all three dark variants.
    gruvbox = {
      description = "Gruvbox dark (medium contrast)";
      counterpart = "gruvbox-light";
      bg = "#282828";
      bgAlt = "#3c3836";
      bgUrgent = "#4a2422";
      fg = "#ebdbb2";
      fgDim = "#928374";
      accent = "#fe8019";
      accentDim = "#8f4a12";
      warn = "#fabd2f";
      err = "#fb4934";
      border = "#8f4a12";
      # Gruvbox is one of the few that genuinely uses its bright variants —
      # the neutral/bright split is core to the palette.
      ansi = {
        black = "#282828";       brightBlack = "#928374";
        red = "#cc241d";         brightRed = "#fb4934";
        green = "#98971a";       brightGreen = "#b8bb26";
        yellow = "#d79921";      brightYellow = "#fabd2f";
        blue = "#458588";        brightBlue = "#83a598";
        magenta = "#b16286";     brightMagenta = "#d3869b";
        cyan = "#689d6a";        brightCyan = "#8ec07c";
        white = "#a89984";       brightWhite = "#ebdbb2";
      };
    };

    # dark0_hard. Same hues, a darker canvas — more contrast under the text
    # and a blacker surround for a bright room or an OLED panel. bgAlt stays
    # at dark1 rather than dropping to dark0: raised surfaces have to stay
    # visibly raised, and #1d2021 against #282828 is a step you can barely
    # see.
    gruvbox-hard = {
      description = "Gruvbox dark (hard contrast)";
      counterpart = "gruvbox-light";
      bg = "#1d2021";
      bgAlt = "#3c3836";
      bgUrgent = "#401f1d";
      fg = "#ebdbb2";
      fgDim = "#928374";
      accent = "#fe8019";
      accentDim = "#8f4a12";
      warn = "#fabd2f";
      err = "#fb4934";
      border = "#8f4a12";
      ansi = {
        black = "#1d2021";       brightBlack = "#928374";
        red = "#cc241d";         brightRed = "#fb4934";
        green = "#98971a";       brightGreen = "#b8bb26";
        yellow = "#d79921";      brightYellow = "#fabd2f";
        blue = "#458588";        brightBlue = "#83a598";
        magenta = "#b16286";     brightMagenta = "#d3869b";
        cyan = "#689d6a";        brightCyan = "#8ec07c";
        white = "#a89984";       brightWhite = "#ebdbb2";
      };
    };

    # dark0_soft, the other direction: a lifted, warmer background for a dim
    # room. Here bgAlt has to go *up* to dark2 for the same reason hard's
    # stays put — dark1 #3c3836 is only a few points off #32302f and raised
    # surfaces would disappear into the background.
    gruvbox-soft = {
      description = "Gruvbox dark (soft contrast)";
      counterpart = "gruvbox-light";
      bg = "#32302f";
      bgAlt = "#504945";
      bgUrgent = "#52322e";
      fg = "#ebdbb2";
      fgDim = "#928374";
      accent = "#fe8019";
      accentDim = "#8f4a12";
      warn = "#fabd2f";
      err = "#fb4934";
      border = "#8f4a12";
      ansi = {
        black = "#32302f";       brightBlack = "#928374";
        red = "#cc241d";         brightRed = "#fb4934";
        green = "#98971a";       brightGreen = "#b8bb26";
        yellow = "#d79921";      brightYellow = "#fabd2f";
        blue = "#458588";        brightBlue = "#83a598";
        magenta = "#b16286";     brightMagenta = "#d3869b";
        cyan = "#689d6a";        brightCyan = "#8ec07c";
        white = "#a89984";       brightWhite = "#ebdbb2";
      };
    };

    # Gruvbox light, kept here with its siblings rather than in the light
    # section below — same reason mono-light sits with mono.
    #
    # Upstream doesn't just invert the dark scheme: light mode swaps the
    # bright hues for the faded ones, because on paper a colour reads as
    # emphasised by getting darker. So the accent is faded_orange #af3a03
    # rather than bright_orange, which is also the only version of it that
    # can carry #fbf1c7 text when the accent is used as a background.
    gruvbox-light = {
      description = "Gruvbox light";
      counterpart = "gruvbox";
      bg = "#fbf1c7";
      bgAlt = "#ebdbb2";
      bgUrgent = "#f0d3c4";
      fg = "#3c3836";
      fgDim = "#7c6f64";
      accent = "#af3a03";
      accentDim = "#d5c4a1";
      warn = "#b57614";
      err = "#9d0006";
      border = "#d5c4a1";
      # Gruvbox's published light terminal palette: neutral_* in the normal
      # slots, faded_* in the bright ones — darker, not lighter, for the same
      # reason the accent is.
      ansi = {
        black = "#fbf1c7";       brightBlack = "#928374";
        red = "#cc241d";         brightRed = "#9d0006";
        green = "#98971a";       brightGreen = "#79740e";
        yellow = "#d79921";      brightYellow = "#b57614";
        blue = "#458588";        brightBlue = "#076678";
        magenta = "#b16286";     brightMagenta = "#8f3f71";
        cyan = "#689d6a";        brightCyan = "#427b58";
        white = "#7c6f64";       brightWhite = "#3c3836";
      };
    };

    dracula = {
      description = "Dracula";
      counterpart = "alucard";
      bg = "#282a36";
      bgAlt = "#44475a";
      bgUrgent = "#4a2436";
      fg = "#f8f8f2";
      fgDim = "#6272a4";
      accent = "#bd93f9";
      accentDim = "#65508c";
      warn = "#f1fa8c";
      err = "#ff5555";
      border = "#65508c";
      ansi = {
        black = "#21222c";       brightBlack = "#6272a4";
        red = "#ff5555";         brightRed = "#ff6e6e";
        green = "#50fa7b";       brightGreen = "#69ff94";
        yellow = "#f1fa8c";      brightYellow = "#ffffa5";
        blue = "#bd93f9";        brightBlue = "#d6acff";
        magenta = "#ff79c6";     brightMagenta = "#ff92df";
        cyan = "#8be9fd";        brightCyan = "#a4ffff";
        white = "#f8f8f2";       brightWhite = "#ffffff";
      };
    };

    # Alucard, which is Dracula's own light theme and not a lightened
    # Dracula — upstream picked new hues for paper rather than inverting the
    # dark ones, so this is a transcription like the rest.
    #
    # One slot is invented. Alucard publishes a cyan (#036a96) and no
    # separate blue, and filling both from the same value would leave a
    # terminal with two identical hues in the middle of it, so the blue slot
    # is hand-picked at the same lightness.
    alucard = {
      description = "Alucard — Dracula's light theme";
      counterpart = "dracula";
      bg = "#fffbeb";
      bgAlt = "#f0ecd8";
      bgUrgent = "#f7dcd8";
      fg = "#1f1f1f";
      fgDim = "#6c664b";
      accent = "#644ac9";
      accentDim = "#cfcfde";
      warn = "#846e15";
      err = "#cb3a2a";
      border = "#cfcfde";
      ansi = {
        black = "#cfcfde";       brightBlack = "#6c664b";
        red = "#cb3a2a";         brightRed = "#a3144d";
        green = "#14710a";       brightGreen = "#0f5507";
        yellow = "#846e15";      brightYellow = "#64530f";
        blue = "#2f5fbd";        brightBlue = "#22468c";
        magenta = "#644ac9";     brightMagenta = "#4c3899";
        cyan = "#036a96";        brightCyan = "#02506f";
        white = "#1f1f1f";       brightWhite = "#0a0a0a";
      };
    };

    # Tokyo Night ships four variants — Night, Storm, Moon and Day — and three
    # of them are here: Night, Storm and Day.
    #
    # This palette used to be almost indistinguishable from `kanagawa`, which
    # is worth writing down because it was not a transcription error. Both
    # were faithful, and both resolved to "an indigo-blue accent on a very
    # dark desaturated violet": Tokyo Night's `blue` #7aa2f7 against
    # Kanagawa's `crystalBlue` #7e9cd8 is four degrees of hue apart, and
    # #1a1b26 against #1f1f28 is a difference you cannot see on a bar. The
    # ten roles are all that reaches the chrome, so two palettes that differ
    # mostly in their *terminal* colours arrive on screen as one palette.
    #
    # What separates them now is the accent and the border, which are the two
    # roles you actually look at. Tokyo Night takes its own `cyan` #7dcfff
    # rather than its blue — the brightest colour in the palette and the one
    # its screenshots are known for — and `blue0` #3d59a1 for the border,
    # which is a saturated indigo where Kanagawa's #435275 is a slate grey
    # with a hint of blue in it. Kanagawa keeps the indigo accent and its warm
    # cream text, which is its own signature. Side by side they now read as a
    # cool theme and a warm one.
    #
    # Going to cyan rather than to Tokyo Night's magenta #bb9af7 was a choice
    # about the rest of the file: five palettes here already wear a lavender
    # accent (Dracula, three Catppuccins, Rosé Pine) and only `abyss` wears a
    # cyan, and abyss's is a saturated teal on a near-black teal ground, which
    # is not this.
    tokyo-night = {
      description = "Tokyo Night";
      counterpart = "tokyo-night-day";
      bg = "#1a1b26";
      bgAlt = "#292e42";
      bgUrgent = "#3d2230";
      fg = "#c0caf5";
      fgDim = "#565f89";
      accent = "#7dcfff";
      accentDim = "#3d59a1";
      warn = "#e0af68";
      err = "#f7768e";
      border = "#3d59a1";
      # Upstream's terminal palette, brights included. The previous version
      # had each bright slot repeating its normal one, which is what the
      # Catppuccin and Rosé Pine blocks above do deliberately — those
      # palettes publish one value per hue. Tokyo Night publishes sixteen.
      ansi = {
        black = "#15161e";       brightBlack = "#414868";
        red = "#f7768e";         brightRed = "#ff899d";
        green = "#9ece6a";       brightGreen = "#9fe044";
        yellow = "#e0af68";      brightYellow = "#faba4a";
        blue = "#7aa2f7";        brightBlue = "#8db0ff";
        magenta = "#bb9af7";     brightMagenta = "#c7a9ff";
        cyan = "#7dcfff";        brightCyan = "#a4daff";
        white = "#a9b1d6";       brightWhite = "#c0caf5";
      };
    };

    # Storm is Night with the background lifted — the same relationship
    # gruvbox-soft has to gruvbox, and it is here for the same reason: an
    # OLED-black surround is not what everyone wants at every hour.
    #
    # bgAlt is the one number that isn't upstream's. Storm publishes
    # `bg_highlight` #292e42, which is six points of luma above its #24283b
    # background — invisible as a raised surface, the same trap the
    # gruvbox-hard note describes. Raised to #363c5a, which is Storm's own
    # hue at a step you can see.
    tokyo-night-storm = {
      description = "Tokyo Night Storm";
      counterpart = "tokyo-night-day";
      bg = "#24283b";
      bgAlt = "#363c5a";
      bgUrgent = "#432a3a";
      fg = "#c0caf5";
      fgDim = "#565f89";
      accent = "#7dcfff";
      accentDim = "#3d59a1";
      warn = "#e0af68";
      err = "#f7768e";
      border = "#3d59a1";
      ansi = {
        black = "#1d202f";       brightBlack = "#414868";
        red = "#f7768e";         brightRed = "#ff899d";
        green = "#9ece6a";       brightGreen = "#9fe044";
        yellow = "#e0af68";      brightYellow = "#faba4a";
        blue = "#7aa2f7";        brightBlue = "#8db0ff";
        magenta = "#bb9af7";     brightMagenta = "#c7a9ff";
        cyan = "#7dcfff";        brightCyan = "#a4daff";
        white = "#a9b1d6";       brightWhite = "#c0caf5";
      };
    };

    # Day, upstream's own light variant, and the counterpart both dark ones
    # toggle to.
    #
    # It follows the two light-palette rules this file uses everywhere (see
    # the note above the light section): the accent is Day's *dark* cyan
    # #007197 rather than its bright blue, so the active workspace can carry
    # the background colour as text on top of it, and `accentDim` is `blue0`
    # #b6bfe2 — a pale tint, because on a light palette accentDim draws the
    # borders that have to recede.
    #
    # `fg` being a blue rather than a grey is Day's, not an accident: the
    # whole palette is built around #3760bf as its ink.
    tokyo-night-day = {
      description = "Tokyo Night Day (light)";
      counterpart = "tokyo-night";
      bg = "#e1e2e7";
      bgAlt = "#d0d5e3";
      bgUrgent = "#f2d5dd";
      fg = "#3760bf";
      fgDim = "#848cb5";
      accent = "#007197";
      accentDim = "#b6bfe2";
      warn = "#8c6c3e";
      err = "#f52a65";
      border = "#b6bfe2";
      # Day's published normals. The bright slots are hand-picked darker
      # rather than taken from upstream, which repeats the normal value in
      # most of them — on paper, emphasis is a step towards the ink.
      ansi = {
        black = "#b4b5b9";       brightBlack = "#a1a6c5";
        red = "#f52a65";         brightRed = "#c64343";
        green = "#587539";       brightGreen = "#40562a";
        yellow = "#8c6c3e";      brightYellow = "#6d5430";
        blue = "#2e7de9";        brightBlue = "#1a5bb8";
        magenta = "#9854f1";     brightMagenta = "#7847bd";
        cyan = "#007197";        brightCyan = "#005a79";
        white = "#6172b0";       brightWhite = "#3760bf";
      };
    };

    everforest = {
      description = "Everforest dark";
      counterpart = "everforest-light";
      bg = "#2d353b";
      bgAlt = "#343f44";
      bgUrgent = "#4a2f2f";
      fg = "#d3c6aa";
      fgDim = "#859289";
      accent = "#a7c080";
      accentDim = "#586c44";
      warn = "#dbbc7f";
      err = "#e67e80";
      border = "#586c44";
      ansi = {
        black = "#414b50";       brightBlack = "#4b565c";
        red = "#e67e80";         brightRed = "#e67e80";
        green = "#a7c080";       brightGreen = "#a7c080";
        yellow = "#dbbc7f";      brightYellow = "#dbbc7f";
        blue = "#7fbbb3";        brightBlue = "#7fbbb3";
        magenta = "#d699b6";     brightMagenta = "#d699b6";
        cyan = "#83c092";        brightCyan = "#83c092";
        white = "#d3c6aa";       brightWhite = "#d3c6aa";
      };
    };

    # Everforest Light, medium contrast, transcribed like its dark sibling.
    #
    # Two roles are departures, both for the reason the header's light-palette
    # note gives: Everforest Light's hues are display colours, chosen to sit
    # *on* bg0 rather than to have bg0 written on top of them.
    #
    # `accent` is green #8da101 taken down to #5f6d00. At upstream's value the
    # active workspace and the selected menu row come out at 2.7:1, which is
    # unreadable; the darker green is 5.3:1 and still unmistakably the same
    # olive. `warn` is yellow #dfa000 down to #a17f00, from near 2:1 to 4.4:1.
    # Both keep their published values in the terminal slots below, where
    # nothing is drawn on top of them.
    #
    # `err` keeps upstream's #f85552 at 3.0:1. It is the lowest-contrast
    # colour in the palette and it stays, because it is the colour Everforest
    # Light is and an error here is a border and a bold foreground rather
    # than body text.
    everforest-light = {
      description = "Everforest light";
      counterpart = "everforest";
      bg = "#fdf6e3";
      bgAlt = "#efebd4";
      bgUrgent = "#f5dcd6";
      fg = "#5c6a72";
      fgDim = "#939f91";
      accent = "#5f6d00";
      accentDim = "#ddd8c0";
      warn = "#a17f00";
      err = "#f85552";
      border = "#ddd8c0";
      ansi = {
        black = "#e0dcc7";       brightBlack = "#939f91";
        red = "#f85552";         brightRed = "#c8433f";
        green = "#8da101";       brightGreen = "#6b7a01";
        yellow = "#dfa000";      brightYellow = "#a17f00";
        blue = "#3a94c5";        brightBlue = "#2b7099";
        magenta = "#df69ba";     brightMagenta = "#b34e93";
        cyan = "#35a77c";        brightCyan = "#27805e";
        white = "#5c6a72";       brightWhite = "#414c52";
      };
    };

    kanagawa = {
      description = "Kanagawa";
      counterpart = "kanagawa-lotus";
      bg = "#1f1f28";
      bgAlt = "#2a2a37";
      bgUrgent = "#43242b";
      fg = "#dcd7ba";
      fgDim = "#727169";
      accent = "#7e9cd8";
      accentDim = "#435275";
      warn = "#e6c384";
      err = "#e82424";
      border = "#435275";
      ansi = {
        black = "#16161d";       brightBlack = "#727169";
        red = "#c34043";         brightRed = "#e82424";
        green = "#76946a";       brightGreen = "#98bb6c";
        yellow = "#c0a36e";      brightYellow = "#e6c384";
        blue = "#7e9cd8";        brightBlue = "#7fb4ca";
        magenta = "#957fb8";     brightMagenta = "#938aa9";
        cyan = "#6a9589";        brightCyan = "#7aa89f";
        white = "#c8c093";       brightWhite = "#dcd7ba";
      };
    };

    # Dragon, Kanagawa's second dark palette: the same ink, desaturated
    # almost to grey. Where Wave above is a cool indigo on sumi black, Dragon
    # is a muted blue-grey on a warmer, flatter black — quieter than anything
    # else here that isn't `mono`.
    kanagawa-dragon = {
      description = "Kanagawa Dragon";
      counterpart = "kanagawa-lotus";
      bg = "#181616";
      bgAlt = "#282727";
      bgUrgent = "#3a2222";
      fg = "#c5c9c5";
      fgDim = "#737268";
      accent = "#8ba4b0";
      accentDim = "#4a5a63";
      warn = "#c4b28a";
      err = "#c4746e";
      border = "#4a5a63";
      ansi = {
        black = "#0d0c0c";       brightBlack = "#625e5a";
        red = "#c4746e";         brightRed = "#e46876";
        green = "#8a9a7b";       brightGreen = "#87a987";
        yellow = "#c4b28a";      brightYellow = "#e6c384";
        blue = "#8ba4b0";        brightBlue = "#7fb4ca";
        magenta = "#a292a3";     brightMagenta = "#938aa9";
        cyan = "#8ea4a2";        brightCyan = "#7aa89f";
        white = "#c8c093";       brightWhite = "#c5c9c5";
      };
    };

    # Lotus, Kanagawa's light palette, and the counterpart both dark ones
    # toggle to. Not a white: lotusWhite3 #f2ecbc is a warm, distinctly
    # yellow paper, which is the whole character of it.
    #
    # It is also the one light palette here whose published bright slots run
    # *lighter* than the normals, against the rule the header sets out — and
    # they are kept that way, because Lotus specifies all sixteen and the
    # ordering is upstream's decision about its own palette.
    kanagawa-lotus = {
      description = "Kanagawa Lotus (light)";
      counterpart = "kanagawa";
      bg = "#f2ecbc";
      bgAlt = "#e5ddb0";
      bgUrgent = "#f0d5c8";
      fg = "#545464";
      fgDim = "#716e61";
      accent = "#4d699b";
      accentDim = "#d5cea3";
      warn = "#836f4a";
      err = "#c84053";
      border = "#d5cea3";
      ansi = {
        black = "#d5cea3";       brightBlack = "#43436c";
        red = "#c84053";         brightRed = "#d7474b";
        green = "#6f894e";       brightGreen = "#6e915f";
        yellow = "#77713f";      brightYellow = "#836f4a";
        blue = "#4d699b";        brightBlue = "#6693bf";
        magenta = "#b35b79";     brightMagenta = "#624c83";
        cyan = "#597b75";        brightCyan = "#5e857a";
        white = "#545464";       brightWhite = "#43436c";
      };
    };

    solarized = {
      description = "Solarized dark";
      counterpart = "solarized-light";
      bg = "#002b36";
      bgAlt = "#073642";
      bgUrgent = "#3d1a1a";
      fg = "#93a1a1";
      fgDim = "#586e75";
      accent = "#268bd2";
      accentDim = "#1a5a87";
      warn = "#b58900";
      err = "#dc322f";
      border = "#1a5a87";
      # Solarized's famous quirk: the bright slots aren't brighter versions of
      # the hues, they're the base greys (base01–base3). Ethan Schoonover
      # designed it that way so the 16 slots carry the full tonal ramp.
      # Transcribed as specified.
      ansi = {
        black = "#073642";       brightBlack = "#002b36";
        red = "#dc322f";         brightRed = "#cb4b16";
        green = "#859900";       brightGreen = "#586e75";
        yellow = "#b58900";      brightYellow = "#657b83";
        blue = "#268bd2";        brightBlue = "#839496";
        magenta = "#d33682";     brightMagenta = "#6c71c4";
        cyan = "#2aa198";        brightCyan = "#93a1a1";
        white = "#eee8d5";       brightWhite = "#fdf6e3";
      };
    };

    # Solarized light, which in Ethan Schoonover's design is not a separate
    # palette at all: the eight accent hues are identical and only the
    # background/foreground ramp is read the other way up. base3 #fdf6e3 for
    # the page, base00 #657b83 for the body text, base1 #93a1a1 for what is
    # dimmed — the exact mirror of base03/base0/base01 in the dark one.
    #
    # Its terminal palette inverts in the same mechanical way, which is why
    # the sixteen slots below are the dark theme's with the four grey ones
    # swapped end for end.
    solarized-light = {
      description = "Solarized light";
      counterpart = "solarized";
      bg = "#fdf6e3";
      bgAlt = "#eee8d5";
      bgUrgent = "#f5dcd2";
      fg = "#657b83";
      fgDim = "#93a1a1";
      accent = "#268bd2";
      accentDim = "#d9d2bd";
      warn = "#b58900";
      err = "#dc322f";
      border = "#d9d2bd";
      ansi = {
        black = "#eee8d5";       brightBlack = "#fdf6e3";
        red = "#dc322f";         brightRed = "#cb4b16";
        green = "#859900";       brightGreen = "#93a1a1";
        yellow = "#b58900";      brightYellow = "#839496";
        blue = "#268bd2";        brightBlue = "#657b83";
        magenta = "#d33682";     brightMagenta = "#6c71c4";
        cyan = "#2aa198";        brightCyan = "#586e75";
        white = "#073642";       brightWhite = "#002b36";
      };
    };

    # ---- originals -------------------------------------------------------
    # Not transcriptions of anything — built here, to the same rules the
    # borrowed palettes are judged by: the accent has to survive being used
    # as a background with `bg` written on top of it, `err` has to be
    # tellable from the accent at a glance (a red battery beside an accented
    # clock), and the sixteen terminal colours have to keep six distinct
    # hues so a diff or a syntax highlighter still reads.

    # Retro-neon: the accent is a magenta rather than the usual blue or
    # green, over a violet-black that isn't quite neutral. The ANSI set keeps
    # the era's other two signature colours — electric cyan and a lime
    # yellow — so a terminal looks of a piece with the chrome.
    synthwave = {
      description = "Neon magenta over midnight violet";
      counterpart = "synthwave-light";
      bg = "#1a1030";
      bgAlt = "#251a45";
      bgUrgent = "#45152e";
      fg = "#f0e6ff";
      fgDim = "#8b7bb8";
      accent = "#ff2f92";
      accentDim = "#8a1350";
      warn = "#ffd166";
      err = "#ff4d6d";
      border = "#8a1350";
      # err (#ff4d6d) sits close to the accent in hue, which is a real risk
      # in a pink-forward theme — so it is held distinctly redder and lighter
      # than accent, and never appears next to it on the same widget.
      ansi = {
        black = "#1a1030";       brightBlack = "#4a3a75";
        red = "#ff4d6d";         brightRed = "#ff7d95";
        green = "#4ee9a1";       brightGreen = "#7ff5c0";
        yellow = "#f9f871";      brightYellow = "#fdfca8";
        blue = "#5b7cfa";        brightBlue = "#8aa0ff";
        magenta = "#ff2f92";     brightMagenta = "#ff6fb5";
        cyan = "#2de2e6";        brightCyan = "#7af4f7";
        white = "#e6dcff";       brightWhite = "#ffffff";
      };
    };

    # Neon does not survive being put on paper, so this does not try. What
    # carries over is the hue and the drama: a magenta pushed to the darkest
    # end it will go while staying unmistakably magenta, on a white with
    # enough violet in it that it reads as a haze rather than as a sheet.
    #
    # The blue is deliberately the loudest of the other seven, because that
    # is the pairing the dark one is built on — magenta and electric blue —
    # and losing it would leave a plain pink theme.
    synthwave-light = {
      description = "Neon magenta on daylight haze (light)";
      counterpart = "synthwave";
      bg = "#f7f2fb";
      bgAlt = "#ebe1f5";
      bgUrgent = "#f7d7e5";
      fg = "#241b33";
      fgDim = "#6d6088";
      accent = "#b3006b";
      accentDim = "#d7c8e8";
      warn = "#8a6a0f";
      err = "#c4304f";
      border = "#d7c8e8";
      ansi = {
        black = "#ebe1f5";       brightBlack = "#6d6088";
        red = "#c4304f";         brightRed = "#9c243d";
        green = "#1f7a56";       brightGreen = "#155c40";
        yellow = "#8a6a0f";      brightYellow = "#6b520b";
        blue = "#2f4fd1";        brightBlue = "#223b9c";
        magenta = "#b3006b";     brightMagenta = "#8a0053";
        cyan = "#0f7f8a";        brightCyan = "#0b5f68";
        white = "#241b33";       brightWhite = "#100b18";
      };
    };

    # Warm without being brown. Gruvbox's orange sits on a warm grey and the
    # whole palette leans sepia; this one puts a golden amber on a properly
    # neutral near-black, so the accent is the only warm thing on screen and
    # reads as a lit coal rather than as a tint over everything.
    ember = {
      description = "Amber embers on cold charcoal";
      counterpart = "ember-light";
      bg = "#131313";
      bgAlt = "#1f1e1d";
      bgUrgent = "#331411";
      fg = "#ece4d9";
      fgDim = "#8a8078";
      accent = "#ffb03a";
      accentDim = "#8a4e0d";
      warn = "#ffd166";
      err = "#ff5c47";
      border = "#8a4e0d";
      # A warm accent means warn and err both crowd it. warn is pulled up
      # into yellow and err down into red, far enough either side of the
      # accent's gold that battery-low and battery-critical never read as the
      # same state.
      ansi = {
        black = "#131313";       brightBlack = "#4a4340";
        red = "#ef4f3a";         brightRed = "#ff7a68";
        green = "#9bbf6a";       brightGreen = "#b9d68f";
        yellow = "#ffb03a";      brightYellow = "#ffca77";
        blue = "#56a3c9";        brightBlue = "#86c2de";
        magenta = "#c38fd6";     brightMagenta = "#d8b3e6";
        cyan = "#57bfae";        brightCyan = "#88d5c8";
        white = "#ece4d9";       brightWhite = "#fbf6f0";
      };
    };

    # The coal put out. Same warm accent hue, taken down to a burnt sienna so
    # it can carry the page colour, on an ash-grey white that stays as close
    # to neutral as the dark one's charcoal does — the point of `ember` is
    # that the warmth is in exactly one place.
    ember-light = {
      description = "Burnt amber on ash (light)";
      counterpart = "ember";
      bg = "#f7f5f2";
      bgAlt = "#e9e5e0";
      bgUrgent = "#f7dccf";
      fg = "#241f1a";
      fgDim = "#6e675f";
      accent = "#a3560a";
      accentDim = "#d9d0c6";
      warn = "#8a6a0f";
      err = "#b03422";
      border = "#d9d0c6";
      ansi = {
        black = "#e9e5e0";       brightBlack = "#6e675f";
        red = "#b03422";         brightRed = "#8c2819";
        green = "#4f7020";       brightGreen = "#3b5417";
        yellow = "#a3700a";      brightYellow = "#7f5607";
        blue = "#26608c";        brightBlue = "#1a476b";
        magenta = "#7a3f80";     brightMagenta = "#5e3063";
        cyan = "#1f6f6a";        brightCyan = "#145350";
        white = "#241f1a";       brightWhite = "#100d0a";
      };
    };

    # Deep water: a blue-black background with one cold, bright cyan on it.
    # The nearest neighbours here are mint (green-teal on near-black) and
    # rose-pine-moon (teal on plum) — this one is bluer than either, and the
    # background carries enough blue to be visibly not-black beside them.
    abyss = {
      description = "Bioluminescent cyan in deep water";
      counterpart = "abyss-light";
      bg = "#06121a";
      bgAlt = "#0d1f2b";
      bgUrgent = "#2c1220";
      fg = "#cfe9f0";
      fgDim = "#5c7f8c";
      accent = "#22d3ee";
      accentDim = "#0e6a80";
      warn = "#ffc857";
      err = "#ff6b81";
      border = "#0e6a80";
      ansi = {
        black = "#06121a";       brightBlack = "#26414d";
        red = "#ff6b81";         brightRed = "#ff97a7";
        green = "#35d6a5";       brightGreen = "#6fe8c4";
        yellow = "#ffc857";      brightYellow = "#ffdb8c";
        blue = "#4aa8ff";        brightBlue = "#86c6ff";
        magenta = "#a78bfa";     brightMagenta = "#c4b0fd";
        cyan = "#22d3ee";        brightCyan = "#67e8f9";
        white = "#cfe9f0";       brightWhite = "#eaf7fb";
      };
    };

    # The same water from above it. A pale blue-white with the cyan taken
    # down to the depth where it can be read as ink; the dark one's #22d3ee
    # is a light source, and there is no light source in a light theme.
    abyss-light = {
      description = "Deep water seen from the surface (light)";
      counterpart = "abyss";
      bg = "#eef5f8";
      bgAlt = "#dbe9ef";
      bgUrgent = "#f5d9dd";
      fg = "#10262e";
      fgDim = "#55707a";
      accent = "#056b82";
      accentDim = "#bcd6e0";
      warn = "#8a6410";
      err = "#a5333f";
      border = "#bcd6e0";
      ansi = {
        black = "#dbe9ef";       brightBlack = "#55707a";
        red = "#a5333f";         brightRed = "#832630";
        green = "#12704f";       brightGreen = "#0d543b";
        yellow = "#8a6410";      brightYellow = "#6b4d0c";
        blue = "#1a5f96";        brightBlue = "#124572";
        magenta = "#5f3f9e";     brightMagenta = "#48307a";
        cyan = "#056b82";        brightCyan = "#035263";
        white = "#10262e";       brightWhite = "#061116";
      };
    };

    # The quiet counterpart to synthwave: the same corner of the wheel at a
    # tenth of the volume, pastel rose on an ink-plum background. Two pinks
    # in one file is deliberate — the file already carries five greens and
    # five purples, and neon and pastel are not interchangeable at 2am.
    sakura = {
      description = "Pastel rose on ink plum";
      counterpart = "sakura-light";
      bg = "#1a141c";
      bgAlt = "#251d29";
      bgUrgent = "#3d1a2a";
      fg = "#f2e4ee";
      fgDim = "#8d7b8d";
      accent = "#f0a8c8";
      accentDim = "#7d4f68";
      warn = "#f0cf9a";
      err = "#f07a8f";
      border = "#7d4f68";
      ansi = {
        black = "#1a141c";       brightBlack = "#4a3b4a";
        red = "#f07a8f";         brightRed = "#f7a3b1";
        green = "#a8d9a0";       brightGreen = "#c4e8be";
        yellow = "#f0cf9a";      brightYellow = "#f7e2c1";
        blue = "#97b8e8";        brightBlue = "#b8d0f2";
        magenta = "#f0a8c8";     brightMagenta = "#f7c6dc";
        cyan = "#96dcd2";        brightCyan = "#b9ebe4";
        white = "#f2e4ee";       brightWhite = "#fdf5fa";
      };
    };

    # Blossom on paper rather than on ink. The one place the pair genuinely
    # differs in character: on the dark palette the rose is the brightest
    # thing on screen, and here it has to be one of the darkest, so it goes
    # to a deep cerise. The background keeps the same trace of pink the dark
    # one keeps of plum.
    sakura-light = {
      description = "Deep rose on blossom paper (light)";
      counterpart = "sakura";
      bg = "#faf3f6";
      bgAlt = "#f0e2ea";
      bgUrgent = "#f7d7dd";
      fg = "#2b1f27";
      fgDim = "#6f5f68";
      accent = "#a3336b";
      accentDim = "#e0cbd6";
      warn = "#8f6710";
      err = "#b83a52";
      border = "#e0cbd6";
      ansi = {
        black = "#f0e2ea";       brightBlack = "#6f5f68";
        red = "#b83a52";         brightRed = "#932c41";
        green = "#40702f";       brightGreen = "#305422";
        yellow = "#8f6710";      brightYellow = "#70500b";
        blue = "#2f5f96";        brightBlue = "#204672";
        magenta = "#a3336b";     brightMagenta = "#7f2853";
        cyan = "#1f6f6a";        brightCyan = "#145350";
        white = "#2b1f27";       brightWhite = "#140e12";
      };
    };

    # ---- sandstone -------------------------------------------------------
    # The only family here that was born light and grew a dark half, rather
    # than the other way round.

    # Warm paper rather than white: an unbleached off-white with a sienna
    # accent, for a bright room. Rosé Pine Dawn is the cool light option and
    # Gruvbox light is the yellow one; this sits between them, warm without
    # gruvbox's cream.
    #
    # accentDim is a tan, not a dark sienna. On a dark theme accentDim is a
    # dimmer version of the accent; on a light one it is a *lighter* one,
    # because it draws inactive borders and scrollbar thumbs — things that
    # have to recede into the page, and a dark border recedes from nothing.
    sandstone = {
      description = "Warm paper and sienna (light)";
      counterpart = "sandstone-dark";
      bg = "#f6f1e7";
      bgAlt = "#ede5d6";
      bgUrgent = "#f2d9cc";
      fg = "#3b3730";
      fgDim = "#7d7466";
      accent = "#b0562a";
      accentDim = "#d3c3a8";
      warn = "#a8730f";
      err = "#a83232";
      border = "#d3c3a8";
      ansi = {
        black = "#e6dcc9";       brightBlack = "#7d7466";
        red = "#a83232";         brightRed = "#8a2020";
        green = "#5d7a2e";       brightGreen = "#47601f";
        yellow = "#a8730f";      brightYellow = "#8a5c07";
        blue = "#2f6f8f";        brightBlue = "#1e5570";
        magenta = "#8a4a72";     brightMagenta = "#6f375a";
        cyan = "#2f7d70";        brightCyan = "#1e6357";
        white = "#3b3730";       brightWhite = "#26231e";
      };
    };

    # The same sienna after dark: the paper becomes a burnt umber, and the
    # accent comes back up to where a warm colour has to sit on a dark
    # ground. It is not `ember` — ember's charcoal is deliberately neutral so
    # the amber is the only warm thing on screen, and this one is warm
    # throughout, which is what makes it the counterpart of a paper palette
    # rather than a second amber-on-black.
    sandstone-dark = {
      description = "Sienna on burnt umber";
      counterpart = "sandstone";
      bg = "#1a1613";
      bgAlt = "#26211c";
      bgUrgent = "#3a1f18";
      fg = "#ede4d5";
      fgDim = "#8d8272";
      accent = "#e08a4f";
      accentDim = "#7a4520";
      warn = "#e0b060";
      err = "#e0705c";
      border = "#7a4520";
      ansi = {
        black = "#1a1613";       brightBlack = "#4a4136";
        red = "#e0705c";         brightRed = "#ec9484";
        green = "#9db861";       brightGreen = "#b9cf8c";
        yellow = "#e0b060";      brightYellow = "#ecc98d";
        blue = "#6ba3bf";        brightBlue = "#97c1d5";
        magenta = "#bf92b8";     brightMagenta = "#d5b4cf";
        cyan = "#6fbfae";        brightCyan = "#99d3c7";
        white = "#ede4d5";       brightWhite = "#fbf6ee";
      };
    };
  };
in
{
  # Applied on a fresh install, and the palette SDDM is built with unless
  # overridden. See MANUAL.md for how the login screen follows runtime
  # switches.
  default = "nord";

  # `mode` is attached here rather than written into each attrset above, so a
  # palette cannot claim to be light while its background says otherwise.
  themes = lib.mapAttrs (_name: t: t // { mode = modeOf t; }) palettes;
}
