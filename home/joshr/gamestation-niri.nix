{ ... }:

# joshr's home profile on the desk, niri session.
#
# Same base as the Plasma variant (shell, kitty, vscode, packages) with the
# niri desktop in place of plasma.nix. plasma-manager is deliberately not
# imported here — under niri its settings would be inert, and its activation
# script shells out to `plasma-apply-*` tools that aren't in this session.
#
# The display layout lives in ./displays/gamestation.nix, kept separate so
# monitor changes don't mean editing this file.
{
  imports = [
    ./home.nix
    ./airpods-media-controls.nix
    ./desktop-apps.nix
    ./niri
    ./niri/privacy.nix
    ./displays/gamestation.nix
    ./office.nix
    ./obs.nix
    ./content-creation.nix
    ./gaming.nix
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

  # noctalia rather than the waybar stack. See home/joshr/niri/noctalia.nix,
  # and `local.niri.shell` in home/common/options.nix for what moves and what
  # is lost. Setting this back to "waybar" is the whole way back.
  #
  # The lock-screen options below are only read under "waybar" — noctalia's
  # lock screen has no album art or greetings — and are left as they were so
  # that going back restores the screen this host had.
  local.niri.shell = "noctalia";

  local.niri.randomLockGreetings = false;
  local.niri.timeBasedLockGreetings = true;

  local.niri.lockAlbumArtBackground = true;
  local.niri.lockAlbumArtCover = true;
}
