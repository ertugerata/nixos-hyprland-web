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

    # --- 1. Hyprland Config Dosyası ---
    hyprlandConf = pkgs.writeTextDir "root/.config/hypr/hyprland.conf" ''
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
      
      animations {
        enabled = false
      }
    '';

    # --- 2. Başlangıç Scripti ---
    entrypoint = pkgs.writeScriptBin "entrypoint" ''
      #!${pkgs.runtimeShell}
      
      # Runtime klasörlerini hazırla
      # (Docker içinde /tmp bazen temiz gelir, bu yüzden garantiye alıyoruz)
      mkdir -p /tmp/runtime-dir
      chmod 0700 /tmp/runtime-dir
      
      echo "Hyprland Headless (Root Modu) Başlatılıyor..."
      
      # KRİTİK DÜZELTME BURADA:
      # --i-am-really-stupid flag'i root ile çalışmaya izin verir.
      exec ${pkgs.hyprland}/bin/Hyprland --i-am-really-stupid
    '';

  in {
    packages.${system}.dockerImage = pkgs.dockerTools.buildLayeredImage {
      name = "nixos-hyprland-web";
      tag = "latest";
      
      contents = [
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
        entrypoint
      ];

      config = {
        Cmd = [ "${entrypoint}/bin/entrypoint" ];
        ExposedPorts = {
          "6080/tcp" = {};
        };
        # Environment Değişkenleri (Artık global olarak tanımlı)
        Env = [
          "XDG_RUNTIME_DIR=/tmp/runtime-dir"
          "WLR_BACKENDS=headless"
          "WLR_LIBINPUT_NO_DEVICES=1"
          "WLR_RENDERER_ALLOW_SOFTWARE=1"
          "HOME=/root"
        ];
      };
    };
  };
}
