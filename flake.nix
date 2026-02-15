{
  description = "NixOS Hyprland Headless Container";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: 
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { 
      inherit system; 
      config.allowUnfree = true;
    };

    # --- Kullanıcı Tanımları ---
    fakePasswd = pkgs.writeTextDir "etc/passwd" ''
      root:x:0:0::/root:/bin/bash
      ertugrulerata:x:1000:1000::/home/ertugrulerata:/bin/bash
    '';

    fakeGroup = pkgs.writeTextDir "etc/group" ''
      root:x:0:
      ertugrulerata:x:1000:
    '';

    fakeShadow = pkgs.writeTextDir "etc/shadow" ''
      root:!x:::::::
      ertugrulerata:!:::::::
    '';

    # --- 1. Hyprland Config Dosyası ---
    hyprlandConf = pkgs.writeTextDir "home/ertugrulerata/.config/hypr/hyprland.conf" ''
      # --- EKRAN ---
      monitor=HEADLESS-1,1920x1080@60,0x0,1

      # --- OTOMATİK BAŞLATMA ---
      exec-once = ${pkgs.wayvnc}/bin/wayvnc 0.0.0.0 5900 --output=HEADLESS-1 --no-auth
      exec-once = ${pkgs.novnc}/bin/websockify --web ${pkgs.novnc}/share/novnc 6080 localhost:5900
      exec-once = ${pkgs.google-chrome}/bin/google-chrome-stable --no-sandbox --disable-gpu --start-maximized

      # --- KISAYOLLAR (ALT Tuşu) ---
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
    '';

    # --- 2. Başlangıç Scripti ---
    entrypoint = pkgs.writeScriptBin "entrypoint" ''
      #!${pkgs.runtimeShell}
      
      # Runtime klasörlerini hazırla
      mkdir -p /tmp/runtime-dir
      chmod 0700 /tmp/runtime-dir
      
      # Cache klasörünü hazırla (Crash report hatasını çözer)
      mkdir -p /home/ertugrulerata/.cache/hypr
      
      echo "Starting Hyprland in Headless Mode (Software Rendering)..."
      
      # Hyprland'i başlat (Zaten kullanıcı olarak çalışıyoruz)
      exec ${pkgs.hyprland}/bin/Hyprland --i-am-really-stupid
    '';

  in {
    packages.${system}.dockerImage = pkgs.dockerTools.buildLayeredImage {
      name = "nixos-hyprland-web";
      tag = "latest";
      
      contents = [
        fakePasswd
        fakeGroup
        fakeShadow
        hyprlandConf
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
        pkgs.git
        pkgs.hyprland
        pkgs.wayvnc
        pkgs.novnc
        pkgs.google-chrome
        pkgs.kitty
        
        # --- KRİTİK EKLEMELER (Software Rendering İçin) ---
        pkgs.mesa
        pkgs.mesa.drivers
        pkgs.libglvnd
        entrypoint
      ];

      # İmaj oluşturulurken çalışacak komutlar (fakeroot içinde çalışır)
      fakeRootCommands = ''
        mkdir -p tmp
        chmod 1777 tmp
        mkdir -p home/ertugrulerata
        chown 1000:1000 home/ertugrulerata
      '';

      config = {
        Cmd = [ "${entrypoint}/bin/entrypoint" ];
        User = "ertugrulerata";
        ExposedPorts = {
          "6080/tcp" = {};
        };
        # Environment Değişkenleri
        Env = [
          # Wayland Ayarları
          "XDG_RUNTIME_DIR=/tmp/runtime-dir"
          "WLR_BACKENDS=headless"
          "WLR_LIBINPUT_NO_DEVICES=1"
          "WLR_RENDERER_ALLOW_SOFTWARE=1"
          
          # --- KRİTİK EKRAN KARTI AYARLARI ---
          "LIBGL_ALWAYS_SOFTWARE=1"            # OpenGL'i CPU'da çalışmaya zorla
          "MESA_LOADER_DRIVER_OVERRIDE=llvmpipe" # Mesa sürücüsü olarak llvmpipe (CPU) kullan
          
          # Diğer
          "HOME=/home/ertugrulerata"
          "XDG_CACHE_HOME=/home/ertugrulerata/.cache"
        ];
      };
    };
  };
}
