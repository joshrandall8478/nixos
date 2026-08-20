{
  description = "joshr's gaming + development NixOS workstation (KDE Plasma, NVIDIA, Steam, Docker)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    #nur = {
    #  url = "github:nix-community/NUR";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # keylase/nvidia-patch as a nixpkgs overlay: takes the concurrent-NVENC
    # session cap and the Quadro-only NvFBC check off a GeForce driver.
    #
    # Used by one host — `server-nvidia` below, through
    # modules/nixos/nvidia-server.nix, which is where what it does and what
    # it costs is written down. The overlay is applied inside that module
    # rather than here, so it reaches the hosts that import it and no others.
    #
    # `follows` because the overlay is a function of whatever pkgs it is
    # applied to; the flake's own nixpkgs only exists for its `nix build`
    # outputs, and letting it pin release-23.11 would put a second nixpkgs in
    # flake.lock for nothing.
    nvidia-patch = {
      url = "github:icewind1991/nvidia-patch-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #xwayland-satellite-scale-fixes = {
    #  url = "github:larsch/xwayland-satellite/scale-fixes";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    # The boot splash: the NixOS logo over black with a progress bar under it,
    # paced like a Mac's boot animation. Used by modules/nixos/plymouth.nix,
    # which is where the reasoning lives — including why the theme it installs
    # is called `mac-style` when the repository is called s4rchiso.
    #
    # Named `mac-style-plymouth` because that is the name the repository's own
    # README gives this input, and the overlay that module applies
    # (`overlays.default`) adds a package of the same name. The Arch theme the
    # repository is named after is on its `archlinux` branch and is not what
    # this input points at; the default branch is the NixOS flake.
    #
    # `follows` for the same reason as nvidia-patch above: it exists to build
    # a package against *this* flake's nixpkgs, and letting it pin its own
    # would put a second nixpkgs in flake.lock for nothing. Its flake-utils
    # has nothing here to follow and stays pinned on its own; that one is a
    # library of pure functions, so it costs a lock entry and no build.
    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The CachyOS kernel, prebuilt: mainline Linux plus CachyOS's patch set and
    # their kconfig, packaged as `linuxPackages-cachyos-*` attribute sets.
    #
    # nixpkgs has nothing equivalent and is not about to: it carries `linux_zen`
    # and the XanMod family, and `linux_lqx` was removed outright for lack of
    # maintenance. The variant this repo actually wants — BORE — has no home
    # there at all. modules/nixos/kernel.nix is where the choice is made and
    # what it buys is written down.
    #
    # Pinned to the `release` branch rather than the default `master`. Both
    # describe the same kernels; `release` only moves once the flake's own
    # Hydra has built them and pushed them to the binary cache, while `master`
    # can name a kernel that has never been compiled anywhere. That difference
    # is not a slow download — a kernel that misses the cache is the better
    # part of an hour of the desk compiling one.
    #
    # **No `inputs.nixpkgs.follows` here, deliberately** — the opposite of what
    # nvidia-patch and mac-style-plymouth above do, and for a reason that only
    # applies to this input. Those two are functions of whatever pkgs they are
    # applied to, so following costs nothing and saves a lock entry. This one
    # ships *built* kernels, and every one of them is keyed on the exact
    # nixpkgs revision it was built against; pointing it at ours would change
    # the derivation hash of the lot and turn every cache hit into a local
    # build. The second nixpkgs in flake.lock is what not compiling a kernel
    # costs.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    # joshrandall8478's existing chezmoi dotfiles repo. Used purely as a source
    # of static assets (fonts, custom Plasma themes/look-and-feel packages,
    # cursor theme, custom icons, wallpapers) that are pulled straight into the
    # home-manager profile below instead of being hand-transcribed.
    dotfiles = {
      url = "github:joshrandall8478/dotfiles";
      flake = false;
    };

    # wallhaven.cc's current toplist, as the API's JSON search response. This
    # is the *list*, not the images: home/joshr/wallhaven.nix reads it and
    # downloads the twenty files it names into
    # ~/.local/share/wallpapers/WallhavenFlake.
    #
    # Locking the response is the point of doing it this way. The twenty
    # become a property of flake.lock like every other input — the same
    # twenty on the desk and on the laptop, changing when `nix flake update`
    # says so and not whenever wallhaven's front page moves. Nix caches
    # fetched files for an hour, so re-locking twice in one sitting wants
    # --refresh:
    #
    #     nix flake update --refresh wallhaven-toplist
    #
    # `file+https` rather than plain https: the plain form is the tarball
    # fetcher, which would try to unpack a JSON document. The query is the
    # website's Toplist view — all three categories (111), SFW only (100),
    # ranked over the last month, nothing below 1080p. Edit it and re-lock to
    # change what "top 20" means; the count itself is
    # `local.wallhaven.count`.
    #
    # `ratios` keeps it to widescreen. Both displays on the desk are 16:9
    # (2560x1440 and 1920x1080, see home/joshr/displays/gamestation.nix), so
    # 16:10 is the widest miss worth accepting — it scales to 16:9 losing a
    # sliver off the top and bottom. Anything squarer arrives pillarboxed or
    # cropped hard by whichever of awww or Plasma is drawing it. The laptop
    # panel isn't pinned anywhere in here (displays/laptop.nix is empty on
    # purpose), so it isn't what this is measured against; 16:10 covers it
    # if it turns out to be one.
    #
    # The parameter takes a comma-separated list, written `%2C` here so the
    # separator survives whatever Nix does to the query on its way to the
    # fetcher — wallhaven url-decodes it back either way. wallhaven also has
    # a `landscape` supergroup, but that is every non-portrait ratio it knows
    # — 4x3 and 5x4 included — which is "not portrait" rather than "wide".
    # The ultrawide ratios (21x9, 32x9) are left out on purpose: nothing
    # here has a display to put them on, and on a 16:9 panel they letterbox
    # to a strip.
    #
    # Narrowing the query narrows the pool it is drawn from, so a month with
    # an unusually vertical toplist can return fewer than
    # `local.wallhaven.count` images. That is handled — the sync script takes
    # what is there — it just means the folder is occasionally short.
    wallhaven-toplist = {
      url = "file+https://wallhaven.cc/api/v1/search?categories=111&purity=100&sorting=toplist&topRange=1M&order=desc&atleast=1920x1080&ratios=16x9%2C16x10";
      flake = false;
    };
  };

  # The kernel flake's binary cache, offered to whatever nix command is
  # building *this* flake — which is the one thing that stops the desk
  # compiling a kernel.
  #
  # modules/nixos/kernel.nix writes the same substituter and key into the
  # system's /etc/nix/nix.conf, and that is what every rebuild reads *after*
  # the one that installs it. This block is for the one that installs it: a
  # cache that arrives with the configuration it was meant to fetch is a cache
  # the daemon didn't have when it planned the build, and the machine spends
  # the better part of an hour compiling a kernel that already exists.
  #
  # nix asks before honouring this — "do you want to allow configuration
  # setting 'extra-substituters' to be set to ..." — once per user, remembered
  # in ~/.local/share/nix/trusted-settings.json. Say yes, or skip the question
  # entirely:
  #
  #     sudo nixos-rebuild switch --flake .#gamestation --accept-flake-config
  #
  # Two things have to be true for any of this to apply, and both already are.
  # The flake being *built* has to be this one — a `nixConfig` in an input is
  # ignored, which is why the kernel flake's own copy of these two lines does
  # nothing for us and this duplicate has to exist. And whoever runs the build
  # has to be in `nix.settings.trusted-users`, since the daemon discards
  # substituters offered by anyone else: root, and @wheel through
  # modules/nixos/development.nix.
  #
  # `accept-flake-config = true` in nix.settings would retire the prompt for
  # good and is deliberately not set — it would apply to every flake this
  # machine ever builds, and the point of the prompt is that adding a
  # substituter is a trust decision. Answering it once per machine is the
  # right amount of friction.
  #
  # These two lines and the ones in modules/nixos/kernel.nix have to stay in
  # step. Nothing checks that they do: a flake's `nixConfig` is read before
  # any of the module system exists, so it cannot be derived from an option.
  nixConfig = {
    extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
    extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      plasma-manager,
      spicetify-nix,
      dotfiles,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations =
        let
          # `homeModules` is the host's home-manager users, as
          # `username -> entrypoint`. root is added to every host below rather
          # than named in each call: it gets the same fish + starship setup
          # everywhere, minus everything graphical, so there is nothing
          # per-host to say about it.
          #
          # **Every account the host's users module creates belongs in here.**
          # The two lists are separate — modules/nixos/users.nix decides who can
          # log in, this decides what they log in *to* — and an account named
          # there but not here is not an error at any point: it evaluates, it
          # builds, SDDM lists it, and the session it opens is a bare
          # compositor with no bar, no keybinds and no shell, because nothing
          # ever wrote that account a ~/.config. That is the state `sabom` was
          # in on every desktop host except laptop-niri.
          mkHost =
            { hostModule, homeModules }:
            nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs; };
              modules = [
                hostModule

                home-manager.nixosModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  # home-manager refuses to overwrite a file it doesn't already
                  # manage. Now that it writes ~/.bashrc and ~/.zshrc, any
                  # pre-existing copy would abort activation; this moves them
                  # aside as e.g. ~/.bashrc.hm-backup instead.
                  home-manager.backupFileExtension = "hm-backup";
                  home-manager.extraSpecialArgs = { inherit inputs; };
                  home-manager.sharedModules = [
                    plasma-manager.homeModules.plasma-manager
                    spicetify-nix.homeManagerModules.spicetify
                  ];
                  # Each account has to exist on the NixOS side as well —
                  # home-manager reads its home directory from
                  # `users.users.<name>` — which is modules/nixos/users.nix,
                  # imported by every host.
                  home-manager.users = nixpkgs.lib.mapAttrs (_name: import) (
                    { root = ./home/root/home.nix; } // homeModules
                  );
                }
              ];
            };
        in
        {
          # --- Plasma sessions -------------------------------------------
          gamestation = mkHost {
            hostModule = ./hosts/gamestation/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/gamestation.nix;
              # raiden = ./home/raiden/gamestation.nix;
              amandak = ./home/amandak/gamestation.nix;
              sabom = ./home/sabom/gamestation.nix;
            };
          };

          laptop = mkHost {
            hostModule = ./hosts/laptop/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/laptop.nix;
              # raiden = ./home/raiden/laptop.nix;
              amandak = ./home/amandak/laptop.nix;
              sabom = ./home/sabom/laptop.nix;
            };
          };

          # --- niri sessions ---------------------------------------------
          # Same two machines, niri instead of Plasma. Separate hosts because
          # the two use different display managers (plasma-login-manager vs
          # SDDM) and NixOS won't enable both. Switching is just a rebuild:
          #
          #   sudo nixos-rebuild switch --flake .#gamestation-niri
          #   sudo nixos-rebuild switch --flake .#gamestation
          #
          # Which shell the session runs is a property of the *profile*, not of
          # the account: `local.niri.shell = "noctalia"` is set in joshr's
          # entrypoint for each of these two hosts, and the entrypoints named
          # beside it import that file, so every account listed here gets the
          # same noctalia session. What stays with one account is the machine's
          # own surfaces — the greeter, the boot menu and the OpenRGB profile
          # follow `local.desktop.primaryUser`, and each session's palette,
          # wallpaper and Noctalia settings live under its own home.
          gamestation-niri = mkHost {
            hostModule = ./hosts/gamestation-niri/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/gamestation-niri.nix;
              # raiden = ./home/raiden/gamestation-niri.nix;
              amandak = ./home/amandak/gamestation-niri.nix;
              sabom = ./home/sabom/gamestation-niri.nix;
            };
          };

          laptop-niri = mkHost {
            hostModule = ./hosts/laptop-niri/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/laptop-niri.nix;
              # delta = ./home/delta/laptop-niri.nix;
              # raiden = ./home/raiden/laptop-niri.nix;
              amandak = ./home/amandak/laptop-niri.nix;
              sabom = ./home/sabom/laptop-niri.nix;
            };
          };

          # --- removable -------------------------------------------------
          # A full install on a USB stick, carried between machines. Same
          # niri session as the two hosts above; the differences are that it
          # boots on hardware it has never seen, installs its bootloader at
          # the removable-media path so it changes nothing on the machine it
          # is plugged into, and logs straight in.
          #
          # It is the one host whose `homeModules` has a single entry and
          # means it: hosts/usb imports modules/nixos/usb-users.nix rather
          # than users.nix, so joshr is the only account on the machine.
          # Naming a second one here would be a home profile for a user that
          # does not exist.
          usb = mkHost {
            hostModule = ./hosts/usb/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/usb.nix;
            };
          };

          # --- headless --------------------------------------------------
          # No desktop at all. Scheduled work lives in its `local.cron`
          # section; see modules/nixos/cron.nix.
          server = mkHost {
            hostModule = ./hosts/server/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/server.nix;
            };
          };

          # The same, with a card in it: driver, nvidia-persistenced, the
          # container toolkit and the NVENC/NvFBC patch. See
          # modules/nixos/nvidia-server.nix and "The NVIDIA server" in
          # MANUAL.md.
          #
          # It reuses home/joshr/server.nix rather than getting a
          # `server-nvidia.nix` of its own, which is the one place this host
          # departs from one-entrypoint-per-host. There is nothing per-host
          # to say: that file is the shared shell and git, and a GPU is not
          # something a home profile has an opinion about. Add the file the
          # moment it does.
          server-nvidia = mkHost {
            hostModule = ./hosts/server-nvidia/configuration.nix;
            homeModules = {
              joshr = ./home/joshr/server.nix;
            };
          };
        };

      # Starting points for per-project development environments:
      #
      #   nix flake init -t github:joshrandall8478/nixos#python
      #
      # or `dev-init python`, which does that and sets up direnv in one go.
      # See "Development environments" in MANUAL.md.
      #
      # They live here rather than in a separate repo so that the machines
      # and the shells they build are updated by the same `nix flake update`.
      #
      # Each language template's shellHook also installs the project's own
      # dependencies on the way in — npm install, uv sync or a requirements
      # file, go mod download, cargo fetch — guarded by a stamp file so an
      # ordinary entry costs no subprocess at all, and by DEV_NO_INSTALL=1
      # for a project whose dependencies are being managed by hand. Nix
      # brings the toolchain and the toolchain brings the libraries, so a
      # project's own lockfile stays the thing that decides.
      templates = {
        default = self.templates.generic;

        generic = {
          path = ./templates/generic;
          description = "Empty devShell skeleton — add packages and go";
          welcomeText = ''
            Edit the `packages` list in flake.nix, then `direnv allow`.
          '';
        };

        python = {
          path = ./templates/python;
          description = "Python 3.13 with uv, ruff and a project-local venv";
          welcomeText = ''
            Nix supplies the interpreter and tooling; the venv created by the
            shellHook supplies the libraries, installed on entry from
            requirements.txt or a pyproject.toml. `direnv allow` to enter.
          '';
        };

        node = {
          path = ./templates/node;
          description = "Node.js 22 with pnpm and the TypeScript language server";
          welcomeText = ''
            `direnv allow` to enter. node_modules is installed on entry and
            refreshed whenever package.json or the lockfile moves, and npm's
            global prefix is redirected into the project, so `npm i -g`
            works.
          '';
        };

        rust = {
          path = ./templates/rust;
          description = "Rust toolchain from nixpkgs, with rust-analyzer and clippy";
          welcomeText = ''
            `direnv allow` to enter; the crates the project locks are
            fetched on the way in. Native libraries your crates link
            against go in `buildInputs`.
          '';
        };

        go = {
          path = ./templates/go;
          description = "Go with gopls, gotools and golangci-lint";
          welcomeText = ''
            `direnv allow` to enter. GOPATH is redirected into the project,
            and the module cache is filled on the way in.
          '';
        };
      };

      # `dev-init` on its own, for a machine this flake does not build.
      #
      # The command normally arrives with modules/nixos/development.nix, in
      # the system profile of whichever hosts have that import uncommented.
      # That is no help on a machine running something else — the CachyOS
      # install, a work laptop, a container — where there is nix and no
      # NixOS. Exposing the same derivation as a package makes it reachable
      # from any of them:
      #
      #     nix profile install github:joshrandall8478/nixos#dev-init
      #     nix run github:joshrandall8478/nixos#dev-init -- python
      #
      # `profile install` is the one to prefer, and not only because it puts
      # the command on PATH for good. Evaluating any output of this flake
      # makes nix fetch every input in flake.lock first — the kernel flake,
      # the dotfiles, the wallhaven listing, none of which this package
      # touches — so `nix run` pays for the lot again each time its
      # tarball-ttl lapses, and `profile install` pays once.
      #
      # The rest of what development.nix does — the nix.settings, direnv,
      # the registry pin — has no package to install and has to be set up by
      # hand there. See "Nix on a machine that isn't NixOS" in MANUAL.md.
      packages.${system}.dev-init = pkgs.callPackage ./packages/dev-init.nix { };

      # Same program as `nixfmt-rfc-style`, under its own name. nixpkgs used
      # to carry two formatters — that one and a `nixfmt-classic` — and the
      # long name distinguished them; classic has since been removed and
      # `nixfmt-rfc-style` is now an alias that warns on every evaluation.
      formatter.${system} = pkgs.nixfmt;
    };
}
