{
  description = "NixOS Hyprland Headless Container (Multi-User Fix)";

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

    # --- 1. Global Hyprland Config ---
    # Dosyayı /root yerine /etc altına koyuyoruz ki herkes erişsin.
    hyprlandConf = pkgs.writeTextDir "etc/hypr/hyprland.conf" ''
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

      # Software Rendering için gerekli env düzeltmeleri
      env = WLR_NO_HARDWARE_CURSORS,1
    '';

    # --- 2. Akıllı Başlangıç Scripti ---
    entrypoint = pkgs.writeScriptBin "entrypoint" ''
      #!${pkgs.runtimeShell}
      
      # Şu anki kullanıcıyı bul
      CURRENT_USER=$(whoami)
      USER_HOME=$(eval echo ~$CURRENT_USER)

      echo "Starting as user: $CURRENT_USER (Home: $USER_HOME)"

      # Runtime klasörünü hazırla
      export XDG_RUNTIME_DIR=/tmp/runtime-dir
      mkdir -p $XDG_RUNTIME_DIR
      chmod 0700 $XDG_RUNTIME_DIR
      
      # Crash raporları için cache klasörünü oluştur (Hata buradaydı)
      mkdir -p $USER_HOME/.cache/hypr
      
      # Hyprland Config klasörünü oluştur (Gerekirse)
      mkdir -p $USER_HOME/.config/hypr

      echo "Launching Hyprland with Global Headless Config..."
      
      # KRİTİK NOKTA: --config parametresi ile bizim dosyamızı zorluyoruz.
      # Böylece kullanıcının ev dizinindeki (boş veya hatalı) config yerine bunu kullanıyor.
      exec ${pkgs.hyprland}/bin/Hyprland \
        --config /etc/hypr/hyprland.conf \
        --i-am-really-stupid
    '';

  in {
    packages.${system}.dockerImage = pkgs.dockerTools.buildLayeredImage {
      name = "nixos-hyprland-web";
      tag = "latest";
      
      contents = [
        hyprlandConf # Config artık /etc/hypr/hyprland.conf yolunda
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
        pkgs.git
        pkgs.hyprland
        pkgs.wayvnc
        pkgs.novnc
        pkgs.google-chrome
        pkgs.kitty
        
        # Grafik Sürücüleri
        pkgs.mesa
        pkgs.mesa.drivers
        pkgs.libglvnd
        pkgs.libdrm
        pkgs.libxkbcommon
        pkgs.wayland
        entrypoint
      ];

      config = {
        Cmd = [ "${entrypoint}/bin/entrypoint" ];
        ExposedPorts = {
          "6080/tcp" = {};
        };
        Env = [
          "XDG_RUNTIME_DIR=/tmp/runtime-dir"
          "WLR_BACKENDS=headless"
          "WLR_LIBINPUT_NO_DEVICES=1"
          "WLR_RENDERER_ALLOW_SOFTWARE=1"
          "WLR_RENDERER=gles2"
          "LIBGL_ALWAYS_SOFTWARE=1"
          "MESA_LOADER_DRIVER_OVERRIDE=llvmpipe"
          
          # Driver fix:
          "LIBGL_DRIVERS_PATH=${pkgs.mesa.drivers}/lib/dri"
          "LD_LIBRARY_PATH=${pkgs.libglvnd}/lib:${pkgs.mesa.drivers}/lib:${pkgs.mesa}/lib:${pkgs.libdrm}/lib:${pkgs.libxkbcommon}/lib:${pkgs.wayland}/lib"
        ];
      };
    };
  };
}
