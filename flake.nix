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
      config.allowUnfree = true; # Google Chrome için gerekli
    };

    # --- 1. Hyprland Config Dosyasını Oluşturuyoruz ---
    # Bu fonksiyon, dosya içeriğini /root/.config/hypr/hyprland.conf yoluna yazar.
    hyprlandConf = pkgs.writeTextDir "root/.config/hypr/hyprland.conf" ''
      # --- EKRAN ---
      monitor=HEADLESS-1,1920x1080@60,0x0,1

      # --- OTOMATİK BAŞLATMA ---
      # VNC Sunucusu (Şifresiz, sadece localhost)
      exec-once = ${pkgs.wayvnc}/bin/wayvnc 0.0.0.0 5900 --output=HEADLESS-1 --no-auth
      
      # Web Arayüzü (noVNC)
      exec-once = ${pkgs.novnc}/bin/websockify --web ${pkgs.novnc}/share/novnc 6080 localhost:5900
      
      # Google Chrome (GPU kapalı modda)
      exec-once = ${pkgs.google-chrome}/bin/google-chrome-stable --no-sandbox --disable-gpu --start-maximized

      # --- TARAYICI DOSTU KISAYOLLAR (ALT Tuşu) ---
      $mainMod = ALT

      bind = $mainMod, RETURN, exec, ${pkgs.kitty}/bin/kitty
      bind = $mainMod, Q, killactive
      bind = $mainMod SHIFT, E, exit

      # Pencere Odaklama (Vim Tuşları)
      bind = $mainMod, h, movefocus, l
      bind = $mainMod, l, movefocus, r
      bind = $mainMod, k, movefocus, u
      bind = $mainMod, j, movefocus, d

      # Mouse Yönetimi
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow
      
      # Animasyonları kapat (Performans için)
      animations {
        enabled = false
      }
    '';

    # --- 2. Başlangıç Scripti ---
    entrypoint = pkgs.writeScriptBin "entrypoint" ''
      #!${pkgs.runtimeShell}
      
      # Runtime klasörlerini hazırla (Wayland için zorunlu)
      export XDG_RUNTIME_DIR=/tmp/runtime-dir
      mkdir -p $XDG_RUNTIME_DIR
      chmod 0700 $XDG_RUNTIME_DIR
      
      # Environment Değişkenleri
      export WLR_BACKENDS=headless
      export WLR_LIBINPUT_NO_DEVICES=1
      export WLR_RENDERER_ALLOW_SOFTWARE=1
      
      echo "Hyprland Headless Başlatılıyor..."
      exec ${pkgs.hyprland}/bin/Hyprland
    '';

  in {
    packages.${system}.dockerImage = pkgs.dockerTools.buildLayeredImage {
      name = "nixos-hyprland-web";
      tag = "latest";
      
      # --- İmaj İçeriği ---
      contents = [
        # 1. Oluşturduğumuz Config Dosyası (En üste ekledik)
        hyprlandConf
        
        # 2. Temel Paketler
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
        pkgs.git
        
        # 3. Masaüstü Ortamı
        pkgs.hyprland
        pkgs.wayvnc
        pkgs.novnc
        pkgs.google-chrome
        pkgs.kitty
        
        # 4. Entrypoint Scripti
        entrypoint
      ];

      # Container Ayarları
      config = {
        Cmd = [ "${entrypoint}/bin/entrypoint" ];
        ExposedPorts = {
          "6080/tcp" = {};
        };
        Env = [
          "XDG_RUNTIME_DIR=/tmp/runtime-dir"
          "HOME=/root" # Config dosyasını /root altına koyduğumuz için
        ];
      };
    };
  };
}