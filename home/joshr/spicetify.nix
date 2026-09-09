{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

# Port of the existing Spicetify setup from the dotfiles repository.
#
# The Text theme's CSS comes from the dotfiles; its colours come from
# Noctalia, at runtime.
#
# One Spotify, not one per palette
# --------------------------------
# A Spicetify build is immutable — `mkSpicetify` patches Spotify's xpui bundle
# in a derivation, so the colours are baked in. The way that was reconciled
# with a runtime theme switcher was to build *every* palette: fifty-odd
# Spotify packages, and a launcher that read `~/.local/state/niri-theme/current`
# and `exec`d whichever one matched.
#
# Under Noctalia that cannot work, and it did not. The palette can be derived
# from a wallpaper or downloaded from api.noctalia.dev, so there is no Nix
# build for it and the shell writes `noctalia-live` to `current` — a name no
# arm of that case ever matched, so the launcher fell through to the default
# every single time. Spotify was pinned to the palette in themes.nix no matter
# what the desktop was wearing, which is exactly the symptom that prompted
# this.
#
# So: one build, with the live colours mounted into it at launch.
#
#   * Noctalia's `spotify` user template renders the live palette to
#     ~/.local/state/noctalia-spotify/colors.css as `--spice-*` custom
#     properties, on every colour-scheme change (see niri/noctalia.nix).
#   * The launcher gives Spotify a private mount namespace and bind-mounts that
#     file over the `colors.css` Spicetify already linked from xpui/index.html.
#   * theme.js, appended to the Text theme below, polls that same-origin URL and
#     swaps a single <style> element when Noctalia rewrites the file.
#
# There is no loopback server and no Chromium security exception. The earlier
# version crossed from https://xpui.app.spotify.com to 127.0.0.1 and depended
# on Spotify's embedded Chromium accepting PNA/LNA flags. The visible Nord
# palette proved that request never became effective. Mounting the file over
# xpui's own stylesheet keeps both the initial load and the polling fetch on
# Spotify's origin, while the Nix store remains untouched outside this one
# process's namespace.
#
# The Spicetify community template is deliberately disabled. It renders
# ~/.config/spicetify/Themes/{Comfy,Colorful}/color.ini and then runs
# `spicetify apply`, but this profile has neither a runtime Spicetify CLI nor a
# mutable Spotify tree for it to patch. `mkSpicetify` did that work at build
# time in the Nix store; the live CSS route above is what changes its colours.
let
  useNoctalia = config.local.niri.shell == "noctalia";

  themeSet = import ./niri/themes.nix { inherit lib; };
  inherit (themeSet) themes;

  spotifyPaletteDir = "${config.home.homeDirectory}/.local/state/noctalia-spotify";

  stripHash = lib.removePrefix "#";

  renderScheme = name: theme: ''
    [${name}]
    accent             = ${stripHash theme.accent}
    accent-active      = ${stripHash theme.accent}
    accent-inactive    = ${stripHash theme.bgAlt}
    banner             = ${stripHash theme.accent}
    border-active      = ${stripHash theme.accent}
    border-inactive    = ${stripHash theme.border}
    header             = ${stripHash theme.bgAlt}
    highlight          = ${stripHash theme.bgAlt}
    main               = ${stripHash theme.bg}
    notification       = ${stripHash theme.accent}
    notification-error = ${stripHash theme.err}
    subtext            = ${stripHash theme.fgDim}
    text               = ${stripHash theme.fg}
  '';

  # Every palette is still rendered into color.ini, and only one of them is
  # ever selected. That is not waste: Spicetify wants a `[scheme]` section to
  # exist for the name it is built with, and shipping the whole set keeps
  # `colorScheme` below a one-word change rather than a new render. What the
  # scheme actually decides is the two seconds between the window appearing
  # and the live CSS landing on it.
  generatedColorIni = lib.concatStringsSep "\n" (lib.mapAttrsToList renderScheme themes);

  textThemeSource = inputs.dotfiles + "/dot_config/private_spicetify/private_Themes/text";

  textTheme = pkgs.runCommand "spicetify-text-niri" { } ''
    mkdir -p "$out"
    cp -R --no-preserve=mode ${textThemeSource}/. "$out/"
    chmod -R u+w "$out"

    cat > "$out/color.ini" <<'COLOR_INI'
    ${generatedColorIni}
    COLOR_INI

    cat >> "$out/theme.js" <<'THEME_JS'

    // Noctalia derives palettes from a wallpaper or a downloaded community
    // scheme at runtime, long after this immutable theme was built. The
    // launcher mounts the shell's rendered file over xpui/colors.css, which
    // Spicetify already loads with a same-origin <link>. Poll that same URL so
    // an already-open Spotify also follows later palette changes.
    (() => {
      const endpoint = "/colors.css";
      const styleId = "noctalia-live-colors";

      async function syncNoctaliaColors() {
        try {
          const response = await fetch(endpoint, { cache: "no-store" });
          if (!response.ok) return;
          const css = await response.text();
          let style = document.getElementById(styleId);
          if (!style) {
            style = document.createElement("style");
            style.id = styleId;
            document.head.appendChild(style);
          }
          if (style.textContent !== css) style.textContent = css;
        } catch (_) {
          // The static color.ini baked into this theme remains the fallback.
        }
      }

      function start() {
        syncNoctaliaColors();
        setInterval(syncNoctaliaColors, 2000);
      }

      // Spicetify injects this with `defer`, so the head is parsed by now.
      // The guard is for the case where it is loaded some other way.
      if (document.head) {
        start();
      } else {
        document.addEventListener("DOMContentLoaded", start, { once: true });
      }
    })();
    THEME_JS
  '';

  marketplaceSource =
    inputs.dotfiles + "/dot_config/private_spicetify/private_CustomApps/marketplace";

  waveVisualizerArchive =
    inputs.dotfiles + "/dot_config/private_spicetify/private_CustomApps/wave-visualizer.zip";

  waveVisualizer =
    pkgs.runCommand "spicetify-wave-visualizer"
      {
        nativeBuildInputs = with pkgs; [
          coreutils
          findutils
          unzip
        ];
      }
      ''
        mkdir -p "$out"
        temporary="$(mktemp -d)"
        unzip -q ${waveVisualizerArchive} -d "$temporary"

        count="$(find "$temporary" -mindepth 1 -maxdepth 1 -printf x | wc -c)"
        first="$(find "$temporary" -mindepth 1 -maxdepth 1 -print -quit)"

        if [ "$count" -eq 1 ] && [ -d "$first" ]; then
          cp -R "$first"/. "$out/"
        else
          cp -R "$temporary"/. "$out/"
        fi
      '';

  spicedSpotify = inputs.spicetify-nix.lib.mkSpicetify pkgs {
    theme = {
      name = "text";
      src = textTheme;
      injectCss = true;
      injectThemeJs = true;
      replaceColors = true;
      overwriteAssets = false;
    };

    # What the window wears for the moment before theme.js has fetched the
    # live palette, and on a machine where the shell has never run.
    colorScheme = themeSet.default;

    alwaysEnableDevTools = false;
    experimentalFeatures = true;

    enabledCustomApps = [
      {
        name = "marketplace";
        src = marketplaceSource;
      }
      {
        name = "wave-visualizer";
        src = waveVisualizer;
      }
    ];
  };

  # `mkSpicetify` puts the generated stylesheet here and injects a relative
  # `<link href='colors.css'>` into xpui/index.html. Under Noctalia, replace
  # that one file with the live template output in a private mount namespace.
  # `--bind / /` preserves the host filesystem and permissions; this is only a
  # mount view, not a sandbox. A normal bind is deliberately `nodev`, though,
  # so /dev has to be overlaid with a device-enabled bind afterwards. Without
  # that, Spotify reaches /dev/urandom but gets EACCES and aborts before opening
  # a window. The final bind is read-only from Spotify's side and does not
  # mutate the Nix store.
  spotifyLauncher = pkgs.writeShellApplication {
    name = "spotify";
    runtimeInputs = lib.optionals useNoctalia [
      pkgs.bubblewrap
      pkgs.coreutils
    ];
    text = ''
      ${lib.optionalString useNoctalia ''
        palette=${lib.escapeShellArg "${spotifyPaletteDir}/colors.css"}
        target=${lib.escapeShellArg "${spicedSpotify}/share/spotify/Apps/xpui/colors.css"}

        # Noctalia renders its user templates during shell startup. Waiting a
        # few seconds closes the login race without creating mutable state.
        for _ in $(seq 1 50); do
          [ -s "$palette" ] && break
          sleep 0.1
        done

        if [ -s "$palette" ]; then
          exec bwrap \
            --die-with-parent \
            --bind / / \
            --dev-bind /dev /dev \
            --ro-bind "$palette" "$target" \
            -- ${lib.getExe spicedSpotify} "$@"
        fi

        echo "spotify: Noctalia palette missing at $palette; using static fallback" >&2
      ''}
      exec ${lib.getExe spicedSpotify} "$@"
    '';
  };
in
{
  # The launcher carries the immutable Spicetify package in its closure and is
  # the one `spotify` placed on PATH. Under Noctalia it supplies the live
  # colors.css mount above; other shells run the static Spicetify build.
  home.packages = [ spotifyLauncher ];

  # spicedSpotify is no longer installed directly, so publish its desktop entry
  # against the launcher and keep the package's icon.
  xdg.desktopEntries.spotify = {
    name = "Spotify";
    genericName = "Music Player";
    comment = "Listen to music and podcasts";
    exec = "${lib.getExe spotifyLauncher} %U";
    icon = "${spicedSpotify}/share/icons/hicolor/256x256/apps/spotify-client.png";
    terminal = false;
    type = "Application";
    categories = [
      "Audio"
      "Music"
      "Player"
      "AudioVideo"
    ];
    mimeType = [ "x-scheme-handler/spotify" ];
    settings.StartupWMClass = "spotify";
  };

}
