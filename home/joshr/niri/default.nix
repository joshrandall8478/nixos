{
  config,
  lib,
  pkgs,
  niriTheming,
  ...
}:

# niri desktop for joshr: compositor config, bar, notifications, launcher,
# lock screen, and the theme/wallpaper switcher.
#
# Import order matters a little: theming.nix, scripts.nix and gamemode.nix
# publish `_module.args` (niriTheming, niriScripts, niriGamemode) that the
# others consume.
#
# Two shells live here, picked per host with `local.niri.shell`. Everything
# from ./waybar.nix down to ./emoji.nix is the assembled stack; ./noctalia.nix
# is the single-process alternative that replaces all of it. Both are imported
# on every niri host and each is gated internally, because `imports` cannot
# read `config` without sending the module system round in a circle.
#
# The theme machinery below is shared rather than switched. theming.nix renders
# themes.nix into every app's own format either way, and the two symlinks at
# the bottom of this file — kdeglobals for Dolphin, the kitty include — are
# what carries a theme change into apps that are not the shell. noctalia's own
# template system is deliberately off for exactly that reason; see the `theme`
# block in ./noctalia.nix.
{
  imports = [
    ./theming.nix
    ./scripts.nix
    ./gamemode.nix
    ./niri.nix
    ./waybar.nix
    ./noctalia.nix
    ./notifications.nix
    ./osd.nix
    ./lock.nix
    ./clipboard.nix
    ./emoji.nix
    ./osk.nix
    # No ./browser.nix or ./mime.nix any more. Both set `xdg.mimeApps`, which
    # owns ~/.config/mimeapps.list and made every settings panel unable to
    # save; the associations are now a system baseline in
    # modules/nixos/default-apps.nix that the user's file overrides.
    ./vscode.nix
    #./firefox.nix
  ];

  # Dolphin as the graphical file manager. It follows the active theme
  # through kdeglobals — see the symlink below.
  home.packages = with pkgs; [
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    
    kdePackages.kconfig
    kdePackages.kio-fuse # mount remote filesystems in place
    kdePackages.kio-extras # sftp://, mtp://, trash:// and friends

    # The File Associations panel (kcm_filetypes) and the standalone
    # keditfiletype that Dolphin's file-properties dialog opens. This is what
    # actually sets "open this type with that app" — System Settings, enabled
    # in the qt block below, is only the shell it loads into and ships no KCMs
    # of its own.
    kdePackages.kde-cli-tools
    kdePackages.qtsvg # icon rendering
    kdePackages.breeze-icons # fallback icons Dolphin expects to exist

    # Screenshot stack: wayfreeze holds a still frame over the screen, slurp
    # selects on top of it, grim captures, satty annotates. The `screenshot`
    # helper takes its own copies through runtimeInputs; these are here so the
    # same tools are on PATH by hand, which is how you tell which of them is at
    # fault when a capture comes out wrong.
    wayfreeze
    grim
    slurp
    satty

    # Wallpaper daemon (this is swww — renamed to awww in nixpkgs 2026-03).
    awww

    # Clipboard, brightness, media control for the keybinds above.
    wl-clipboard
    brightnessctl
    playerctl

    # Drives the bar's visualiser (see cavaBar in scripts.nix). Here as well
    # so plain `cava` in a terminal works — that's the full-size version of
    # the same thing, and it's the quickest way to tell whether it's cava or
    # the widget at fault if the bar stays empty.
    cava

    # Tray applet for NetworkManager, spawned at startup.
    # networkmanagerapplet

    # X11 apps under niri.
    xwayland-satellite
  ];

  services.blueman-applet.enable = false;

  xdg.configFile."autostart/blueman.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Blueman Applet
      Hidden=true
    '';
  };

  # Cursor theme is set in ../home.nix so the Plasma and niri sessions share
  # one definition; niri.nix just names it in `cursor { xcursor-theme … }`.

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Noto Sans";
      size = 10;
    };
  };

  # Dark preference for apps that honour it (GTK4/libadwaita, Electron).
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # Qt apps take their palette from KDE, not from GTK.
  #
  # This is what makes the kdeglobals symlink below actually do something.
  # `platformTheme.name = "gtk"` — what this used to be — loads Qt's GTK
  # platform plugin, which reads colours out of the *GTK* theme and never
  # opens kdeglobals at all; combined with `style.name = "adwaita-dark"`
  # forcing Adwaita on top, Dolphin came out in Adwaita's grey no matter
  # which palette was active. Naming "kde" loads plasma-integration instead,
  # which is the piece that reads ~/.config/kdeglobals through KColorScheme.
  #
  # Breeze rather than Adwaita for the widget style, because Breeze is the
  # one that draws from the KDE colour scheme; it's also what the generated
  # kdeglobals already declares in `[KDE] widgetStyle`. home-manager pulls in
  # kdePackages.breeze and plasma-integration from these two names.
  #
  # None of this needs Plasma to be running — KColorScheme is a library, and
  # the greeter/session around it is irrelevant. Qt file dialogs become KDE's
  # rather than GTK's, which is why kio is in the package list below.
  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";

    # Spelled out rather than left to the name mapping.
    #
    # System Settings is back in the list. It was dropped for showing up in
    # the launcher on a session with no Plasma to configure, which was true —
    # but it turned out to be wanted for the File Associations panel, so the
    # reason it was removed no longer outweighs having it.
    #
    # It does not carry that panel itself. `systemsettings` ships no KCMs at
    # all; it is the shell they load into, and on its own it opens onto almost
    # nothing. The panels are in other packages —
    #
    #     kcm_filetypes / keditfiletype   kde-cli-tools    (File Associations)
    #     kcm_componentchooser            plasma-desktop   (Default Applications)
    #
    # — so kde-cli-tools is installed alongside it in home.packages above.
    # That is the one that matters here: File Associations is the per-MIME-type
    # panel, which is what "open photos with Gwenview" actually needs.
    # plasma-desktop is deliberately not pulled in for the other one; it is a
    # large chunk of Plasma, and Default Applications only covers the
    # browser/email/terminal/file-manager four rather than file types.
    #
    # None of those panels could save anything until recently, whatever was
    # installed: they write ~/.config/mimeapps.list, which `xdg.mimeApps` used
    # to own as a read-only store symlink. See modules/nixos/default-apps.nix.
    #
    # The mapping this replaces: home-manager's qt module maps
    # `platformTheme.name = "kde"` to a fixed list, and in
    # modules/misc/qt/default.nix that list is
    #
    #     kde = [ kdePackages.kio kdePackages.plasma-integration
    #             kdePackages.systemsettings ];
    #
    # Setting `package` here overrides the mapping outright rather than adding
    # to it — the module takes the *first non-empty* of [package-list,
    # name-derived-list]. Listing all three is therefore the same set the name
    # would have given; it stays spelled out so that dropping one again is a
    # one-line change with the reasoning above it.
    #
    # The other two are load-bearing: kio is the KDE file dialog, and
    # plasma-integration is the platform plugin that reads kdeglobals, which
    # is the entire reason the theme is named "kde" rather than "gtk".
    #
    # `name` stays "kde" and still sets QT_QPA_PLATFORMTHEME=kde; the plugin
    # search path is built from the profile directory, not from this list, so
    # the contents can't strip it. The Plasma hosts are untouched — they get
    # System Settings from Plasma itself, and this file is only imported by
    # the niri profiles.
    platformTheme.package = with pkgs.kdePackages; [
      kio
      plasma-integration
      systemsettings
    ];
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # Point KDE apps at the active theme's kdeglobals.
  #
  # KColorScheme reads this whether or not Plasma is running, so Dolphin
  # picks up the palette in a bare niri session — but only with the KDE
  # platform theme loaded, which is what the `qt` block above is for. It has
  # to be a symlink to the mutable state path rather than a store file, or a
  # theme switch couldn't change it — mkOutOfStoreSymlink is home-manager's
  # escape hatch for exactly that.
  #
  # A *running* Dolphin repaints if it hears KDE's palette-changed signal,
  # which `theme-apply` emits (see scripts.nix). Nothing guarantees a given
  # app listens for it, so the fallback is still "relaunch and it's correct".
  xdg.configFile."kdeglobals".source =
    config.lib.file.mkOutOfStoreSymlink "${niriTheming.activeDir}/kdeglobals";

  # Point kitty at the active theme's colours.
  #
  # This lives here rather than in ../kitty.nix because that module is shared
  # with the Plasma hosts, which have no niri theme state — the include would
  # be a dangling path there. On a niri host it's appended to everything
  # kitty.nix already set, and kitty takes the last value for any key, so the
  # colours are overridden and font, padding and opacity are left alone.
  #
  # mkAfter is what guarantees that ordering: extraConfig is a `lines` option,
  # and without it the merge order between two modules isn't defined.
  #
  # The theme switcher reloads running terminals; see scripts.nix.
  #
  # Only under the waybar stack. noctalia's `kitty` template renders the same
  # palette to ~/.config/kitty/themes/noctalia.conf and ./noctalia.nix adds
  # the include for it; carrying both would leave two `include` lines setting
  # the same colours, where kitty takes the last value for any key and which
  # one that is would come down to the merge order of two `mkAfter`s. One
  # writer per shell instead.
  programs.kitty.extraConfig = lib.mkIf (config.local.niri.shell == "waybar") (
    lib.mkAfter ''

      include ${niriTheming.activeDir}/kitty.conf
    ''
  );

  # Enable Dolphin's Git version-control integration while leaving dolphinrc
  # writable, so Dolphin can still save its other preferences normally.
  home.activation.enableDolphinGitPlugin =
  lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config"

    $DRY_RUN_CMD ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} \
      --file "$HOME/.config/dolphinrc" \
      --group VersionControl \
      --key enabledPlugins \
      Git
  '';
}
