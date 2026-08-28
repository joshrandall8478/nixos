{ config, lib, pkgs, niriTheming, ... }:

# The on-screen keyboard, on `Mod+Shift+K` — and the reason it is here is the
# Steam Controller.
#
# `local.gaming.steamInputOnWayland` (modules/nixos/gaming.nix) gives the pad a
# working *pointer* in this session by preloading extest into Steam, and extest
# replaces the XTEST keyboard entry point as well as the pointer ones — its
# `XTestFakeKeyEvent` emits a real key on the same uinput device the cursor
# comes from. So a Steam layout that binds a button to a key does type here,
# and Steam's own on-screen keyboard does produce keystrokes.
#
# What none of that decides is *where* the keystrokes land. A uinput device is
# a keyboard plugged into the machine, so what it emits goes to whichever
# window the compositor has focused — and Steam's keyboard is itself a window
# in that session. Typing on it therefore only works for as long as that window
# never takes the focus when the pointer arrives on it, which is not something
# this session can promise: `focus-follows-mouse` is on (see ./niri.nix), and a
# window that accepts focus is given it. Every key after that goes to Steam
# rather than to what was being filled in. That is the risk in pointing a real
# Wayland pointer at an X11-era on-screen keyboard, and no setting removes it.
#
# wvkbd is the shape that does work, for two reasons that are both structural:
#
#   * it is a layer-shell surface that asks for no keyboard interactivity at
#     all — `zwlr_layer_surface_v1_set_keyboard_interactivity(…, false)` in its
#     main.c — so it *cannot* take focus off the window underneath it, whatever
#     the pointer does; and
#   * it types through `zwp_virtual_keyboard_v1` rather than XTEST, which niri
#     implements (`VirtualKeyboardManagerState` in niri's src/niri.rs) and
#     which delivers to the focused window by definition.
#
# It also draws on the overlay layer (`ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY`),
# which is above fullscreen windows, so it is usable over Big Picture and over
# a game — which is most of the point of having it.
#
# **Reaching it without a keyboard.** The toggle is an ordinary niri bind, and
# niri binds read real key events, so the way a controller opens this is a
# Steam desktop-layout binding that presses `Super+Shift+K` — XTEST, through
# extest, into the same keyboard the bind is watching. That is also the
# constraint on which chord it can be: extest's virtual device only carries the
# keys Big Picture can bind (`KEYS` in its steam_keys.rs), and a key that is
# not in that table is one the pad cannot press. Super, Shift and K all are.
#
# The keyboard is not started with the session. It is spawned on the key and
# killed on the key, which costs a few milliseconds on each open and buys two
# things: nothing holds a layer surface while nobody is typing, and every open
# reads the palette that is current *now* rather than the one that was current
# at login — wvkbd takes its colours as command-line flags and cannot be
# recoloured while it is up, so a resident keyboard would be the one thing on
# screen still wearing last week's theme.
let
  inherit (niriTheming) activeDir stateDir themes defaultTheme;

  cfg = config.local.niri.onScreenKeyboard;

  # noctalia's palette manifest, spelled the way ./noctalia.nix spells it —
  # the fan-out point the SDDM sync in modules/nixos/niri.nix and the Limine
  # sync in modules/nixos/boot.nix already read their colours out of. It is
  # the only description of a wallpaper-derived or community palette, which is
  # why the colours below go looking for it rather than settling for the
  # generation's idea of the theme.
  resolvedThemeFile = "${stateDir}/noctalia-resolved";

  # The palette of last resort: the default theme, baked in at build time, for
  # a session where neither of the two above has written anything yet.
  fallback = themes.${defaultTheme};

  hex = lib.removePrefix "#";

  # nixpkgs builds wvkbd's `mobintl` layout set and nothing else (`mainProgram`
  # in its package.nix), which is the set that carries the wide `landscape`
  # layouts. That is the pair this session actually uses: wvkbd picks the
  # landscape list whenever the output is wider than it is tall, so on every
  # display here the portrait list below is only ever the fallback.
  oskToggle = pkgs.writeShellApplication {
    name = "osk-toggle";

    runtimeInputs = with pkgs; [
      procps # pkill
      wvkbd
    ];

    text = ''
      # Already up: this key is the "put it away" half. wvkbd can also be told
      # to hide with SIGUSR1 and left resident, which is what its own docs
      # suggest — but a resident keyboard keeps the palette it was started
      # with, and this session's palette changes under it (see ./theming.nix).
      #
      # `pkill -x` matches the process name exactly, so it cannot match this
      # script, and its non-zero "nothing to kill" is the normal path into the
      # rest of the file rather than an error.
      if pkill -x wvkbd-mobintl; then
        exit 0
      fi

      # Colours, from whichever of the two shells is running, in that order of
      # authority.
      #
      # Under the waybar stack the theme directory holds the wvkbd.env
      # theming.nix renders, and sourcing it is the whole answer — same shape
      # as the lock screen's colours in ./scripts.nix. Under noctalia that
      # directory is the shell's own live one and carries no wvkbd.env, but
      # the manifest does exist and is *better* than a rendered file: it
      # follows a wallpaper-derived or community palette, which nothing built
      # into this generation can describe. The `:=` is what puts them in
      # order — a name the sourced file already set is not asked for again.
      read_colour() {
        [ -f "${resolvedThemeFile}" ] || return 0
        sed -n "s/^$1=\(#[0-9A-Fa-f]\{6\}\)$/\1/p" "${resolvedThemeFile}" | head -n1 || true
      }

      # One key of that manifest, without its leading `#` — wvkbd's colour
      # arguments are bare `rrggbb` — or the build-time default if the
      # manifest is missing the key or missing entirely.
      colour() {
        local c
        c="$(read_colour "$1")"
        c="''${c#\#}"
        printf '%s' "''${c:-$2}"
      }

      # shellcheck disable=SC1091
      if [ -r "${activeDir}/wvkbd.env" ]; then
        . "${activeDir}/wvkbd.env"
      fi

      : "''${OSK_BG:=$(colour bg ${hex fallback.bg})}"
      : "''${OSK_FG:=$(colour bg_alt ${hex fallback.bgAlt})}"
      : "''${OSK_FG_SP:=$(colour border ${hex fallback.border})}"
      : "''${OSK_TEXT:=$(colour fg ${hex fallback.fg})}"
      : "''${OSK_TEXT_SP:=$(colour fg ${hex fallback.fg})}"
      : "''${OSK_PRESS:=$(colour accent ${hex fallback.accent})}"
      : "''${OSK_TEXT_PRESS:=$(colour bg ${hex fallback.bg})}"
      : "''${OSK_PRESS_SP:=$(colour accent_dim ${hex fallback.accentDim})}"
      : "''${OSK_TEXT_PRESS_SP:=$(colour fg ${hex fallback.fg})}"

      # Both layer lists are given because wvkbd chooses between them by
      # comparing the output's width and height, and only ever reaches the
      # portrait one on a rotated display. `landscape` is the wide layout the
      # desk wants; the rest of each list is what the ⌨ key in the corner
      # cycles through — symbols, emoji, and a navigation pad that is the only
      # way to reach the arrow keys from here.
      #
      # `--text-press` and its `-sp` partner are not optional decoration: with
      # them unset wvkbd draws a held key's label in its compiled-in white,
      # over a key that this session has just coloured with the theme's accent.
      exec wvkbd-mobintl \
        -H ${toString cfg.height} \
        -L ${toString cfg.height} \
        --fn "Sans 16" \
        -l full,special,emoji,nav \
        --landscape-layers landscape,landscapespecial,emoji,nav \
        --bg "$OSK_BG" \
        --fg "$OSK_FG" \
        --fg-sp "$OSK_FG_SP" \
        --text "$OSK_TEXT" \
        --text-sp "$OSK_TEXT_SP" \
        --press "$OSK_PRESS" \
        --text-press "$OSK_TEXT_PRESS" \
        --press-sp "$OSK_PRESS_SP" \
        --text-press-sp "$OSK_TEXT_PRESS_SP"
    '';
  };
in
{
  home.packages = lib.optional cfg.enable oskToggle;

  # Published unconditionally: ./niri.nix decides whether to write the bind by
  # reading the same option, and a module argument that comes and goes would
  # make that a conditional import instead.
  _module.args.niriOsk = {
    inherit oskToggle;
  };
}
