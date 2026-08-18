{ config, lib, pkgs, ... }:

let
  # ollama's HTTP API, if this host runs one. Both of these are read rather
  # than set — modules/nixos/ai.nix owns the service, this file only wants to
  # know whether there is one and where it listens.
  ollamaHere = config.services.ollama.enable;
  ollamaUrl = "http://127.0.0.1:${toString config.services.ollama.port}";

  # Whether the start hook has a model server to take the card back from. Both
  # halves have to be true — a host with no ollama has nothing to release, and
  # the option is the "my game may interrupt my agent" preference.
  releaseOnGameMode = ollamaHere && config.local.gaming.releaseGpuOnGameMode;

  # Take the card back from the model server when a game starts.
  #
  # ollama keeps a model in video memory for five minutes after the last
  # request (OLLAMA_KEEP_ALIVE), which is the right default for a machine
  # answering questions and the wrong one for a machine also being played on:
  # deepseek-r1:14b is around nine gigabytes that nobody is using by the time
  # the game wants them. Worse, nothing here is user-driven — Open WebUI in a
  # background tab, or the OpenClaw gateway (which lingers, so it is up with
  # nobody logged in) can load a model *while* a game is running, which is
  # what turns this into "the machine gets slower the longer I play" rather
  # than "the machine is slow".
  #
  # `keep_alive: 0` on /api/generate is ollama's documented way to say "drop
  # this now" — no CLI, no privileges, one loopback request per resident
  # model. There is no end hook to match: ollama loads on demand, so the next
  # question reloads whatever it needs by itself.
  #
  # **Stdout is a notification body.** Nothing is printed unless a model was
  # actually holding the card, and what is printed is meant to be read by
  # somebody who was about to play a game rather than by whoever is reading
  # the journal later — the model's name, and how much of the card it had.
  # gamemodeStart below is what puts it on screen.
  releaseGpu = pkgs.writeShellApplication {
    name = "gamemode-release-gpu";

    runtimeInputs = with pkgs; [
      curl
      jq
    ];

    text = ''
      # A server that isn't running, isn't up yet, or has nothing resident is
      # the ordinary case, not a failure — gamemoded logs a non-zero script,
      # and `-s` without `-S` keeps "connection refused" out of its journal
      # too. The unload below keeps `-S`, where a failure is worth reading.
      snapshot=$(curl -fs --max-time 2 "${ollamaUrl}/api/ps") || exit 0

      # name<TAB>GiB, one resident model per line, read once and reused: the
      # sizes have to be taken *before* the unloads, because after them
      # /api/ps has nothing left to report. A tenth of a gigabyte is as
      # precise as this needs to be — the number is here to say how much of
      # the card was gone, not to be audited.
      #
      # `|| exit 0` on the whole thing for the same reason the request above
      # has it: a server that answered with something this doesn't
      # understand is a hook that has nothing to do, not a hook that failed.
      # jq's complaint still reaches the journal.
      resident=$(printf '%s' "$snapshot" | jq -r '
        (.models // [])[] | "\(.name)\t\(.size_vram / 1073741824 * 10 | round / 10)"') || exit 0
      [ -n "$resident" ] || exit 0

      while IFS=$'\t' read -r model gib; do
        [ -n "$model" ] || continue
        # `if` rather than `|| true`: a model that would not unload is the
        # one case worth saying out loud, because it means the game is
        # starting on a card that is still part full and the frame rate is
        # about to be explained by something this hook already knows.
        if curl -fsS --max-time 10 "${ollamaUrl}/api/generate" \
          --json "{\"model\": \"$model\", \"prompt\": \"\", \"keep_alive\": 0}" \
          >/dev/null; then
          echo "released $model ($gib GiB)"
        else
          echo "$model ($gib GiB) would not unload"
        fi
      done <<< "$resident"
    '';
  };

  # Ask the niri session to enter or leave its own GameMode.
  #
  # That mode lives entirely on the home-manager side —
  # home/joshr/niri/gamemode.nix — because what it changes is the compositor's
  # and the shell's configuration: animations, blur, transparency, and the
  # shell's own CPU/GPU sampling. This module cannot name the script that does
  # it. A NixOS module has no handle on a store path home-manager built, and it
  # could not find one by name either: gamemoded's PATH is not merely sparse,
  # it is `lib.mkForce`d in nixpkgs' own module to a link farm containing
  # `pkexec` and nothing else.
  #
  # A unit name crosses that gap where a path cannot. gamemoded runs under the
  # user's own systemd manager — `systemd.user.services.gamemoded` in
  # nixos/modules/programs/gamemode.nix, D-Bus activated on the session bus,
  # which is also why `notify-send` in these hooks works at all — so
  # `systemctl --user` is always reachable from a hook and $XDG_RUNTIME_DIR is
  # set for it by definition. home-manager declares `niri-gamemode-start` and
  # `niri-gamemode-stop`; this only has to know those two names, and nothing
  # checks that the two files spell them the same way, exactly as nothing
  # checks SIGRTMIN+9 above.
  #
  # `--no-block` because gamemoded kills a custom script after ten seconds
  # (`script_timeout`) and there is nothing here worth waiting for.
  #
  # The existence check is what makes the failure legible. "No such unit" and
  # "the unit exists and would not start" both exit non-zero, and only the
  # second is worth a word: the first is every session that has no niri
  # profile — a Plasma login, root — and is as ordinary as `pkill` finding no
  # waybar. gamemoded reads a hook's stdout and discards it, so the complaint
  # goes to stderr, which lands in `journalctl --user -u gamemoded`.
  sessionGamemode = which: ''
    if systemctl --user cat niri-gamemode-${which}.service >/dev/null 2>&1; then
      systemctl --user start --no-block niri-gamemode-${which}.service \
        || echo "gamemode hook: niri-gamemode-${which}.service would not start" >&2
    fi
  '';

  # --- why both hooks are programs, and not lines of shell -----------------
  #
  # **gamemoded will not read a `custom.*` value longer than 255 bytes, and it
  # drops the whole thing rather than truncating it.** `append_value_to_list`
  # (daemon/gamemode-config.c) does a `strncpy` into a CONFIG_VALUE_MAX buffer,
  # notices the result is unterminated, logs
  #
  #     Config: Could not add [...] to [start], exceeds length limit of 256
  #
  # and `memset`s the entry back to empty. The script does not run in a reduced
  # form; it does not run at all.
  #
  # That is a low ceiling for a config written in Nix, because every command in
  # a hook is an absolute store path and a store path is seventy-odd bytes
  # before the arguments. Three of them plus their arguments is around 335
  # bytes — which is exactly what these hooks became when the session GameMode
  # hand-off was added to a pair of shell one-liners that were already at 200.
  # Both sides silently stopped running: no session GameMode, no bar poke, and
  # no "GameMode started" notification either.
  #
  # One store path per hook is the shape that cannot come back. It costs about
  # 87 bytes whatever the script grows into, so the limit stops being something
  # to keep an eye on — and `hookScript` below still checks, because the point
  # of a limit you have already been bitten by is that the build should say so
  # rather than the journal.
  gamemodeScriptLimit = 255;

  hookScript =
    which: program:
    let
      path = lib.getExe program;
      bytes = builtins.stringLength path;
    in
    assert lib.assertMsg (bytes <= gamemodeScriptLimit) ''
      modules/nixos/gaming.nix: programs.gamemode.settings.custom.${which} is ${toString bytes}
      bytes, over gamemoded's ${toString gamemodeScriptLimit}-byte limit for a config value. It
      would be dropped whole at load (append_value_to_list in
      daemon/gamemode-config.c), so the hook would silently never run. Keep the
      value to one store path and put the work inside the program.
    '';
    path;

  # What gamemode runs when a game takes gamemode.
  #
  # It is a program rather than a line of shell for two reasons, and the second
  # one is now the load-bearing one:
  #
  #   * The notification has to say what the GPU release did, and that answer
  #     only exists once the release has run — so the two cannot be sequenced
  #     in a config value.
  #   * A config value cannot be long. See gamemodeScriptLimit above.
  #
  # The order here is the whole reason the file exists:
  #
  #   * The notification, the bar poke and the session's own GameMode go first.
  #     They are the confirmation that the mode engaged, and they must not sit
  #     behind a model server that is mid-generation. gamemoded gives a custom
  #     script ten seconds and then kills it (`script_timeout`), so a release
  #     that hangs would otherwise take all three down with it.
  #
  #   * The release then *rewrites* that notification rather than raising a
  #     second one behind it. `notify-send -p` prints the id the notification
  #     daemon assigned and `-r` replaces that id, so what the player sees is
  #     one notification that gains a line naming what was on the card once
  #     the card is back.
  #
  # The release half is conditional where it used to decide whether this
  # program existed at all. That gained nothing once both hooks had to be
  # programs regardless, and it cost the hosts without a model server a second
  # code path that was never the one being read when something went wrong.
  #
  # Which leaves the notification itself as the one line that still differs per
  # host, and it has to. `-p` prints the id the notification daemon assigned so
  # that the release below can replace *that* notification instead of raising a
  # second one; a host with no model server has nothing to replace it with and
  # must not ask for the id, because writeShellApplication runs shellcheck and
  # an assigned-but-never-read variable is a failed build rather than a warning.
  startNotify =
    if releaseOnGameMode then
      ''id=$(notify-send -p -i input-gamepad 'GameMode started') || id=""''
    else
      ''notify-send -i input-gamepad 'GameMode started' || true'';

  gamemodeStart = pkgs.writeShellApplication {
    name = "gamemode-start-hook";

    runtimeInputs =
      with pkgs;
      [
        libnotify
        procps # pkill
        systemd # systemctl --user
      ]
      ++ lib.optional releaseOnGameMode releaseGpu;

    text = ''
      # One of two lines, chosen per host — see startNotify above. On the host
      # that captures an id, a daemon that doesn't hand one back (or no daemon
      # at all) leaves it empty and the rewrite below falls back to a plain
      # notification.
      ${startNotify}

      # waybar's custom/gamemode module is otherwise on a 30-second poll, and
      # a mode you turn on for a game should show up in the bar as the game
      # starts rather than up to half a minute later. SIGRTMIN+9 is the
      # `signal` that module is given in home/joshr/niri/waybar.nix — the two
      # numbers have to agree, and nothing checks that they do.
      #
      # `|| true` because pkill exits 1 when nothing matches, which is the
      # ordinary case in a Plasma session with no waybar running.
      pkill -RTMIN+9 waybar || true

      # The niri session's own GameMode: animations, blur, transparency and
      # the shell's sampling off, exactly as Mod+G leaves them.
      ${sessionGamemode "start"}
    ''
    + lib.optionalString releaseOnGameMode ''

      # Silent when the card was already the game's: gamemode-release-gpu
      # prints nothing unless something was holding video memory, so an
      # ordinary launch notifies exactly as it did before this existed.
      freed=$(gamemode-release-gpu) || freed=""
      if [ -n "$freed" ]; then
        if [ -n "$id" ]; then
          notify-send -r "$id" -i input-gamepad 'GameMode started' "$freed" || true
        else
          notify-send -i input-gamepad 'GameMode started' "$freed" || true
        fi
      fi
    '';
  };

  # And the other half. There is no release to undo — ollama loads on demand,
  # so the next question reloads whatever it needs — which is why this stayed a
  # one-liner for as long as a one-liner was allowed to be one.
  gamemodeEnd = pkgs.writeShellApplication {
    name = "gamemode-end-hook";

    runtimeInputs = with pkgs; [
      libnotify
      procps # pkill
      systemd # systemctl --user
    ];

    text = ''
      notify-send -i input-gamepad 'GameMode ended' || true
      pkill -RTMIN+9 waybar || true
      ${sessionGamemode "stop"}
    '';
  };

  # One command that answers "why is it slow *now*".
  #
  # The failure modes behind a game that degrades mid-session look identical
  # from the chair — frames drop, the hitching starts — and are told apart
  # only by numbers taken while it is happening. This prints all of them in
  # one go, so a bad session produces evidence instead of a memory:
  #
  #   * video memory near the card's total, or another process holding a
  #     chunk of it, means eviction to system memory. The NVIDIA driver does
  #     not degrade gracefully past that point.
  #   * a graphics clock far below its maximum with a reason listed under
  #     "Clocks Event Reasons" means thermal or power throttling, which is a
  #     case-and-fans answer rather than a configuration one.
  #   * a `~/.cache/nv` sitting near 1 GB with SKIP_CLEANUP unset means the
  #     driver is about to throw the shader cache away — see the long note in
  #     modules/nixos/nvidia.nix.
  #   * an empty EGL external platform directory means the XWayland path has
  #     fallen off its fast route, which is the regression in
  #     nixpkgs#524342 and the sway thread it links to.
  #
  # The last two sections answer a different question — "why does the pad not
  # move the cursor" — and they are here rather than in a command of their own
  # because the answer is assembled from places nobody remembers the paths to:
  # /proc/bus/input/devices, every hidraw device's uevent and driver link
  # under /sys, the open file descriptors of every process this user owns,
  # /dev/uinput's permissions, and the environment of the *running* Steam.
  # See `local.gaming.steamInputOnWayland` in modules/nixos/options.nix for
  # what each of them means. With two generations of Steam Controller on one
  # machine the table is also the only thing that says which pad is which.
  #
  # Every probe here is allowed to find nothing: no card, no model server, no
  # niri session, no controller. writeShellApplication runs this under
  # `set -e`, so each one ends in `|| true` — a diagnostic that stops at the
  # first absent thing is worse than no diagnostic.
  gamingDoctor = pkgs.writeShellApplication {
    name = "gaming-doctor";

    runtimeInputs =
      with pkgs;
      [
        coreutils
        curl
        gamemode # gamemoded --status
        gawk # the controller table
        gnugrep
        jq
        libnotify # the one finding worth leaving the terminal for
        procps # free, pgrep
        util-linux # swapon
      ]
      # nvidia-smi lives in the driver's `bin` output. Conditional because
      # this module has no NVIDIA dependency of its own — a host that imports
      # it with an AMD card gets a report with the card sections empty rather
      # than a build that pulls in a driver it will never load.
      ++ lib.optional (lib.elem "nvidia" config.services.xserver.videoDrivers) config.hardware.nvidia.package.bin
      ++ lib.optional config.services.power-profiles-daemon.enable pkgs.power-profiles-daemon;

    text = ''
      have() { command -v "$1" >/dev/null 2>&1; }
      section() { printf '\n== %s ==\n' "$1"; }

      echo "gaming-doctor on $(uname -n) at $(date '+%F %T')"
      echo "Run this *while* it is slow — most of what follows is a snapshot."

      section "driver"
      # One line, and it says both the version and whether this is the open
      # kernel module: the open one calls itself so in this string.
      cat /proc/driver/nvidia/version 2>/dev/null || echo "no NVIDIA driver loaded"
      grep -E 'PreserveVideoMemoryAllocations|EnableGpuFirmware|UseKernelSuspendNotifiers' \
        /proc/driver/nvidia/params 2>/dev/null || true

      section "the card, right now"
      if have nvidia-smi; then
        nvidia-smi --format=csv \
          --query-gpu=memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw,power.limit,clocks.current.graphics,clocks.max.graphics,clocks.current.memory,clocks.max.memory \
          || true
      else
        echo "no nvidia-smi on PATH"
      fi

      section "throttling"
      # The authoritative answer. "Active" against anything other than
      # GpuIdle is the card telling you it is being held back, and by what.
      if have nvidia-smi; then
        nvidia-smi -q -d PERFORMANCE || true
      fi

      section "what is holding video memory"
      # Type G is a graphics client (the game, the compositor, a browser),
      # type C is compute (ollama, anything CUDA). Both come out of the same
      # pool.
      if have nvidia-smi; then
        nvidia-smi || true
      fi

      section "local model server"
      resident=$(curl -fsS --max-time 2 "${ollamaUrl}/api/ps" 2>/dev/null) || resident=""
      if [ -z "$resident" ]; then
        echo "nothing answering on ${ollamaUrl} — expected when local.ai is off"
      else
        count=$(echo "$resident" | jq -r '(.models // []) | length') || count=0
        echo "models resident: $count"
        echo "$resident" \
          | jq -r '(.models // [])[] | "  \(.name)  \(.size_vram / 1073741824 * 100 | round / 100) GiB VRAM, expires \(.expires_at)"' \
          || true

        # The one section that gets a notification of its own.
        #
        # Everything else here is a number to read in the terminal this was
        # typed into. A model resident on the card is different in kind: it
        # is the finding that explains a bad session, it is the one with
        # something to do about it (start a game and gamemode's hook takes
        # the card back, or `ollama stop <model>` by hand), and this is a
        # command as likely to be bound to a key and hit mid-game — with the
        # terminal behind a fullscreen window — as it is to be typed at a
        # prompt. Only when something is actually resident: a doctor that
        # notifies on a clean bill is noise.
        #
        # dialog-warning rather than the gamepad the gamemode hooks use,
        # because this is a finding rather than a change of state.
        #
        # `|| true` for the run with no session bus behind it: over ssh, or
        # from a unit, notify-send fails and that is not a failed report.
        if [ "$count" -gt 0 ]; then
          notify-send -i dialog-warning 'gaming-doctor: AI is holding the card' \
            "$(echo "$resident" \
              | jq -r '(.models // [])[] | "\(.name) — \(.size_vram / 1073741824 * 10 | round / 10) GiB VRAM"')" \
            || true
        fi
      fi

      section "shader cache"
      echo "__GL_SHADER_DISK_CACHE=''${__GL_SHADER_DISK_CACHE-unset}"
      echo "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=''${__GL_SHADER_DISK_CACHE_SKIP_CLEANUP-unset}"
      du -sh "''${XDG_CACHE_HOME:-$HOME/.cache}/nv" 2>/dev/null \
        || echo "no shader cache directory yet"

      section "EGL external platforms"
      # Without these JSON files NVIDIA's EGL has no Wayland or X11 external
      # platform to load, and XWayland clients — which is every Proton game —
      # fall back to a path that runs at a fraction of the speed. nixpkgs
      # installs them from egl-wayland, egl-gbm, egl-wayland2 and egl-x11, so
      # an empty listing here is the bug, not a quirk.
      ls -1 /run/opengl-driver/share/egl/egl_external_platform.d/ 2>/dev/null \
        || echo "EMPTY — see 'Gaming performance' in MANUAL.md"
      echo "__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS=''${__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS-unset}"

      section "system memory"
      free -h || true
      swapon --show || true

      section "cpu and power"
      cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
      if have powerprofilesctl; then powerprofilesctl get || true; fi
      # gamemoded is D-Bus activated, so asking it for its status is enough to
      # start it — check it is already up first, the same way the bar's
      # gamemode indicator does (gamemodeStatus in
      # home/joshr/niri/gamemode.nix).
      if pgrep -x gamemoded >/dev/null 2>&1; then
        gamemoded --status || true
      else
        echo "gamemoded not running (no game holds gamemode)"
      fi

      section "compositor"
      if have niri && [ -n "''${NIRI_SOCKET-}" ]; then
        niri msg outputs || true
      else
        echo "not a niri session, or not run from inside one"
      fi

      # --- the controller, which is a different question -----------------
      #
      # Everything above answers "why is it slow". The two sections below
      # answer "why does the pad not move the cursor", which is the other
      # thing that gets typed into a search box at eleven at night.
      #
      # Read them in order. The kernel has to see the pad; something has to
      # have claimed it, or not, and which is which matters; /dev/uinput has
      # to be writable; the preload has to be in the *running* Steam; and
      # only then does the absence of the fake device mean anything.

      section "controllers"
      # Every input device whose name looks like a pad, with the event and
      # js nodes it owns. A pad missing from this list is a cable, a battery
      # or a udev rule, and nothing further down applies.
      devices=$(gawk '
        /^N: Name=/ {
          name = substr($0, 10)
          gsub(/"/, "", name)
        }
        /^H: Handlers=/ {
          handlers = substr($0, 13)
          key = tolower(name)
          if (key ~ /steam|controller|gamepad|joystick|extest|x-?box|dualsense|dualshock/)
            printf "  %-38s %s\n", name, handlers
        }
      ' /proc/bus/input/devices 2>/dev/null) || devices=""
      if [ -n "$devices" ]; then
        echo "$devices"
      else
        echo "nothing controller-shaped is connected, or no driver has bound to it"
      fi

      # --- every Valve HID device, its driver, and who has it open --------
      #
      # This is the table that matters when there is more than one pad on the
      # machine, because the two generations behave differently in a way
      # nothing else here would show.
      #
      # The product id says which pad a line is. 1102 is the wired 2015 Steam
      # Controller, 1142 its wireless dongle, 1205 a Steam Deck, and 1304 the
      # 2026 controller (which enumerates as "Steam Controller Puck").
      #
      # The driver column is the difference. hid-steam's device table is those
      # first three ids and nothing else — `steam_controllers[]` in
      # drivers/hid/hid-steam.c — so a 2015 pad gets a kernel driver that owns
      # its lizard mode, enabling the firmware's mouse-and-keyboard emulation
      # when nothing holds the device and disabling it the moment a hidraw
      # client opens one (`steam_input_open`). The 2026 pad falls through to
      # hid-generic: its lizard mode is the firmware's own decision, the
      # kernel is not managing it, and there is no kernel-side path that puts
      # it back.
      #
      # And the last column is the fact that explains a dead cursor. Lizard
      # mode ends when something opens the hidraw node; `steam` in that column
      # is therefore Steam having taken the pad, which is correct and wanted —
      # it is what Steam Input's layouts require — and also why everything in
      # the next section has to work.
      valve=""
      for dev in /sys/class/hidraw/hidraw*; do
        [ -e "$dev/device/uevent" ] || continue
        # HID_ID=0003:000028DE:00001102 — bus, vendor, product, each padded.
        hid_id=$(gawk -F= '$1 == "HID_ID" { print $2 }' "$dev/device/uevent") || continue
        case "$hid_id" in *:000028DE:*) ;; *) continue ;; esac

        node=''${dev##*/}
        product=$(printf '%s' "$hid_id" | gawk -F: '{ print substr($3, 5) }')
        hid_name=$(gawk -F= '$1 == "HID_NAME" { print $2 }' "$dev/device/uevent") || hid_name="?"

        # The driver is a symlink; no driver at all is a device nothing has
        # claimed, which is itself worth seeing.
        drv=$(readlink "$dev/device/driver" 2>/dev/null) || drv=""
        [ -n "$drv" ] || drv="(none)"
        drv=''${drv##*/}

        valve="$valve$node|$product|$drv|$hid_name
"
      done

      if [ -z "$valve" ]; then
        echo "  no Valve HID devices — no pad is connected"
      else
        # One pass over /proc rather than one per device. Only this user's
        # processes are readable, which is the right set: Steam runs as the
        # person sitting here.
        holders=""
        for link in /proc/[0-9]*/fd/*; do
          target=$(readlink "$link" 2>/dev/null) || continue
          case "$target" in /dev/hidraw*) ;; *) continue ;; esac
          pid=''${link#/proc/}
          pid=''${pid%%/*}
          comm=$(cat "/proc/$pid/comm" 2>/dev/null) || comm="?"
          holders="$holders''${target##*/} $comm($pid)
"
        done

        printf '  %-8s %-7s %-12s %s\n' node product driver "open by"
        while IFS='|' read -r node product drv hid_name; do
          [ -n "$node" ] || continue
          who=$(printf '%s' "$holders" | gawk -v n="$node" '$1 == n { print $2 }' \
            | sort -u | tr '\n' ' ')
          [ -n "$who" ] || who="-"
          printf '  %-8s %-7s %-12s %s\n' "$node" "$product" "$drv" "$who"
          printf '           %s\n' "$hid_name"
        done <<< "$valve"
      fi

      section "steam input on wayland"
      # What the configuration says, so the run-time answers below have
      # something to disagree with. See local.gaming.steamInputOnWayland.
      echo "programs.steam.extest.enable = ${lib.boolToString config.programs.steam.extest.enable}"

      # extest writes through this node, and the ACL on it is what udev's
      # `uaccess` tag grants whoever is logged in at the seat.
      if [ -e /dev/uinput ]; then
        ls -l /dev/uinput
        if [ -w /dev/uinput ]; then
          echo "  writable by $(id -un)"
        else
          echo "  NOT writable by $(id -un) — extest cannot create its device"
        fi
      else
        echo "/dev/uinput missing — hardware.steam-hardware.enable is what loads the module"
      fi

      # And whether the Steam that is actually running has the preload. This
      # is the one that disagrees with the line above in practice: a Steam
      # started from a Flatpak, from a stale desktop entry, or from a shell
      # that predates the rebuild is a Steam the wrapper never wrapped.
      steam_pid=$(pgrep -x steam | head -n1) || steam_pid=""
      if [ -z "$steam_pid" ]; then
        echo "steam is not running — start it to check the preload"
      else
        preload=$(tr '\0' '\n' < "/proc/$steam_pid/environ" | grep '^LD_PRELOAD=' || true)
        if [ -n "$preload" ]; then
          echo "steam pid $steam_pid: $preload"
        else
          echo "steam pid $steam_pid has no LD_PRELOAD — extest is not loaded into it"
        fi
      fi

      # The proof, and the one line worth reading twice.
      #
      # extest names its uinput device "extest fake device" and creates it the
      # first time Steam asks XTEST to move something. Present means the
      # translation is working and a cursor that still does not move is a
      # Steam-side problem — see the 2026 controller's registration bug in
      # local.gaming.steamInputOnWayland. Absent with everything above green
      # means Steam has not driven a mouse yet: open the Desktop Layout, move
      # the pad, and look again.
      if grep -q 'extest fake device' /proc/bus/input/devices 2>/dev/null; then
        echo "extest fake device: present — XTEST is reaching the real pointer"
      else
        echo "extest fake device: absent — nothing has asked XTEST for pointer motion yet"
      fi
    '';
  };
in
{
  # local.* lives in its own module so this one can stay a config attrset.
  imports = [
    ./options.nix

    # OpenRGB: the daemon, and re-applying the profile after a suspend.
    #
    # It lived here as four lines and moved out when the resume half was added.
    # Still imported from this file rather than per host, so the hosts that had
    # RGB before still have it and nothing had to be edited to keep it. Its
    # `local.openrgb.*` options are in modules/nixos/options.nix.
    ./openrgb.nix
  ];

  # MangoHud isn't here at all: it's configured per-user in
  # home/joshr/gaming.nix, through home-manager's programs.mangohud rather than
  # a NixOS-level option. The counters it shows are chosen to match the
  # sections gaming-doctor prints — see the comment there.

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;

    # The controller's pointer, in a session that has no X server to fake one
    # in.
    #
    # Steam's desktop-level mouse emulation — the Desktop Layout, the Big
    # Picture cursor, the guide-button chord that turns a pad into a mouse —
    # is written against the X11 XTEST extension, which asks the X server to
    # pretend a device did something. There is no such server here: Steam is
    # an Xwayland client, so XTEST moves Xwayland's private idea of the
    # pointer and the compositor, which draws the cursor and routes the click,
    # never hears about it. That is the "second, invisible cursor" — X11
    # windows follow the phantom, everything else ignores it, and the pointer
    # on screen does not move.
    #
    # extest replaces those XTEST entry points at load time and drives a
    # /dev/uinput device instead, which the kernel and therefore the
    # compositor treat as a real mouse. nixpkgs puts the 32-bit build in
    # Steam's own `LD_PRELOAD`, so it reaches Steam and its children and
    # nothing else.
    #
    # Not niri-specific, which is why it is here rather than in the niri
    # module: `gamestation` is a Plasma **Wayland** session and has exactly
    # the same problem. See `local.gaming.steamInputOnWayland` in
    # modules/nixos/options.nix for what it needs from udev and what it does
    # not fix, and `gaming-doctor` for whether it actually ended up loaded.
    extest.enable = config.local.gaming.steamInputOnWayland;
  };

  # Stop the kernel from sleeping a thread that does a split lock.
  #
  # The detector stays on and still logs; what this turns off is the penalty
  # — the forced sleep, serialised behind a global semaphore — that lands on
  # the render thread of a Proton game whose hot path does unaligned atomics.
  # It is a burst-hitching symptom that reads as a GPU problem and isn't one,
  # and Linux 6.2 gained this sysctl because of how many games hit it.
  #
  # `local.gaming.splitLockMitigate` is the way back to the kernel default,
  # and its description is the longer version of why the default here is the
  # other one. On a CPU without split-lock or bus-lock detection the file does
  # not exist and systemd-sysctl says it skipped it.
  boot.kernel.sysctl."kernel.split_lock_mitigate" =
    if config.local.gaming.splitLockMitigate then 1 else 0;

  programs.gamescope = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    prismlauncher
    protonup-qt
    lutris

    # "Why is it slow *now*" — see the comment on the derivation above, and
    # "Gaming performance" in MANUAL.md for what to do with each answer.
    gamingDoctor
  ];

  programs.gamemode = {
    enable = true;

    settings = {
      # One store path per side, and nothing else.
      #
      # Each hook notifies, pokes waybar, and hands the niri session its own
      # GameMode; the start half may also take the card back from a model
      # server. All of that is *inside* the two programs above, because a
      # `custom.*` value that runs past 255 bytes is dropped whole by gamemoded
      # rather than truncated — see the comment on gamemodeScriptLimit. Writing
      # the work here as shell is what broke both hooks once already.
      #
      # gamemode still runs each value through `/bin/sh -c`
      # (game_mode_execute_scripts in daemon/gamemode-context.c) rather than
      # execvp on a split string. Nothing here needs that any more, but it is
      # also why a bare store path works with no PATH to find it on: nixpkgs'
      # own gamemode module mkForces gamemoded's PATH to a link farm holding
      # `pkexec` and nothing else.
      #
      # `hookScript` is the length check. It cannot fail as things stand — 87
      # bytes against a limit of 255 — and it exists so that the next thing
      # appended here fails the build with the reason instead of disappearing
      # into gamemoded's journal.
      custom = {
        start = hookScript "start" gamemodeStart;
        end = hookScript "end" gamemodeEnd;
      };
    };
  };
}
