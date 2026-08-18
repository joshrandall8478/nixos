{ lib, ... }:

# Small set of shape options so the hosts — and joshr vs root — can share the
# same home modules. Declared separately from the modules that consume them so
# those don't have to split into options/config blocks.
{
  options.local.shell.fastfetchGreeting = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether fish's greeting runs fastfetch.

      Mirrors the username branch in the dotfiles' config.fish.tmpl: root gets
      an empty greeting, everyone else gets the fastfetch one. Also controls
      whether fastfetch and ~/.smallfetch.jsonc are installed at all.
    '';
  };


  options.local.niri.shell = lib.mkOption {
    type = lib.types.enum [
      "waybar"
      "noctalia"
    ];
    default = "noctalia";
    description = ''
      Which desktop shell the niri session runs.

      "waybar" is the assembled stack: waybar, dunst, swayosd, wofi, cliphist,
      swayidle and hyprlock, each configured by its own module under
      home/joshr/niri/ and themed by theming.nix rendering themes.nix into
      seven different config formats.

      "noctalia" replaces all seven with one Quickshell process reading one
      TOML file — home/joshr/niri/noctalia.nix — which disables the daemons it
      subsumes. themes.nix stays the source of colour either way: the palettes
      are rendered into noctalia's own format by noctalia-palettes.nix, and
      `theme-apply` remains the switcher, so kitty, Dolphin and VS Code follow
      a theme change exactly as they do under waybar.

      Not everything survives the crossing, and both losses are indicators
      that were rarely on screen: the gamemode pad has no noctalia widget
      (its waybar module was a polled script, and custom_button has no exec),
      and the lock screen loses the album art, media buttons, battery readout
      and greetings that `lock-session` builds hyprlock configs for. The
      `local.niri.lock*` options are therefore only read under "waybar".
    '';
  };

  options.local.niri.noctaliaSourcePatches = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to build Noctalia with this repository's C++ extras: animated
      lock/unlock transitions, content-sized text OSDs, the customized
      control-panel identity and detail colours, and a `shadow_offset` setting
      on the clock widget so a small one can carry a shadow that is visible at
      its size, plus the relative MPRIS IPC actions retained for compatibility.

      Enabling this changes the Noctalia derivation and therefore compiles it
      locally instead of using the binary from cache.nixos.org. Disabling it
      keeps the complete generated Noctalia configuration, palettes, plugins,
      templates and theme-sync hooks, but uses stock pkgs.noctalia and its
      upstream behaviour for those source-only features.
    '';
  };

  options.local.waybar.cavaInBar = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether the bar carries an audio visualiser.

      Named for waybar because that is where it started, and still read by
      both shells — it answers the same question either way. Under waybar it
      adds the `custom/cava` module, a script feeding the bar one frame of
      glyphs per line (cavaBar in home/joshr/niri/scripts.nix); under noctalia
      it adds the compact bar widget, which reads PipeWire directly and needs
      no helper.

      The lock screen's visualizer used to ride on this same option and is now
      `local.niri.cavaInLockscreen`. They were split because they are not one
      decision: eight bars beside the clock is a detail of the bar, and a
      spectrum across the whole display behind the login prompt is what the
      machine looks like while it is locked. Wanting one is no reason to want
      the other, in either direction.
    '';
  };

  options.local.niri.cavaInLockscreen = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether Noctalia's lock screen carries a full-output audio visualiser.

      It is the backmost lock widget, its box the entire logical output with
      no panel or padding behind it, drawn from the PipeWire stream rather
      than by cava. `show_when_idle = false` fades it away when playback
      stops, so a locked machine with nothing playing shows the plain
      wallpaper — which is why this can default on without the screen looking
      busy.

      Only read under `local.niri.shell = "noctalia"`, and the mirror image of
      the `local.niri.lock*` options in that respect: hyprlock, the screen the
      waybar stack builds, has no visualiser widget for this to turn on.
    '';
  };

  options.local.niri.randomLockGreetings = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether Hyprlock chooses a randomized, time-aware greeting each time the
      niri session locks. When disabled, it always shows the ordinary
      "Welcome, <first name>" greeting.
    '';
  };

  options.local.niri.timeBasedLockGreetings = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Gives time based greetings: "Good {Morning, Afternoon, Evening}, <first name>".
    '';
  };

  options.local.niri.lockAlbumArtBackground = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether Hyprlock replaces the wallpaper with a blurred version of the
      current track's album art. When disabled, the selected wallpaper stays
      behind the lock screen while its other media widgets keep working.
    '';
  };

  options.local.niri.lockAlbumArtCover = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether Hyprlock shows the current track's album cover above the now
      playing label. This is independent of the album-art background.
    '';
  };

  options.local.niri.lockBatteryIndicator = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether Hyprlock shows the battery charge in the bottom-right corner of
      the lock screen.

      On by default, and safe to leave on everywhere: the battery has to be
      found before it can be drawn. `lock-session` looks for a system battery
      each time it writes the config and leaves the widget out of the file
      entirely when the machine hasn't got one, so a desk draws nothing here
      whatever this is set to — which is also why there is no per-host `false`
      for the machines without a battery. Turning it off is for a laptop whose
      corner you would rather have empty.
    '';
  };

  # Per-host display layout for niri. Rendered into `output` blocks in
  # config.kdl by home/joshr/niri/niri.nix.
  #
  # Leave empty to let niri auto-detect, which is right for a laptop whose
  # external displays change. Set it where the layout is fixed and you care
  # about the exact mode — a monitor's advertised preferred mode is often not
  # its highest refresh rate.
  options.local.niri.outputs = lib.mkOption {
    default = [ ];
    description = "niri output configuration, one entry per display.";
    example = lib.literalExpression ''
      [
        {
          name = "DP-3";
          mode = "2560x1440@180.000";
          position = { x = 0; y = 0; };
          focusAtStartup = true;
        }
      ]
    '';
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = ''
              Connector name, e.g. "DP-3" or "eDP-1". `niri msg outputs` lists
              them along with every mode each display actually supports.
            '';
          };

          mode = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "2560x1440@180.000";
            description = ''
              `WIDTHxHEIGHT@REFRESH`. The refresh rate is optional but worth
              being explicit about, and it must match a mode the display
              reports — niri falls back to the preferred mode and logs a
              warning if it doesn't. Copy it verbatim from `niri msg outputs`.
            '';
          };

          position = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  x = lib.mkOption { type = lib.types.int; };
                  y = lib.mkOption { type = lib.types.int; };
                };
              }
            );
            default = null;
            description = ''
              Top-left corner in the global logical coordinate space. These
              are logical pixels, so a scaled display occupies
              width / scale — lay the next one out from there, not from its
              physical width.
            '';
          };

          scale = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            example = 2;
            description = ''
              Integer scale factor. Omit for 1.

              Fractional scales are deliberately not accepted. A client that
              does not implement wp-fractional-scale-v1 — which is most of
              XWayland, and a fair number of toolkits under it — is rendered
              at the next integer up and then bilinearly downscaled by the
              compositor, so text on it is soft in a way no font setting
              fixes. Integer scales have no such path: every client is either
              scaled exactly or left alone. A null here is rendered as an
              explicit `scale 1` rather than left out, so niri's own
              guess-from-DPI (which can land on a fractional value) never
              gets to choose.
            '';
          };

          transform = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "90";
            description = ''Rotation: "90", "180", "270", "flipped", etc.'';
          };

          variableRefreshRate = lib.mkOption {
            type = lib.types.enum [
              false
              true
              "on-demand"
            ];
            default = false;
            example = "on-demand";
            description = ''
              VRR / adaptive sync on this output — FreeSync, G-Sync, or
              whatever the panel calls it.

              With VRR the display waits for the frame instead of the frame
              waiting for the display, which is the difference between a game
              whose frame rate wanders and a game that visibly judders while
              it does. A fixed 180 Hz panel shows each frame for a whole
              multiple of 5.6ms, so a frame that took 7ms is shown for 11.2
              and the hitch is the *display*, not the game. That is the
              stutter this removes, and it is the only kind it removes:
              nothing here helps a frame that took 40ms to render.

              `"on-demand"` is the setting worth having, and it is not a
              weaker version of `true`. It leaves the output at its fixed
              rate for the desktop and turns VRR on only while a window
              carrying the `variable-refresh-rate` window rule is displayed
              on it — the games rule in home/joshr/niri/niri.nix. That
              matters because a desktop under VRR is a display whose refresh
              rate tracks how much the shell happens to be animating, which
              on some panels is visible as brightness flicker in dark areas,
              and because it is the one setting that cannot make anything
              worse when nobody is playing anything.

              `true` holds VRR on permanently, which is what to use if the
              panel is well behaved and you would rather not think about it.

              A panel that doesn't support VRR takes any of these and stays
              fixed; niri logs it and carries on. `niri msg outputs` says
              which mode is actually in use.
            '';
          };

          focusAtStartup = lib.mkEnableOption ''
            starting the session focused on this output.

            niri has no "primary display" concept, so this is the closest
            equivalent. To also pin workspaces to a display, give them an
            `open-on-output` in the workspace declarations
          '';

          off = lib.mkEnableOption "disabling this output entirely";
        };
      }
    );
  };

  options.local.niri.lockClockOutputs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "eDP-1" ];
    description = ''
      Connectors that get a clock on noctalia's lock screen, for hosts that
      do not pin their display layout.

      Only consulted when `local.niri.outputs` is empty. noctalia places lock
      screen widgets by pixel coordinate per output, so the clock's position
      is normally computed from the mode already declared there — one place
      for the resolution, and a monitor change moves the clock with it. A host
      that leaves the layout to niri's auto-detection has no mode to read, so
      this names the connectors instead and the position falls back to a 1080p
      centre. noctalia clamps widget coordinates to the output, so on a panel
      that is not 1080p the clock is off-centre rather than off-screen.

      `niri msg outputs` prints the connector names. Only read under
      `local.niri.shell = "noctalia"`; the hyprlock screen the waybar stack
      uses draws its own clock and needs none of this.
    '';
  };

  options.local.niri.brightness.device = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "ddcci5";
    description = ''
      Backlight device that speaks for "the display" — the one the bar's
      brightness reading and the OSD both report. The keys still drive every
      display; this only decides which one is *quoted*.

      Nothing picks that consistently on its own, which is the reason this
      exists. waybar's backlight module, given no device, takes the one with
      the highest `max_brightness` and breaks ties in udev enumeration order;
      the `brightness` helper takes whichever sorts first in
      /sys/class/backlight. On a laptop those are the same single panel. On a
      desk with one `ddcci*` device per monitor they are two different numbers
      about two different screens, neither of them necessarily the monitor in
      front of you.

      null leaves that as it was — right for a machine with one panel, and for
      one where you haven't decided yet. A name that matches no device falls
      back to the same place, with a warning on stderr from the helper.

      Find the name by asking each device which monitor it is. `idModel` and
      `idSerial` come from the ddcci device the backlight sits on:

          for d in /sys/class/backlight/*; do
            printf '%s\t%s\t%s\n' "''${d##*/}" \
              "$(cat "$d/device/idModel" 2>/dev/null)" \
              "$(cat "$d/device/idSerial" 2>/dev/null)"
          done

      Note that a `ddcci*` name is its i2c adapter number
      (`ddcci<adapter>`), so it follows the bus the monitor is on rather than
      the monitor. Moving a cable to a different port can renumber it.
    '';
  };

  options.local.niri.workspaceOutput = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "DP-3";
    description = ''
      Output the named workspaces open on, as an `open-on-output` on each
      `workspace` declaration.

      niri creates a workspace on whichever output is focused at the time, so
      without this the numbered workspaces land wherever you happened to be —
      the Mod+<n> binds end up scattered across displays. Naming an output
      pins them all to it.

      null leaves them unpinned, which is what a single-display machine
      wants.
    '';
  };

  options.local.niri.screenshotFreeze = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether region capture freezes the screen while the selection is drawn,
      the way Spectacle and Flameshot do.

      It reaches whichever shell is capturing. Under noctalia it is
      `shell.screenshot.freeze_screen`, and the still frame is the selection
      overlay itself. Under waybar it is the `screenshot` helper putting
      wayfreeze up first — a still copy of every output, painted back over the
      session as an overlay layer surface — with slurp selecting on top of
      that.

      Either way, what you framed is what gets captured, because nothing
      underneath it can move in between: a video keeps the frame you picked,
      an animation stops mid-flight, and a menu that would close the moment it
      lost focus is still open.

      Off, the selection happens over the live screen, which is what this did
      before. That is the setting to fall back to if a niri or wayfreeze
      update breaks the stacking the waybar freeze depends on — slurp has to
      map after the freeze to be above it, and a slurp underneath it would
      send the first click to the wrong surface. `screenshot last` re-shoots
      without a selection and so never freezes either way.
    '';
  };

  options.local.niri.screenshotEditor = lib.mkOption {
    type = lib.types.enum [
      "satty"
      "spectacle"
    ];
    default = "satty";
    description = ''
      Which annotation editor a capture lands in — arrows, boxes, blur, text —
      before it is saved.

      This is the noctalia session's setting. noctalia captures and then hands
      the PNG to one command, and `screenshot-annotate` (home/joshr/niri) is
      that command; the waybar `screenshot` helper is always satty.

      `"satty"` is the Wayland-native one and the reason region capture was
      ever a script: it reads the image on stdin, writes exactly where it is
      told, copies to the clipboard on save, and exits when it is done, so a
      capture is one gesture from Print to a file on disk.

      `"spectacle"` is KDE's, and worth having on the hosts that already run
      Plasma and know its editor. It cannot read stdin or be told to exit, so
      the shot is written to its destination first and spectacle opens on that
      file — meaning the unannotated capture is already saved and spectacle's
      own Save is what overwrites it. On a host with no other KDE application
      it also pulls a large chunk of the Plasma runtime into the session's
      closure, which is why this is not the default.
    '';
  };

  # OpenRGB's options are not here. `local.openrgb.autostart`, `.profile` and
  # `.applyOnResume` are declared on the NixOS side (modules/nixos/options.nix)
  # and read from this side through `osConfig`, because the session isn't the
  # only thing that uses them: the daemon and the after-resume re-apply are
  # system services (modules/nixos/openrgb.nix), and a profile name that the
  # session and the resume service disagreed about would be a bug nobody would
  # notice until a suspend.

  # wallhaven.cc's toplist, downloaded into
  # ~/.local/share/wallpapers/WallhavenFlake from the `wallhaven-toplist`
  # flake input. See home/joshr/wallhaven.nix.
  options.local.wallhaven.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Keep ~/.local/share/wallpapers/WallhavenFlake in sync with the
      `wallhaven-toplist` flake input.

      Only reaches machines that import home/joshr/wallhaven.nix, which is
      the desktop base — the server and root have no wallpapers at all. Turn
      it off and the directory is simply left where it stands: nothing
      removes it, because nothing runs. `rm -r` it yourself if you want it
      gone.
    '';
  };

  options.local.wallhaven.count = lib.mkOption {
    type = lib.types.ints.between 1 24;
    default = 20;
    description = ''
      How many of the listing's wallpapers to keep — the 20 in "top 20".

      The ceiling is a page of wallhaven's API, which holds 24 results and is
      what the input asks for. Lowering this deletes the surplus on the next
      switch, same as the toplist moving on would.
    '';
  };

  options.local.wallhaven.timeout = lib.mkOption {
    type = lib.types.ints.positive;
    default = 600;
    description = ''
      Seconds the download run may take before it gives up and leaves the
      rest for next time.

      This exists because the run happens inside `nixos-rebuild switch`. A
      network that drops packets rather than refusing connections would
      otherwise let twenty files' worth of timeouts and retries stack up into
      a rebuild that looks hung. Nothing is lost when the budget runs out:
      what did download stays, nothing is deleted, and the next activation or
      login picks up where this one stopped.
    '';
  };

  options.local.plasma.secondaryMonitorPanel = lib.mkEnableOption ''
    the status bar on the second monitor (screen 1).

    On the desk this is the top bar carrying the pager, window list, clock,
    media controls and volume. A single-screen machine has nothing to put it
    on — Plasma would place it on the only display, on top of the panels
    already there
  '';
}
