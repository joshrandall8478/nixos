{ config, lib, pkgs, ... }:

# The NVIDIA driver, and what it takes to come back from suspend.
#
# Only the two `gamestation` hosts import this — the laptop has no discrete
# NVIDIA card (hosts/laptop/configuration.nix says so at length), so nothing
# here has to consider Optimus, PRIME or a battery.
#
# This is the *desktop* driver: a card driving monitors, 32-bit libraries for
# Proton, and the suspend dance below. A card in a headless box wants
# modules/nixos/nvidia-server.nix instead — persistence rather than suspend,
# the container toolkit, and the NVENC/NvFBC patch. Import one or the other;
# both write `hardware.nvidia.package`.
#
# Waking up
# ---------
# By default the driver throws video memory away when the machine suspends.
# Nothing warns you: the suspend works, the machine wakes, the fans spin, and
# the session never comes back — the compositor's framebuffers, textures and
# GL/Vulkan contexts all lived in memory the driver no longer has, so niri
# cannot take the GPU back and you get a black screen with a live machine
# behind it (SSH in and `systemctl restart display-manager` is the usual way
# to prove that to yourself).
#
# `powerManagement.enable` is the fix, and it is three things at once:
#
#   * `NVreg_PreserveVideoMemoryAllocations=1` on the nvidia module, which is
#     what tells the driver to save allocations instead of dropping them.
#
#   * nvidia-suspend.service and nvidia-hibernate.service, ordered *before*
#     systemd-suspend.service / systemd-hibernate.service, which write
#     "suspend"/"hibernate" to /proc/driver/nvidia/suspend so the save
#     actually happens while there is still a machine to save from.
#
#   * nvidia-resume.service, ordered *after* both, which writes "resume" and
#     puts the memory back.
#
# All three are `${nvidia_x11}/bin/nvidia-sleep.sh <state>`; nixpkgs
# generates the units. Check them on the machine after a rebuild:
#
#     systemctl list-unit-files 'nvidia-*'
#     cat /proc/driver/nvidia/params | grep PreserveVideoMemoryAllocations
#
# Where the video memory goes
# ---------------------------
# To a file under /tmp — `NVreg_TemporaryFilePath` — sized by how much of the
# card is in use, so gigabytes on a card this size. On this machine /tmp is a
# directory on the root btrfs subvolume (hosts/gamestation/hardware-configuration.nix,
# and nothing here sets `boot.tmp.useTmpfs`), so that is real disk and the
# default is right.
#
# It stops being right the moment /tmp becomes a tmpfs: the "save" would then
# be a copy from RAM to RAM, which doubles the memory a suspend needs and
# makes hibernation impossible. If `boot.tmp.useTmpfs` is ever turned on here,
# point the driver somewhere on disk in the same breath:
#
#     hardware.nvidia.moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # needed for Steam/Proton

    # What `LIBVA_DRIVER_NAME = "nvidia"` further down this file is naming.
    #
    # libva looks up a driver by that name and loads `nvidia_drv_video.so`;
    # nothing in the NVIDIA driver package provides one, so without this the
    # variable names a backend that isn't there and every VA-API probe fails
    # at `vaInitialize`. nvidia-vaapi-driver is the shim that answers it,
    # translating VA-API onto NVDEC.
    #
    # It is 64-bit only on purpose. There is no `extraPackages32` line to
    # match, because the 32-bit consumers of VA-API here are none: browsers
    # and OBS are 64-bit, and a Proton game does not decode video through
    # libva.
    #
    # `NVD_BACKEND` is the knob if decode still refuses — it chooses between
    # reaching the kernel driver directly and going through EGL, and the EGL
    # half has been broken since the 525 series. The default is already
    # `direct`, so nothing sets it here.
    extraPackages = [ pkgs.nvidia-vaapi-driver ];
  };

  hardware.nvidia = {
    # Required for Plasma Wayland sessions.
    modesetting.enable = true;

    # Save and restore video memory across suspend and hibernate. See the
    # header — without this the machine resumes to a black screen.
    powerManagement.enable = true;

    # Keep the three nvidia-{suspend,hibernate,resume} services.
    #
    # This looks redundant and isn't. The driver gained a second mechanism —
    # it registers with the kernel's own PM notifier chain and does the
    # save/restore itself, no systemd units involved — and nixpkgs turns that
    # on *by default* for the open modules on a driver this new. When it is
    # on, the three services above are not generated at all, so a rebuild
    # would leave `systemctl list-unit-files 'nvidia-*'` as empty as it is
    # today and it would look like nothing had changed.
    #
    # False pins the systemd path, which is the older and far more widely
    # travelled of the two. `NVreg_PreserveVideoMemoryAllocations=1` is set
    # either way; the choice is only about who drives the save and restore.
    #
    # To try the newer mechanism, delete this line and rebuild: the nvidia-*
    # units disappear and `NVreg_UseKernelSuspendNotifiers=1` shows up in
    # /proc/driver/nvidia/params instead. It is worth a go if resume is still
    # unreliable with the services in place — it removes an ordering problem
    # rather than working around one.
    powerManagement.kernelSuspendNotifier = false;

    # Runtime D3 for a PRIME offload GPU. Nothing on this machine is offload
    # — the NVIDIA card drives the displays directly — and nixpkgs asserts
    # that this requires `prime.offload.enable`, so it stays off.
    powerManagement.finegrained = false;

    # Turing (RTX 20xx) and newer can use the open kernel module instead.
    # Flip this to `true` if your card supports it.
    open = true;

    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # Stop the driver from throwing the shader cache away.
  #
  # Compiled shaders are cached under ~/.cache/nv, and by default the driver
  # caps that directory at 1 GB — 128 MB before driver 460 — and *wipes* it
  # when it goes over rather than evicting the oldest entries. There is no
  # "prune to N" behaviour to fall back on; it is the whole cache or none of
  # it.
  #
  # A single Proton game's DXVK/VKD3D pipelines run to a few hundred
  # megabytes, so three or four of them is enough to trip that, and what the
  # wipe feels like is not a warning but the next hour of play recompiling
  # pipelines mid-frame. That is the shape of the complaint it answers: fine
  # for a while, hitching later, fine again after the cache has refilled, then
  # hitching again — a sawtooth, not a machine that is simply slow.
  #
  # SKIP_CLEANUP takes the cap off entirely. `__GL_SHADER_DISK_CACHE_SIZE` is
  # the other half of the pair and only moves the same cliff further out, so
  # the choice is really between a cliff and unbounded growth. Unbounded wins
  # here: the directory only gains an entry when something compiles a shader
  # it has never compiled before, so it grows in steps and then stops, and it
  # is a cache — deleting it costs one slow first launch per game.
  #
  #     du -sh ~/.cache/nv        # what it has actually grown to
  #     rm -rf ~/.cache/nv        # safe at any time; rebuilt on demand
  #
  # It has to be set for the whole session rather than in one game's launch
  # options, which is why it is here and not in home/joshr/gaming.nix. The
  # limit is enforced by whichever process happens to be writing, so one GL
  # program started without it — a browser, a screen recorder — trims the
  # cache back under 1 GB behind the game's back and the launch-option
  # version of this achieves nothing.
  environment.sessionVariables = {
    __GL_SHADER_DISK_CACHE = "1";
    __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";

    # Three names for "use NVIDIA's implementation and not Mesa's".
    #
    # None of them is a preference. Each one names a loader that would
    # otherwise *guess* which backend to open, and each guess is wrong in a
    # way that produces a symptom rather than an error message.
    #
    # `GBM_BACKEND` is the one the compositor itself needs, and the reason all
    # three are here rather than in niri's own `environment {}` block: that
    # block sets variables for the processes niri spawns, and niri is not one
    # of them. `environment.sessionVariables` goes through /etc/pam/environment,
    # so it is already set for whatever the greeter starts — the compositor
    # included. GBM is how a Wayland compositor asks for buffers it can scan
    # out, Mesa's libgbm picks a backend from the DRM driver's name, and
    # `nvidia-drm` is the one the driver installs into
    # /run/opengl-driver/lib/gbm. Left to guess, the failure is a session that
    # starts on llvmpipe or does not start at all.
    #
    # `__GLX_VENDOR_LIBRARY_NAME` is libglvnd's, and it is about XWayland
    # rather than about Wayland: every Proton game here is an X11 client (see
    # "The XWayland regression" in MANUAL.md), and glvnd has to decide which
    # vendor's GLX to load for it.
    #
    # `LIBVA_DRIVER_NAME` is libva's, and it is the one with a package behind
    # it — see `hardware.graphics.extraPackages` at the top of this file.
    # Video decode rather than games: a browser playing back h264 or AV1, or
    # OBS encoding it.
    #
    # All three are safe here *because this box has one GPU*. Forcing a GBM
    # backend on a machine with an integrated GPU as well would break every
    # Mesa client on the other card, which is why this lives in the desktop
    # NVIDIA module — imported only by the two gamestation hosts — and not in
    # base.nix or desktop.nix. The laptop, which does have an Intel GPU, never
    # sees it.
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
  };

  environment.systemPackages = with pkgs; [
     nvtopPackages.nvidia
  ];
}
