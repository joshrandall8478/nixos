{ config, lib, ... }:

# System-level `local.*` options.
#
# The home-manager equivalents live in home/common/options.nix; these are the
# ones a NixOS module needs to read, which can't come from there.
{
  # Whose session the machine-wide surfaces follow.
  #
  # Three things outside any session are dressed from one user's choices: the
  # SDDM greeter reads the theme and wallpaper out of that user's
  # `~/.local/state/niri-theme`, the limine boot menu reads only the theme
  # there, and plasmalogin copies Plasma's settings out of their `~/.config`
  # (modules/nixos/niri.nix, modules/nixos/boot.nix and
  # modules/nixos/plasmalogin.nix).
  #
  # Each of those is a singleton — one login screen, one boot menu — so this
  # can't be generalised to "every user" without the last one to log in
  # deciding what the machine looks like at boot. Naming one owner is the
  # honest version. It was `/home/joshr/...` written into three modules
  # before this option existed; the default keeps that behaviour exactly.
  options.local.desktop.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = "joshr";
    example = "alice";
    description = ''
      Account whose theme the login screen and boot menu follow, and whose
      wallpaper the login screen follows. Limine keeps its build-time image.

      The user has to exist and have a home directory at /home/<name> —
      nothing here creates one. Their session writes the state these modules
      read, so a name that never logs into niri leaves the greeter and the
      boot menu on the default palette rather than breaking: the sync
      services find no state file and leave what is already there.
    '';
  };

  options.local.boot.maxGenerations = lib.mkOption {
    type = lib.types.ints.positive;
    default = 10;
    description = "Maximum amount of generations shown in limine";
  };

  options.local.boot.loader = lib.mkOption {
    type = lib.types.enum [
      "limine"
      "grub"
      "systemd-boot"
    ];
    default = "limine";
    description = ''
      Which bootloader to install. See modules/nixos/boot.nix.

      "limine" is the default because it is the only one of the three that
      can draw a wallpaper and the desktop's live palette on the boot menu,
      which is the point of the module. It finds other operating systems by
      scanning the EFI System Partition for their boot loaders.

      "grub" is the fallback for anything limine can't handle — BIOS/MBR
      installs, exotic partition layouts, or a machine whose firmware
      dislikes limine's EFI binary. It detects other systems with os-prober,
      which looks *inside* other partitions rather than only at the ESP, so
      it finds installs whose loader isn't on this ESP at all. It is themed
      from the palette but its background is fixed at build time.

      "systemd-boot" is the escape hatch, and what this repo used before the
      module existed. No theming at all — it has no background support — but
      it is the most boring, best-tested option on a UEFI machine, and it
      picks up Windows on its own.

      Changing this rewrites how the machine boots. Do it on a rebuild you
      can watch, with install media to hand: the previous generation stays
      in the *old* loader's menu, but only if that loader is still installed
      and still the one the firmware runs.
    '';
  };

  options.local.boot.detectOtherSystems = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Add boot menu entries for other operating systems found on the machine.

      Under limine this scans the EFI System Partition for other vendors'
      boot loaders (Windows, another distro's GRUB or shim, rEFInd) and adds
      a chainload entry for each. Under grub it enables os-prober. Under
      systemd-boot it does nothing — that loader already finds Windows and
      any other Boot Loader Spec entries by itself.

      Under limine this covers this machine's own ESP always, and every
      other EFI System Partition on the machine when
      `local.boot.scanAllEsps` is on. What neither reaches is an OS whose
      loader lives on a non-EFI partition — os-prober (grub) is the option
      that looks that far.
    '';
  };

  options.local.boot.scanAllEsps = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Look for other operating systems on *every* EFI System Partition
      attached to the machine, not just the one NixOS boots from. Only
      meaningful under limine, and only when
      `local.boot.detectOtherSystems` is on.

      This is what finds a Windows installed on its own disk. Sharing one
      ESP is the common case for a dual boot set up in a single sitting,
      and the plain scan handles that — but a second OS installed later, or
      onto a disk of its own, brings its own ESP, and NixOS does not mount
      it. So limine-theme-sync locates them by partition type, mounts each
      read-only in turn, reads it, and unmounts. Nothing is written and no
      mount outlives the scan.

      Entries found this way are addressed by filesystem UUID
      (`uuid(XXXX-XXXX):/EFI/...`) rather than limine's `boot():`, which
      only ever means the volume limine itself was loaded from.

      Turn this off if the extra mounts are unwelcome — on a machine with an
      encrypted or removable disk you'd rather nothing touched, or if a
      rebuild is somehow slowed by spinning something up.
    '';
  };

  options.local.boot.wallpaper = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = ''
      Optional replacement for the fixed image shown behind the boot menu.
      Under Limine, null selects the familiar NixOS wallpaper from the
      dotfiles input; under grub, null disables the splash image.

      Noctalia still supplies Limine's colours at runtime, but changing the
      session wallpaper never overwrites this image on the EFI System
      Partition.
    '';
  };

  options.local.boot.branding = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "gamestation";
    description = ''
      Text limine prints above the boot menu, in the theme's accent colour.
      null leaves limine's own branding alone. Ignored by the other loaders.
    '';
  };

  options.local.boot.menuTransparency = lib.mkOption {
    type = lib.types.strMatching "[0-9a-fA-F]{2}";
    default = "50";
    description = ''
      How much of the wallpaper shows through the limine menu panel, as the
      `TT` byte of limine's `term_background` (`TTRRGGBB`). "00" is an opaque
      panel in the theme's background colour — the wallpaper then only shows
      in the margin — and "ff" is fully transparent, which puts the menu text
      straight onto the picture and is usually unreadable.

      The default is a middle that keeps the text legible on a busy image.
    '';
  };

  options.local.boot.plymouth.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Draw a boot splash — the NixOS logo, animated — over the gap between the
      boot menu and the login screen. See modules/nixos/plymouth.nix, which is
      also where the theme's misleading provenance is written down.

      Off by default and turned on per host, because the hosts that want it
      are exactly the ones with someone sitting in front of them. On the two
      servers a splash has no audience and the console messages it replaces
      are the only thing to look at when a headless machine doesn't come back.
      The stick leaves it off too, for a reason of its own — see
      hosts/usb/configuration.nix.

      It costs the initrd: plymouth, its rendering module, the theme's frames
      and a DRM-capable framebuffer all have to be there before the root
      filesystem is, which is a few megabytes and a fraction of a second. It
      does not hide a failure — a stage-1 that panics drops to the emergency
      shell with the messages intact, and Escape at any point during the boot
      switches to the console.
    '';
  };

  options.local.boot.plymouth.quiet = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Turn the kernel, udev and stage-1 down to errors so nothing prints over
      the splash. Only read when `local.boot.plymouth.enable` is on.

      This is the half of a splash screen that people actually mean by one: a
      plymouth with a talkative kernel underneath is an animation with driver
      messages landing on top of it, because the kernel writes to the console
      directly and outranks anything userspace has drawn there.

      Turn it off to keep the messages while still getting the animation —
      worth doing on a machine that is misbehaving early in boot, where the
      output is the diagnosis. `journalctl -b` has all of it either way; this
      only decides what reaches the screen at the time.
    '';
  };

  # Which kernel a host boots — modules/nixos/kernel.nix, and "The kernel" in
  # MANUAL.md. Only the two desk hosts import that module; everything else
  # stays on the nixpkgs default and never sees these.
  options.local.kernel.cachyos.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Boot the CachyOS kernel instead of the one nixpkgs would pick.

      Mainline Linux with CachyOS's patch set and their kconfig, taken
      prebuilt from the `nix-cachyos-kernel` flake input. The default variant
      is BORE — see `local.kernel.cachyos.variant` for what that means and
      what else is on offer.

      Off by default because it is a third-party kernel from a third-party
      binary cache, and neither is something to hand a host that has no use
      for it. A machine that is not gaming gains close to nothing here and
      takes on both.

      **A kernel change is a reboot, and `nixos-rebuild test` cannot help.**
      The way back is the previous generation in the boot menu, so switch
      this on a rebuild you can reboot into and watch — and note that a
      kernel the driver won't build against fails at build time, before
      anything is activated, which is the failure mode you want.
    '';
  };

  options.local.kernel.cachyos.variant = lib.mkOption {
    type = lib.types.enum [
      "bore"
      "bore-lto"
      "bore-x86_64-v3"
      "bore-lto-x86_64-v3"
      "bore-x86_64-v4"
      "bore-lto-x86_64-v4"
      "bore-zen4"
      "bore-lto-zen4"
      "latest"
      "latest-lto"
      "lts"
      "lts-lto"
    ];
    default = "bore";
    description = ''
      Which CachyOS kernel to boot. Names the suffix of a
      `linuxPackages-cachyos-*` attribute in the flake input; only read when
      `local.kernel.cachyos.enable` is on.

      "bore" is the default and the one this repo is set up around. BORE —
      Burst-Oriented Response Enhancer — sits on top of the fair scheduler
      and tracks how bursty each task has been, so short bursty work (a
      render thread waking sixty times a second, the compositor, an audio
      thread) is preferred over a long-running batch job holding the same
      nice value. That is the whole of what it changes, and it is why the
      variant is worth having on a machine that plays games while something
      else compiles.

      The "-lto" half of each pair is built with Clang and ThinLTO, which is
      what upstream CachyOS ships by default and is worth trying once the
      plain build has proven itself. Out-of-tree modules follow the kernel's
      compiler automatically — the flake arranges that — so the NVIDIA driver
      and the DDC/CI module still build, they just build with LLVM.

      The "-x86_64-v3", "-x86_64-v4" and "-zen4" variants are compiled for a
      newer instruction set than the x86-64 baseline. They are a real if
      small win and an unbootable machine on a CPU that doesn't have the
      instructions, so check before reaching for one:

          lscpu | grep -o 'avx2\|avx512f'   # v3 wants avx2; v4/zen4 want avx512f

      "latest" and "lts" are the same patch set without the BORE scheduler,
      on mainline's newest and on the long-term branch respectively — "lts"
      being the one to fall back to when a brand-new kernel and the NVIDIA
      driver disagree.

      Every name here is one the flake's Hydra builds and caches. It has more
      — bmq, deckify, eevdf, hardened, rc, rt-bore, server, and an x86_64-v2
      line — which are left out of this list on purpose: some of them are not
      cached at all, and picking an uncached kernel is not a slow rebuild,
      it is an hour of compiling. Adding one is a line in this enum if it
      ever turns out to be wanted.

      Six of them come with a second helping of cache. The flake assembles a
      whole test system — NVIDIA driver, `open = true`, `nvidiaPackages
      .latest`, which is this repo's configuration — for "bore", "latest",
      "lts" and their "-lto" twins, so on those the *driver's kernel module*
      is prebuilt too. Pick one of the CPU-optimised builds instead and the
      kernel is still a download while its NVIDIA module is compiled here:
      ten minutes, not an hour, but it is the difference between the two
      halves of that trade.
    '';
  };

  options.local.kernel.cachyos.binaryCache.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Add the kernel flake's binary cache to this host's substituters.

      Without it there is no CachyOS kernel to fetch and the machine compiles
      its own, which is the better part of an hour every time the input
      moves. So this is on by default wherever modules/nixos/kernel.nix is
      imported — including when the kernel itself is switched off, so that
      turning it on later isn't a surprise build.

      It is a genuine trust decision and worth reading as one: the public key
      this installs authorises that cache to supply *any* store path the
      machine asks for, not only kernels. The alternative is `false` and a
      long build on every kernel update; there is no third option that keeps
      both.

      This is the permanent half. It only takes effect once a rebuild has
      installed it, and the daemon running *that* rebuild is still on the old
      configuration — so the switch that first brings in the kernel would
      compile one regardless. The `nixConfig` block at the top of flake.nix
      is what covers that gap: nix reads it off the flake it is building,
      before any of this exists, and asks once per user before honouring it
      (`--accept-flake-config` on the rebuild skips the question).

      The two have to agree, and nothing checks that they do — a flake's
      `nixConfig` is read before the module system exists, so it cannot be
      derived from this option. Changing the cache means editing both.
    '';
  };

  options.local.power.noAutoSleepOnAC = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Never suspend on an idle timer while the machine is on mains power.
      Battery behaviour is untouched.

      Implemented as a logind *idle* inhibitor held for as long as a mains
      supply is online — see modules/nixos/power.nix. That blocks the
      automatic, timer-driven path only: `systemctl suspend`, the session
      menu's "Suspend" and the lid switch all still work, which a `sleep`
      inhibitor would have broken.

      Locking, dimming and blanking are unaffected. Those are separate
      timers (swayidle under niri, powerdevil under Plasma) and "don't fall
      asleep" is not "don't lock the screen".

      Whether the machine counts as on mains is read from
      /sys/class/power_supply. A machine with no battery at all is always
      on mains, so the inhibitor simply stays up on the desk and the
      server.
    '';
  };

  # RGB lighting. The daemon and the resume hook are modules/nixos/openrgb.nix;
  # the session-side half — the tray applet niri starts at login — reads the
  # profile name from here through `osConfig`, so the two can't drift.
  options.local.openrgb.profile = lib.mkOption {
    type = lib.types.str;
    default = "Main";
    example = "Off";
    description = ''
      Name of the OpenRGB profile the session applies at login and the
      machine re-applies after resume, without the `.orp` extension.

      Profiles are made from OpenRGB's own UI ("Save Profile") and live in
      ~/.config/OpenRGB, under the account named by
      `local.desktop.primaryUser`. They are runtime state, not something this
      repo writes — which also means the name is a filename and is
      case-sensitive: "Main" and "main" are two different profiles, and
      OpenRGB will tell you it failed to load the one that doesn't exist.

      Naming a profile that hasn't been saved yet is harmless. The login
      spawn prints "Profile failed to load" and still leaves you a tray icon;
      the resume service checks for the file first and does nothing.
    '';
  };

  options.local.openrgb.autostart = lib.mkOption {
    type = lib.types.bool;
    default = config.services.hardware.openrgb.enable;
    defaultText = lib.literalExpression "config.services.hardware.openrgb.enable";
    description = ''
      Start OpenRGB's tray applet with the niri session and apply
      `local.openrgb.profile`. Read by home/joshr/niri/niri.nix through
      `osConfig`; Plasma has its own autostart handling and ignores this.

      The default follows the daemon, which is only enabled on the hosts that
      import modules/nixos/gaming.nix. That is the desk, which has RGB
      hardware worth driving, and not the laptop, where the applet would cost
      a tray icon, a Qt process and a failed profile load every session for
      nothing to talk to.

      Off only stops the applet starting itself. Where the daemon is enabled
      it keeps running and `openrgb` stays on PATH, so launching it by hand —
      for a keyboard or mouse plugged into a dock, say — still works. Where
      the daemon isn't enabled, which is the usual reason this is off, the
      package isn't installed either: it arrives with the daemon's module.
    '';
  };

  options.local.openrgb.applyOnResume = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Re-apply `local.openrgb.profile` after the machine wakes from suspend or
      hibernate. See modules/nixos/openrgb.nix.

      On by default because the lighting does not survive a sleep on its own.
      RGB controllers hold whatever was last written to them and no further:
      suspend cuts their power, USB ones are re-enumerated on the way back and
      the ones on the board come back on their firmware default, so a machine
      that has slept once is wearing the factory rainbow until the next login
      applies the profile again.

      Turning this off leaves that behaviour — it doesn't restore anything
      else. The only reason to is if something else on the machine has taken
      over the lighting and you'd rather this didn't argue with it.
    '';
  };

  options.local.backlight.ddcci.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Control external monitors' brightness over DDC/CI, by loading the
      out-of-tree ddcci-backlight driver. See modules/nixos/ddcci.nix.

      This is what makes brightnessctl — and anything else that drives
      `/sys/class/backlight` — work on a machine with no internal panel. Each
      monitor that answers DDC/CI gets a `ddcci*` backlight device, and the
      existing keybinds and idle dim then apply to it with no changes.

      Off by default because it is an out-of-tree kernel module, and because
      on a laptop it would add a second set of backlight devices whenever an
      external monitor is plugged in — which is only useful if you actually
      want the external displays following the brightness keys too.

      A monitor that ignores DDC/CI, or has it switched off in its OSD, simply
      doesn't get a device. Nothing else breaks.
    '';
  };

  options.local.backlight.ddcci.busNameMatch = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "NVIDIA i2c adapter*"
      "AMDGPU DM*"
      "Radeon i2c*"
      "i915 gmbus*"
    ];
    description = ''
      I2C adapter names to look for monitors on, as udev `ATTR{name}` globs.
      Only meaningful when `local.backlight.ddcci.enable` is on.

      Adapters are matched by name rather than probing every bus on the
      machine on purpose. A desktop's i2c buses are mostly *not* displays —
      they are SMBus segments carrying RAM SPD, fan controllers and RGB
      hardware — and this box already runs with `acpi_enforce_resources=lax`
      (hosts/gamestation/kernel-params.nix) so that OpenRGB can reach some of
      them. Sending display queries to those is not a thing worth doing on a
      timer at every boot.

      Note that these are the *display* adapters of each driver, not every bus
      the GPU exposes — an AMD card's "AMDGPU SMU" bus is RGB and telemetry,
      not a monitor, and is deliberately not in the list.

      If a monitor isn't picked up, get the real adapter names off the machine
      and add the one it is on:

          cat /sys/bus/i2c/devices/i2c-*/name
          ddcutil detect
    '';
  };

  options.local.sddm.theme = lib.mkOption {
    type = lib.types.enum [
      "stock"
      "astronaut"
    ];
    default = "stock";
    description = ''
      Which greeter SDDM draws.

      "stock" sets no theme at all, so SDDM uses its own built-in greeter:
      no external theme package, no QML of ours, no runtime state pointing
      at it. Almost nothing in that path is our code, which is exactly why
      it is the default.

      "astronaut" is the themed one — an sddm-astronaut build per palette,
      following the desktop's theme and wallpaper through a system service.

      The themed greeter left the primary display black on this machine.
      That happened under kwin_wayland, under weston and under X11 alike,
      with the display-server layer producing no errors at all: SDDM logged
      "Greeter session started successfully" and the greeter connected. Three
      different display servers failing identically points away from all of
      them and at the one component they share, which is the theme.

      So "stock" is both the fallback and the experiment. If the login screen
      works here, the theme was at fault and can be rebuilt more carefully.
      If it is still black, the cause is somewhere neither the compositor nor
      the theme, and the next thing to suspect is SDDM's multi-monitor
      handling itself.
    '';
  };

  options.local.sddm.wayland = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Run SDDM's Wayland greeter. False uses the X11 greeter instead, which
      starts an X server for the sole purpose of drawing the login screen.

      The niri session is Wayland either way — this is only about the greeter.

      True by default because X11 was tried against the black primary display
      and behaved exactly like the two Wayland compositors, which is what
      ruled the display server out as the cause. It stays an option because
      it is one line to flip and worth a try if the greeter breaks again.
    '';
  };

  options.local.sddm.compositor = lib.mkOption {
    type = lib.types.enum [
      "kwin"
      "weston"
    ];
    default = "kwin";
    description = ''
      Which compositor SDDM's Wayland greeter runs under.

      Back to NixOS's default of kwin. weston was tried against the black
      primary display and made no difference, which — together with X11
      behaving the same way — is what ruled the compositor out.

      Kept as an option because it is a cheap thing to vary if the greeter
      misbehaves again. To leave Wayland entirely, set
      `services.displayManager.sddm.wayland.enable = false` for the X11
      greeter; the niri session stays Wayland regardless.
    '';
  };

  # Single GPU passthrough — the machine's only graphics card, lent to a guest
  # and taken back afterwards. The libvirt hook that does the lending is
  # modules/nixos/gpu-passthrough.nix, which is where the mechanics are
  # written down; these are the knobs.
  options.local.virtualisation.singleGpuPassthrough.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Install the libvirt hook that hands this machine's only GPU to a guest
      while it runs, and puts the host back together when it stops.

      Ordinary VFIO passthrough gives a *second* card to a VM: the host never
      wants it, so it is bound to vfio-pci in the initrd and nothing else has
      to happen. With one card the host is using it — greeter, compositor,
      framebuffer console — and all of that has to let go first. So starting
      one of these guests **logs you out**, and the screen stays dark until
      the guest drives the monitor itself. Shutting the guest down brings the
      greeter back. That is inherent to one card and two operating systems,
      not a rough edge of the implementation.

      On its own this does nothing: the hook only fires for the domains named
      in `local.virtualisation.singleGpuPassthrough.vms`, and a rebuild warns
      if that list is empty. It also needs libvirtd — import
      modules/nixos/virtualization.nix on the host — and an IOMMU, which on
      the desk is `amd_iommu=on iommu=pt` in
      hosts/gamestation/kernel-params.nix.
    '';
  };

  options.local.virtualisation.singleGpuPassthrough.vms = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "win11" ];
    description = ''
      Which guests may take the GPU, by libvirt domain name — the names
      `virsh list --all` prints, which are also what virt-manager shows in its
      list. Anything not named here starts and stops as an ordinary VM and the
      hook returns immediately.

      This is a list rather than "every domain with a `<hostdev>`" because the
      cost of being wrong is asymmetric. A guest that shouldn't have the card
      but is treated as though it should takes the desktop down with it on
      every boot of that VM; a guest that should have it and isn't listed just
      fails to get a display, with the session still there to fix it in.

      A name that doesn't match any domain is harmless — no domain, no hook —
      so renaming a VM in virt-manager makes passthrough stop happening rather
      than start happening to the wrong guest.
    '';
  };

  options.local.virtualisation.singleGpuPassthrough.pciDevices = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [
      "0000:0b:00.0"
      "0000:0b:00.1"
    ];
    description = ''
      PCI functions to bind to vfio-pci, in the kernel's
      `domain:bus:slot.function` form. Empty — the default — reads them out of
      the domain XML libvirt hands the hook on stdin, so the card is written
      down once, in the VM, instead of twice.

      Set it when the automatic reading is wrong or not wanted: a guest whose
      `<hostdev>` list mixes the GPU with a USB controller you'd rather the
      hook left alone, or a card whose audio function has to move even though
      the guest doesn't ask for it.

      `lspci -nnk` names them; a GPU is normally at least two — the video
      function and its HDMI/DP audio — and everything in one IOMMU group has
      to travel together. `find /sys/kernel/iommu_groups -type l` prints the
      groups.
    '';
  };

  options.local.virtualisation.singleGpuPassthrough.hostDriverModules = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default =
      if lib.elem "nvidia" config.services.xserver.videoDrivers then
        [
          "nvidia_drm"
          "nvidia_modeset"
          "nvidia_uvm"
          "nvidia"
        ]
      else
        [ "amdgpu" ];
    defaultText = lib.literalExpression ''
      the NVIDIA stack when services.xserver.videoDrivers contains "nvidia",
      otherwise [ "amdgpu" ]
    '';
    description = ''
      Kernel modules to unload before the guest starts, in the order they come
      out. They go back in the reverse order afterwards.

      Order is the whole content of this option. `nvidia` will not unload
      while `nvidia_drm` is loaded on top of it, so the list runs from the
      most dependent module to the least — and reversing it on the way back
      means loading the bottom of the stack first, which is also what a bare
      `modprobe nvidia_drm` would pull in anyway.

      Getting this wrong looks like a guest that refuses to start with the
      hook logging "could not unload the host GPU driver", and the desktop
      coming straight back — the hook undoes its own work before failing.
    '';
  };

  options.local.virtualisation.singleGpuPassthrough.stopServices = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "ollama.service" ];
    description = ''
      Extra systemd units to stop before the GPU is taken, and start again
      after it comes back. `display-manager.service` is always handled and
      doesn't belong here.

      This is for the things that hold the card without being the desktop: a
      local model runner, a transcoding daemon, a container that was started
      with the GPU passed in. Anything with an open handle to /dev/nvidia* or
      /dev/dri/* keeps the driver loaded, and the hook's five attempts to
      unload it will all fail — with the useful consequence that the VM
      refuses to start rather than the machine ending up in a state where
      neither side has a display.

      Only units that were actually running get stopped, and only those get
      started again, so naming a unit that is off costs nothing.

      modules/nixos/ai.nix adds its own units to this list when it is enabled,
      so the local model server doesn't have to be written down here as well.
    '';
  };

  # Local AI. The model runner, a chat window for it and an agent, all on
  # loopback — modules/nixos/ai.nix is where the mechanics are written down
  # and these are the knobs. "Local AI" in MANUAL.md is the prose version.
  options.local.ai.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Run large language models on this machine.

      This is the switch the three sub-sections below follow. On its own it
      brings up ollama and Open WebUI — a model server on 127.0.0.1:11434 and
      a browser chat window on 127.0.0.1:8080, neither of which talks to
      anything off this box. The agent (`local.ai.openclaw`) is the one part
      that does *not* follow it, and has to be turned on by name.

      Off by default because it is not free to have: models are gigabytes on
      disk, and on an NVIDIA machine the first rebuild after this compiles
      ollama against CUDA locally, because cache.nixos.org doesn't carry that
      build. See `local.ai.ollama.acceleration`.
    '';
  };

  options.local.ai.ollama.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.local.ai.enable;
    defaultText = lib.literalExpression "config.local.ai.enable";
    description = ''
      Run ollama, the model server everything else here points at.

      It listens on 127.0.0.1 only. `ollama` is also on PATH and talks to the
      running server over that socket, so `ollama run <model>` in a terminal
      and `ollama pull` both work without this module having to grant anything
      — they are HTTP clients, not a second copy of the server.

      Turn it off to keep Open WebUI or the agent while pointing them at a
      model server somewhere else; the wiring this module does for them is
      then yours to write.
    '';
  };

  options.local.ai.ollama.acceleration = lib.mkOption {
    type = lib.types.enum [
      "auto"
      "cuda"
      "rocm"
      "vulkan"
      "cpu"
    ];
    default = "auto";
    description = ''
      Which ollama build to install, and therefore what does the arithmetic.

      "auto" reads `services.xserver.videoDrivers`: nvidia gives `ollama-cuda`,
      amdgpu gives `ollama-rocm`, and anything else gives `ollama-cpu`. A
      machine that has already named its driver once doesn't have to name it
      again here.

      **The accelerated builds are not in the binary cache.** Hydra doesn't
      build against unfree CUDA or against ROCm's closure, so the first
      rebuild after enabling this compiles ollama on this machine — tens of
      minutes, once, and again after a nixpkgs bump that moves it. That is the
      cost of the default, not a fault in it: on the desk's card the
      difference between "cuda" and "cpu" is roughly the difference between a
      conversation and a progress bar.

      "cpu" is the honest way to try the rest of this module in the meantime;
      it builds from cache and small models are usable, if slow. "vulkan" is
      the escape hatch for a GPU neither of the vendor stacks likes.
    '';
  };

  options.local.ai.ollama.port = lib.mkOption {
    type = lib.types.port;
    default = 11434;
    description = ''
      Where ollama listens, on 127.0.0.1.

      Worth knowing before changing it: OpenClaw's bundled Ollama provider
      only *discovers* a server on the default 11434. Move the port with
      `local.ai.openclaw` enabled and a rebuild warns, with the two commands
      that teach the agent the new address.
    '';
  };

  options.local.ai.ollama.models = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [
      "qwen3"
      "qwen3:32b"
      "nomic-embed-text"
    ];
    description = ''
      Models to pull once ollama is up, by their name in
      <https://ollama.com/library>. A bare name is that model's default tag,
      which is usually its smallest sensible size; `name:tag` picks one.

      This is a *download* list, not a build input. `ollama-model-loader.service`
      fetches them in the background after the server starts, so a rebuild
      doesn't wait on gigabytes and a machine that is offline at the time
      retries with a backoff rather than failing the activation. The weights
      never enter the Nix store — they live under /var/lib/ollama and are not
      what `nix-collect-garbage` collects.

      An empty list is a working server with nothing in it, which is a fine
      place to start: `ollama pull <model>` from a terminal does the same
      thing imperatively, and the ones worth keeping can be written down here
      afterwards.

      If the agent is going to use one of these, it needs a model that
      supports *tool calling* and has a context window of at least 16K —
      OpenClaw checks for both, and a model that can only chat will look
      broken rather than limited. The qwen and llama families advertise tools;
      several otherwise excellent small models do not.
    '';
  };

  options.local.ai.ollama.pruneUndeclaredModels = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Delete any model that isn't in `local.ai.ollama.models`, on every start
      of the loader service.

      Off by default because the models directory is state, not a build
      product, and the usual way to meet a model is to pull it by hand and
      decide afterwards. Turning this on makes the list above authoritative —
      useful when disk is tight and the answer to "what is in here?" should be
      readable from this file, expensive when the answer costs a re-download.
    '';
  };

  options.local.ai.webui.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.local.ai.enable;
    defaultText = lib.literalExpression "config.local.ai.enable";
    description = ''
      Run Open WebUI, a browser chat window for the local models, on
      127.0.0.1.

      It is pointed at ollama automatically when that is enabled. The first
      visit asks for an account; that account is local to this machine, lives
      in a SQLite file under /var/lib/open-webui, and is what keeps a stray
      browser tab from talking to the models. `WEBUI_AUTH = "False"` in
      `extraEnvironment` removes it if the prompt is more ceremony than a
      single-user desktop wants.
    '';
  };

  options.local.ai.webui.port = lib.mkOption {
    type = lib.types.port;
    default = 8080;
    description = ''
      Where Open WebUI listens, on 127.0.0.1. 8080 is a popular port; move it
      if something else on this machine wants it.
    '';
  };

  options.local.ai.webui.extraEnvironment = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    example = {
      WEBUI_AUTH = "False";
      ENABLE_WEB_SEARCH = "True";
    };
    description = ''
      Extra environment for Open WebUI, merged over what this module sets and
      winning where the two collide. The full list of names is at
      <https://docs.openwebui.com/getting-started/env-configuration>.

      What this module sets, and would therefore be overriding: telemetry off
      (three variables), `ENABLE_OPENAI_API = "False"`, and `OLLAMA_BASE_URL`
      pointing at the local server.

      Secrets don't belong here — this ends up in the unit file, which is
      world-readable in the store. `services.open-webui.environmentFile` takes
      a path for those.
    '';
  };

  options.local.ai.openclaw.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Run the OpenClaw gateway: an agent that holds sessions, tools and chat
      channels, with a control UI on http://127.0.0.1:18789.

      **This one does not follow `local.ai.enable`, and the reason is worth
      reading.** A model server answers questions. An agent acts: it reads and
      writes files, runs commands, and does so on the basis of text that
      arrived from somewhere else — a message, a web page, a document it was
      handed. There is no reliable way to keep instructions in that text from
      being followed. nixpkgs states this in the package itself, as a
      `knownVulnerabilities` entry, which means a plain rebuild *refuses to
      install it*; modules/nixos/ai.nix disarms that check by name for this
      one package, so switching this on is the moment that decision gets made.

      What limits the damage here is the account boundary and nothing else.
      The gateway runs as `local.ai.openclaw.user` — not as root, not as a
      daemon user with a sandbox, because the assistant's whole purpose is
      that account's files and tools. Assume anything that user can do, this
      can be talked into doing.

      It listens on loopback and this module opens no firewall port. Reaching
      it from a phone is a `tailscale serve` decision to make deliberately,
      after reading <https://docs.openclaw.ai/gateway/security>.
    '';
  };

  options.local.ai.openclaw.user = lib.mkOption {
    type = lib.types.str;
    default = config.local.desktop.primaryUser;
    defaultText = lib.literalExpression "config.local.desktop.primaryUser";
    description = ''
      Whose assistant it is. The gateway runs in this account's systemd user
      manager, and keeps its config, token, workspace and session history in
      that account's ~/.openclaw.

      One account, not a list: the config, the chat channels and the memory
      are all singular, and two people sharing them would be sharing an inbox
      rather than each having an assistant. A second person wants a second
      gateway on a second port, which this option doesn't express — the unit
      in modules/nixos/ai.nix would have to be written per user for that.

      A rebuild fails if the name isn't an account on this machine; the unit
      is generated for every user manager on the box and selected with
      systemd's `ConditionUser=`, so a name with no home directory would
      simply never start and never say why.
    '';
  };

  options.local.ai.openclaw.port = lib.mkOption {
    type = lib.types.port;
    default = 18789;
    description = ''
      Where the gateway listens, on 127.0.0.1 — the WebSocket and the control
      UI share the one port.

      Passed on the command line rather than written into OpenClaw's config
      file, so this option stays authoritative. The config file is seeded once
      and then belongs to OpenClaw (see `local.ai.openclaw.model`); a port
      living in there would be a copy that quietly stopped matching.
    '';
  };

  options.local.ai.openclaw.model = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "ollama/qwen3";
    description = ''
      The model the agent thinks with, as `provider/model`. `ollama/<name>`
      is the local server; the name has to be one ollama actually has, so it
      belongs in `local.ai.ollama.models` too.

      **Read once, at first start, and never again.** OpenClaw owns
      ~/.openclaw/openclaw.json — its control UI writes to that file, its CLI
      writes to that file, and the gateway reloads it while running — so this
      module seeds the file when it is missing and then keeps its hands off.
      Changing this option later is a no-op. The way to change the model on a
      machine that has already started once is:

          openclaw models set ollama/<model>

      null leaves the model out of the seed entirely, which is the right
      choice if `openclaw onboard` is going to be run by hand: it picks a
      provider and a model interactively and writes them itself.
    '';
  };

  options.local.ai.openclaw.linger = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Keep the gateway running when nobody is logged in.

      Off by default, which means the assistant is up while its account has a
      session and gone otherwise. That is the honest shape for something on a
      desktop: it is there when you are.

      On means `loginctl enable-linger` for that account — the user manager
      starts at boot and survives logout, so a message sent from a phone at
      midday reaches a machine nobody has touched. It also means an agent with
      a shell running unattended, which is a different risk than one running
      behind an unlocked session. Worth it for a machine you actually message;
      not worth it for one you sit at.
    '';
  };

  options.local.ai.openclaw.environmentFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    example = "/var/lib/secrets/openclaw.env";
    description = ''
      A systemd `EnvironmentFile` for the gateway — provider API keys for
      anything that isn't the local model server, in `NAME=value` lines.

      This is for a file something *else* manages: a secrets tool, a path
      outside the home directory, something restored from a backup. A missing
      file is not an error, so it can be named before it exists.

      The other place credentials can go is ~/.openclaw/gateway.env, which the
      service creates on first start to hold the generated gateway token and
      then sources on every start. Anything added to that file by hand is
      picked up the same way. Use whichever suits: this option when the file
      belongs to the system, that file when it belongs to the person.

      Either way it is a path, read at start — nothing is copied into the Nix
      store, and neither file's contents appear in the unit.
    '';
  };

  # Gaming — modules/nixos/gaming.nix. "Gaming performance" in MANUAL.md is
  # the prose version, including how to tell the failure modes apart.
  options.local.gaming.steamInputOnWayland = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Give Steam Input a way to move the *real* pointer in a Wayland session,
      by preloading extest into Steam.

      This is the fix for the one symptom that makes a controller look broken
      rather than unconfigured: the trackpad or stick moves something, the
      Steam UI reacts to it, and the cursor on screen never goes anywhere.
      There are two pointers, and only one of them is drawn.

      Steam is an X11 program. Its desktop-level mouse emulation — the
      Desktop Layout, the Big Picture cursor, the chord that turns the right
      pad into a mouse — is implemented with the X11 XTEST extension, which
      is a request to the X server to *pretend* an input device did
      something. Under a Wayland session there is no X server that owns the
      pointer: Steam is an Xwayland client, XTEST moves Xwayland's own idea of
      where the cursor is, and the compositor — which draws the cursor and
      decides which surface gets the click — is never told. X11 windows react
      to the phantom, Wayland windows ignore it entirely, and nothing moves.

      extest is a small library that replaces those XTEST entry points at load
      time and, instead of asking an X server for a fake event, creates a
      virtual input device through /dev/uinput and moves *that*. A uinput
      device is a real device as far as the kernel and the compositor are
      concerned, so the cursor it drives is the one on screen, over every
      window, X11 or Wayland or the shell's own panels.

      `programs.steam.extest.enable` is what this switches on; nixpkgs sets
      `LD_PRELOAD` to the 32-bit build in Steam's own environment, so it
      reaches Steam and the game processes it starts and nothing else on the
      machine. Two things it needs are already true here and worth knowing
      about, because they are what breaks first: `/dev/uinput` has to exist
      and be writable, which `hardware.steam-hardware.enable` arranges (it
      loads the uinput module and installs Valve's udev rules, which tag the
      node `uaccess` so the logged-in user gets an ACL on it), and every
      interactive account here is in the `input` group as a second route to
      the same permission. `gaming-doctor` prints all of it.

      The cost is a line of noise. The preload is a 32-bit library because
      Steam is a 32-bit program, so every 64-bit process Steam starts — which
      is most games — has the dynamic linker print `ERROR: ld.so: object
      libextest.so ... cannot be preloaded ... ignored` and carry on. It is
      ugly and it is harmless.

      This covers both generations of the controller, because both reach the
      pointer the same way. It does not cover a pad Steam never drives at
      all, and the 2026 controller has a Valve-side bug that can put it in
      that state — Steam misidentifies it as Steam Deck hardware and its
      registration fails
      (https://github.com/ValveSoftware/steam-for-linux/issues/13185). The
      tell is that with extest loaded there is still no `extest fake device`
      in /proc/bus/input/devices after moving the pad: no XTEST is being
      issued, so there is nothing to translate.

      The way out of that one is Steam's own settings rather than anything
      here — turning Steam Input off for that controller stops Steam claiming
      the hidraw node, and the pad falls back to its firmware's lizard mode,
      where it is a plain USB mouse and keyboard and no compositor has an
      opinion about it. It costs that pad its gamepad, which is not a small
      thing: `hid-steam`'s device table is the 2015 controller, its dongle and
      the Steam Deck (`steam_controllers[]` in drivers/hid/hid-steam.c), so
      the 2026 pad has no kernel driver to synthesise one and Steam's virtual
      gamepad is the only one it ever had. The 2015 pad is not in that
      position — the kernel driver restores its lizard mode by itself as soon
      as Steam lets go.

      There is no option here for taking the hidraw node away from Steam in
      udev instead. It would work, and it would trade a pad's whole purpose
      for its pointer — a decision that belongs in a settings panel where it
      can be undone in a second, not in a rebuild.

      `gaming-doctor` prints the table this is all read from: every Valve HID
      device, its product id, which driver claimed it, and which process has
      its hidraw node open.
    '';
  };

  options.local.gaming.splitLockMitigate = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Leave the kernel's split-lock "misery mode" on.

      A split lock is an atomic instruction whose operand straddles two cache
      lines. The CPU can only do it by locking the whole memory bus for the
      duration, which stalls every other core, so the kernel detects them and
      — by default — punishes the offending thread: it is forced to sleep,
      and the check is serialised behind a global semaphore so only one such
      thread runs at a time. That is the misery mode, and the name is
      upstream's own.

      It is the right default for a shared machine and the wrong one for this
      one. Plenty of Windows games do split locks in their hot path, and under
      Proton the penalty lands on the render thread: the game does not fail,
      it hitches, in bursts, in a way that looks exactly like a GPU problem
      and is not one. It was widely enough hit that Linux 6.2 gained
      `kernel.split_lock_mitigate` specifically so it could be turned off
      (https://www.phoronix.com/news/Linux-Splitlock-Hurts-Gaming).

      Off, the kernel still detects split locks and still logs them — it just
      stops sleeping the thread that did one. What is given up is protection
      against a local program degrading the machine for everything else by
      doing them deliberately, which is a real consideration on a shared
      server and not one here.

      True restores the kernel default. On a CPU with no split-lock or
      bus-lock detection the sysctl does not exist and systemd-sysctl logs
      that it skipped it, either way.
    '';
  };

  options.local.gaming.releaseGpuOnGameMode = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Unload the local model server's weights from video memory when a game
      takes gamemode, so the game starts on a card that isn't already half
      full.

      This only does anything on a host that runs both — `services.ollama`
      and `programs.gamemode` on one machine, which here is
      `gamestation-niri`. Elsewhere it is inert.

      ollama holds a model in VRAM for five minutes after the last request
      and reloads it on the next one, so on a machine that is both the desk
      and the model server the card can be carrying eight or nine gigabytes
      of weights that nobody is using. A game started into that has less
      video memory than the card has, and NVIDIA's Linux driver does not
      degrade gracefully when it runs out — it evicts to system memory and
      the frame rate falls off a cliff and stays there. That it can happen
      *mid-game*, because an agent or a chat window asked a question while
      you were playing, is what makes it look like the machine gets slower
      the longer you play.

      There is no matching end hook and there shouldn't be: ollama loads a
      model on demand, so the next request after the game brings the weights
      straight back. This only takes the card back, it doesn't keep it.

      What it took is attached to the "GameMode started" notification —
      `released deepseek-r1:14b (8.9 GiB)`, one line per model, and a
      differently worded line for a model that refused to unload. Since none
      of this is driven from the chair, the notification is the only thing
      that connects a session that ran badly to the reason it did. An
      ordinary launch, with nothing resident, notifies exactly as it did
      before.
    '';
  };

  # The headless NVIDIA card — modules/nixos/nvidia-server.nix, which is where
  # the mechanics are written down and these are the knobs. "The NVIDIA
  # server" in MANUAL.md is the prose version.
  #
  # Nothing else reads them. modules/nixos/nvidia.nix — the desktop driver,
  # imported by the two gamestation hosts — pins its own package and settings
  # and is unaffected by anything below.
  options.local.nvidia.driver = lib.mkOption {
    type = lib.types.enum [
      "production"
      "stable"
      "beta"
      "latest"
    ];
    default = "production";
    description = ''
      Which `boot.kernelPackages.nvidiaPackages.*` channel to install.

      "production" rather than the desktop's "latest" for two reasons that
      point the same way on a machine nobody is sitting at: it is the branch
      NVIDIA supports for longest, and it is old enough that
      nvidia-patch's offset table has certainly caught up with it. "latest"
      regularly lands a driver the patch has never seen, which costs the
      encoder unlock — see `local.nvidia.patch.enable`.

      "stable" is the middle, "beta" is for a card so new the other branches
      don't drive it. Anything outside the four — a datacenter driver for a
      Tesla, a `legacy_*` for a card NVIDIA has dropped — goes in
      `local.nvidia.package` instead.
    '';
  };

  options.local.nvidia.package = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    example = lib.literalExpression "config.boot.kernelPackages.nvidiaPackages.dc_580";
    description = ''
      The driver package outright, ignoring `local.nvidia.driver`.

      For the branches that option can't name: `dc_*` for a datacenter card,
      `legacy_470` and friends for one NVIDIA no longer builds a current
      driver for. The patch is still applied to whatever is named here, if
      the offset table knows its version.

      This is the option to reach for rather than setting
      `hardware.nvidia.package` in the host — that one is written by
      modules/nixos/nvidia-server.nix, and a second definition either
      conflicts or (with `lib.mkForce`) quietly discards the patch.
    '';
  };

  options.local.nvidia.open = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Use NVIDIA's open kernel modules instead of the proprietary ones.

      True needs Turing (RTX 20xx, GTX 16xx) or newer. Older silicon — the
      Pascal cards that make up most of the second-hand transcoding boxes,
      P4, P40, GTX 10xx — has no open module at all, and a rebuild with this
      on produces a driver that will not load. Set it to false there.

      It has no bearing on the patch either way. That edits userspace
      libraries the two kernel modules share.
    '';
  };

  options.local.nvidia.persistenced = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Run nvidia-persistenced, which holds the driver initialised when no
      process is using the card.

      On by default here and off on a desktop, because a desktop always has a
      client — the display server — and a headless box usually has none. Each
      job that arrives at an unpersisted card pays for a full initialisation,
      the clocks fall back to idle between jobs, and settings that only exist
      in persistence mode revert in the gaps.
    '';
  };

  options.local.nvidia.containerToolkit = lib.mkOption {
    type = lib.types.bool;
    default = config.virtualisation.docker.enable;
    defaultText = lib.literalExpression "config.virtualisation.docker.enable";
    description = ''
      Install the NVIDIA container toolkit, so a container can be handed the
      card:

          docker run --rm --device=nvidia.com/gpu=all <image> nvidia-smi

      Follows Docker — which on these hosts means it follows whether
      modules/nixos/development.nix is imported — because the toolkit's only
      job is injecting this driver into containers, and there is nothing to
      inject into otherwise.

      That device name is a CDI spec, generated at boot and regenerated by a
      udev rule. The older `--gpus all` spelling wants a runtime wrapper that
      only arrives with the deprecated `virtualisation.docker.enableNvidia`;
      modules/nixos/nvidia-server.nix turns Docker's CDI support on instead.
    '';
  };

  options.local.nvidia.patch.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Apply <https://github.com/keylase/nvidia-patch> to the installed
      driver, via the `nvidia-patch` flake input.

      It removes two limits that GeForce cards carry in software rather than
      in silicon: the cap on simultaneous NVENC encode sessions (three or
      five, depending on the driver — the one that decides how many streams a
      transcoding server can serve), and the refusal to do NvFBC
      whole-framebuffer capture on anything that isn't a Quadro.

      The mechanism is a `sed` over the shipped `libnvidia-encode.so` and
      `libnvidia-fbc.so`, run on this machine, keyed to the exact driver
      version. Two consequences worth knowing about are in the header of
      modules/nixos/nvidia-server.nix: it edits a binary NVIDIA ships, and it
      makes the driver a local build rather than a cache hit.

      A driver the offset table doesn't cover warns and installs unpatched —
      `local.nvidia.patch.required` for a host where that should stop the
      rebuild instead.
    '';
  };

  options.local.nvidia.patch.nvenc = lib.mkOption {
    type = lib.types.bool;
    default = config.local.nvidia.patch.enable;
    defaultText = lib.literalExpression "config.local.nvidia.patch.enable";
    description = ''
      Patch the encoder session limit specifically.

      This is the half a transcoding server is here for. Unpatched, the
      fourth or sixth concurrent encode fails with "OpenEncodeSessionEx
      failed: out of memory (10)" while the card is barely warm.
    '';
  };

  options.local.nvidia.patch.fbc = lib.mkOption {
    type = lib.types.bool;
    default = config.local.nvidia.patch.enable;
    defaultText = lib.literalExpression "config.local.nvidia.patch.enable";
    description = ''
      Patch the NvFBC restriction specifically.

      Whole-framebuffer capture, which Sunshine, OBS and the remote desktops
      use when it is available and fall back from when it isn't. A headless
      machine with no session to capture has little use for it; it costs
      nothing to leave on, and it is the half that matters if this box ever
      streams a virtual display.
    '';
  };

  options.local.nvidia.patch.required = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Fail the rebuild when the patch can't be applied, instead of warning
      and installing a capped driver.

      Off by default: an unpatchable driver is a working machine with a
      limit, and stopping a rebuild over it is the wrong trade on most
      hosts. Turn it on where the limit is an outage — a box whose only job
      is serving more concurrent encodes than an unpatched card allows — so
      that a `nix flake update` which moves the driver past the offset table
      is caught at build time rather than at the fourth stream.
    '';
  };
}
