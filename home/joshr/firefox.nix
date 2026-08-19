{ config, ... }:

# Firefox, on every host. Installed and themed, but no longer the default —
# see ./browser.nix, which hands that back to Vivaldi.
#
# Why it was the default
# ----------------------
# The brief was: cloud sync, Chromium- or Firefox-based, and able to wear the
# niri palette. Firefox is the only candidate that does all three without a
# workaround. The notes below are kept because they are still what you'd be
# giving up by uninstalling it, and still what makes the theming work.
#
#   sync     Firefox Sync, over a Mozilla account. First-party, end-to-end
#            encrypted, and it carries bookmarks, history, open tabs, logins,
#            add-ons and preferences between the desk and the laptop with no
#            server of your own.
#
#   theming  Chromium's UI colours come from a signed theme extension or from
#            whatever GTK says; neither takes a palette from a file. Vivaldi —
#            what this replaced — *can* take arbitrary colours, but only
#            through its own settings UI, into a preferences blob that isn't
#            declarative and can't be repointed at a symlink. Firefox reads
#            `chrome/userChrome.css` out of the profile directory at startup,
#            so it can be pointed at the active theme exactly like Dolphin's
#            kdeglobals. See home/joshr/niri/firefox.nix.
#
# What Nix owns and what Sync owns
# --------------------------------
# Nix owns the *shape* of the browser: which prefs are set, that custom
# stylesheets are on, that it's the handler for http(s). Sync owns the
# *contents*: bookmarks, history, tabs, logins, add-ons.
#
# That split is deliberate. Declaring add-ons here would need the NUR or the
# firefox-addons flake, and it would then fight Sync every time the two
# disagreed — Nix would reinstall what you removed on the laptop. The prefs
# below are written to `user.js`, which Firefox re-applies on every start, so
# where the two overlap the declared value always wins. Anything you want to
# change from inside the browser and have stick has to not be listed here.
let
  # Referenced by home/joshr/niri/firefox.nix to find the profile directory,
  # so the two can't drift apart.
  #
  # From `config.home.username` rather than written out, because this file is
  # shared with the accounts in home/raiden/ and the name becomes a directory:
  # ~/.mozilla/firefox/<profileName>. It resolves to "joshr" here exactly as
  # the literal did, so there is no profile to migrate.
  profileName = config.home.username;
in
{
  programs.firefox = {
    enable = true;

    profiles.${profileName} = {
      id = 0;
      isDefault = true;

      # home-manager defaults this to the attribute name; stated because the
      # niri module builds ~/.mozilla/firefox/<path>/chrome from it.
      path = profileName;

      settings = {
        # --- theming ---------------------------------------------------
        # Without this Firefox ignores chrome/userChrome.css and
        # chrome/userContent.css entirely — it is the switch that makes the
        # whole palette story work, on niri hosts and nowhere else.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # Dark, matching the prefer-dark the niri session already sets for
        # GTK4/libadwaita and Electron, and the Plasma colour scheme.
        #
        # This one can't follow a runtime theme switch — prefs are read at
        # startup from user.js, which is a store file. The generated
        # userChrome.css carries CSS `color-scheme` per palette on top of it,
        # so the two light palettes still get light native widgets; what they
        # don't get is Firefox's own light *built-in* theme underneath.
        "ui.systemUsesDarkTheme" = 1;

        # --- sync ------------------------------------------------------
        # On by default in a stock build; stated so that it's obvious this is
        # load-bearing and not something to disable while trimming telemetry.
        # Sign in from the toolbar's account button.
        "identity.fxaccounts.enabled" = true;

        # --- Wayland ---------------------------------------------------
        # Go through the desktop portal for file dialogs and for handing a
        # link or download off to another app, so both get the same picker as
        # everything else in the session rather than Firefox's own.
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "widget.use-xdg-desktop-portal.mime-handler" = 1;

        # Ask for hardware video decode. Whether it's actually used depends on
        # the driver having a VA-API backend — Intel on the laptop does out of
        # the box; NVIDIA's proprietary stack needs nvidia-vaapi-driver, which
        # the desk hosts install alongside `LIBVA_DRIVER_NAME` in
        # modules/nixos/nvidia.nix. Firefox falls back to software decode
        # either way, so this is a request, not a guarantee. `nix run
        # nixpkgs#libva-utils -- vainfo` is what says whether the backend
        # answered; nothing here installs it.
        "media.ffmpeg.vaapi.enabled" = true;

        # --- first-run and new tab noise -------------------------------
        # The rebuild sets the default browser — /etc/xdg/mimeapps.list, from
        # modules/nixos/default-apps.nix — so the nag is only ever wrong.
        "browser.shell.checkDefaultBrowser" = false;
        "browser.aboutConfig.showWarning" = false;

        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "extensions.pocket.enabled" = false;

        # --- telemetry -------------------------------------------------
        # Note this is not the same switch as sync: Mozilla accounts stay on.
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "app.shield.optoutstudies.enabled" = false;
      };
    };
  };

  # $BROWSER and the http(s) handler are *not* set here — Vivaldi is the
  # default again, and both live in ./browser.nix. Firefox stays installed
  # and stays themed; it is simply not what links open in.
}
