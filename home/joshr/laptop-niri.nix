{ lib, niriScripts, ... }:

# joshr's home profile on the laptop, niri session.
#
# niri's per-monitor behaviour is driven by the outputs actually present
# rather than by hardcoded screen indices, so unlike the Plasma variant there
# is nothing single-display to switch off here.
#
# The display layout lives in ./displays/laptop.nix.
{
  imports = [
    ./home.nix
    ./airpods-media-controls.nix
    ./niri
    ./niri/privacy.nix
    ./displays/laptop.nix
    ./desktop-apps.nix
    ./office.nix
    ./kitty.nix
    ./ranger.nix
    ./vscode.nix
    ./spicetify.nix
    ./firefox.nix
    ./browser.nix
    #./wallhaven.nix
    ./emu-hackathon.nix
    ./image-editing.nix
  ];

  # noctalia rather than the waybar stack — see the same line in
  # ./gamestation-niri.nix, and `local.niri.shell` in home/common/options.nix.
  local.niri.shell = "noctalia";

  # Keep the generated Noctalia configuration, palettes, plugins and theme
  # syncing, but use the stock cache.nixos.org binary on the laptop. The C++
  # extras remain enabled by default on the desk, where compiling the custom
  # derivation is intentional.
  local.niri.noctaliaSourcePatches = true;

  # The two visualizers under Noctalia, one option each — the bar's compact
  # widget and the lock screen's full-output spectrum. Both default on, and
  # both are written down here anyway: they used to be a single option, so an
  # unqualified "cava is on for the laptop" no longer says which screen.
  local.waybar.cavaInBar = true;
  local.niri.cavaInLockscreen = true;

  # The lock screen's clock is placed by pixel coordinate per output, and this
  # host deliberately declares no `local.niri.outputs` (./displays/laptop.nix
  # leaves the layout to niri, because a laptop's external displays change).
  # So the connector is named here instead. eDP-1 is the internal panel;
  # `niri msg outputs` confirms it, and the position falls back to a 1080p
  # centre that noctalia clamps onto whatever the panel actually is.
  local.niri.lockClockOutputs = [ "eDP-1" ];

  local.niri.randomLockGreetings = false;
  local.niri.timeBasedLockGreetings = true;

  local.niri.lockAlbumArtBackground = false;
  local.niri.lockAlbumArtCover = true;

  # The charge in the bottom-right corner of the lock screen. On by default
  # and stated here anyway, because this is the machine the option was written
  # for — the desk gets the same default and draws nothing, since `lock-session`
  # only writes the widget out when it finds a battery.
  local.niri.lockBatteryIndicator = true;

  # No OpenRGB tray applet at login here, and nothing to switch off to get
  # that: `local.openrgb.autostart` defaults to whether the OpenRGB daemon is
  # enabled, and the daemon comes with modules/nixos/gaming.nix, which
  # hosts/laptop-niri doesn't import. The desk has RGB hardware worth driving;
  # here the applet would have nothing to talk to and would still cost a tray
  # icon, a Qt process and a failed profile load every session.
  #
  # Nothing OpenRGB-shaped is installed here at all, in fact: the package comes
  # from the daemon's own module (`services.hardware.openrgb` puts it in
  # environment.systemPackages), so no daemon means no `openrgb` on PATH
  # either. If a docked keyboard or mouse ever needs it, `nix run nixpkgs#openrgb`
  # is a one-off, and importing modules/nixos/gaming.nix on this host is the
  # permanent version.
  # Only read under `local.niri.shell = "waybar"`, where swayidle runs at all.
  # noctalia's idle timers are in home/joshr/niri/noctalia.nix and are the same
  # on both niri hosts: lock at 300s, outputs off at 600s. This host's tighter
  # "lock and blank together" is not carried across; set the `screen-off`
  # behaviour's timeout to 300 there if it turns out to be wanted.
  services.swayidle.events.lock = lib.mkForce (lib.getExe niriScripts.lockBlank);
}
