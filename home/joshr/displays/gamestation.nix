{ ... }:

# Display layout for the desk.
#
# This is the file to edit when a monitor changes — nothing else in here
# depends on it. Imported by home/joshr/gamestation-niri.nix.
#
# Get connector names and the modes each display actually reports with:
#
#     niri msg outputs
#
# The refresh rates are stated explicitly because a display's preferred mode
# is frequently not its fastest; without them you can silently end up at
# 60Hz. The string has to match a mode the display reports, or niri falls
# back to the preferred mode and only logs a warning.
#
# Positions are in *logical* pixels, so a scaled output occupies
# width / scale. DP-2 starts at x=2560 because DP-3 is unscaled — if DP-3
# ever gets a scale, that number becomes 2560 / scale.
{
  # Numbered workspaces (Mod+1..5) all live on the 1440p panel. Without this
  # niri creates each one on whichever output was focused at the time, so
  # they end up scattered across both displays.
  local.niri.workspaceOutput = "DP-3";

  local.niri.outputs = [
    {
      name = "DP-3";
      mode = "2560x1440@179.952";
      position = {
        x = 0;
        y = 0;
      };

      # VRR, but only while a game is on this display.
      #
      # A fixed 180Hz panel can only show a frame for a whole multiple of
      # 5.6ms, so a frame that took 7ms to render is held for 11.2 and the
      # judder you see is the display rather than the game. VRR removes that
      # by making the panel wait for the frame instead.
      #
      # "on-demand" rather than `true` so the desktop keeps its fixed rate:
      # the output only switches while a window carrying the
      # `variable-refresh-rate` window rule is on it, and the only rule that
      # sets it is the games one in home/joshr/niri/niri.nix. That keeps the
      # panel out of the case where its refresh rate tracks how much the
      # shell happens to be animating, which on some displays shows up as
      # brightness flicker in dark areas.
      #
      # If this panel turns out not to support adaptive sync, nothing here
      # breaks — niri logs it and leaves the output fixed. `niri msg outputs`
      # says which it actually did. Set it to `false` to take it out
      # entirely, or `true` to hold VRR on for the desktop as well.
      variableRefreshRate = "on-demand";

      # niri has no "primary" display; this is the nearest equivalent — the
      # session starts focused here. To also pin workspaces to this output,
      # give them an `open-on-output` in the workspace declarations in
      # home/joshr/niri/niri.nix.
      focusAtStartup = true;
    }
    {
      name = "DP-2";
      mode = "1920x1080@100.000";
      # Top-aligned with DP-3 rather than centred against it. Set y = 180 to
      # centre the 1080p panel against the 1440p one instead.
      position = {
        x = 2560;
        y = 0;
      };
    }
  ];
}
