{ config, pkgs, ... }:

let
  # Entrypoint script defining the startup logic
  entrypoint = pkgs.writeScriptBin "entrypoint" ''
    #!${pkgs.runtimeShell}

    # Source system environment variables
    if [ -f /etc/profile ]; then
      source /etc/profile
    fi

    # Current user setup
    CURRENT_USER=$(whoami)
    USER_HOME=$(eval echo ~$CURRENT_USER)

    echo "Starting as user: $CURRENT_USER (Home: $USER_HOME)"

    # Prepare runtime directory
    export XDG_RUNTIME_DIR=/tmp/runtime-dir
    mkdir -p $XDG_RUNTIME_DIR
    chmod 0700 $XDG_RUNTIME_DIR

    # Create cache directory
    mkdir -p $USER_HOME/.cache/hypr

    # Create config directory
    mkdir -p $USER_HOME/.config/hypr

    echo "Launching Hyprland with Global Headless Config..."

    exec ${pkgs.hyprland}/bin/Hyprland \
      --config /etc/hypr/hyprland.conf \
      --i-am-really-stupid
  '';
in
{
  # Define the system state version
  system.stateVersion = "23.11";

  # Helper to make it behave like a container
  boot.isContainer = true;

  # Define Users (Example of user creation as requested)
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    uid = 1000;
    home = "/home/nixos";
    createHome = true;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System Packages
  environment.systemPackages = with pkgs; [
    bash
    coreutils
    curl
    git
    hyprland
    wayvnc
    novnc
    google-chrome
    kitty

    # Graphics Drivers
    mesa
    mesa.drivers
    libglvnd
    libdrm
    libxkbcommon
    wayland

    # The entrypoint script
    entrypoint
  ];

  # Expose entrypoint for external use (flake.nix)
  system.build.entrypoint = entrypoint;

  # Hyprland Configuration File
  environment.etc."hypr/hyprland.conf".text = ''
    # --- SCREEN ---
    monitor=HEADLESS-1,1920x1080@60,0x0,1

    # --- AUTOSTART ---
    exec-once = ${pkgs.wayvnc}/bin/wayvnc 0.0.0.0 5900 --output=HEADLESS-1 --no-auth
    exec-once = ${pkgs.novnc}/bin/websockify --web ${pkgs.novnc}/share/novnc 6080 localhost:5900
    exec-once = ${pkgs.google-chrome}/bin/google-chrome-stable --no-sandbox --disable-gpu --start-maximized

    # --- SHORTCUTS (ALT Key) ---
    $mainMod = ALT
    bind = $mainMod, RETURN, exec, ${pkgs.kitty}/bin/kitty
    bind = $mainMod, Q, killactive
    bind = $mainMod SHIFT, E, exit
    bind = $mainMod, h, movefocus, l
    bind = $mainMod, l, movefocus, r
    bind = $mainMod, k, movefocus, u
    bind = $mainMod, j, movefocus, d
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    misc {
      disable_hyprland_logo = true
      disable_splash_rendering = true
    }

    animations {
      enabled = false
    }

    # Software Rendering Env Fix
    env = WLR_NO_HARDWARE_CURSORS,1
  '';

  # Environment Variables
  environment.variables = {
    XDG_RUNTIME_DIR = "/tmp/runtime-dir";
    WLR_BACKENDS = "headless";
    WLR_LIBINPUT_NO_DEVICES = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_RENDERER = "gles2";
    LIBGL_ALWAYS_SOFTWARE = "1";
    MESA_LOADER_DRIVER_OVERRIDE = "llvmpipe";

    # Driver fixes
    LIBGL_DRIVERS_PATH = "${pkgs.mesa.drivers}/lib/dri";
    LD_LIBRARY_PATH = "${pkgs.libglvnd}/lib:${pkgs.mesa.drivers}/lib:${pkgs.mesa}/lib:${pkgs.libdrm}/lib:${pkgs.libxkbcommon}/lib:${pkgs.wayland}/lib";
  };
}
