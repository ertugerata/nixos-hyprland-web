# NixOS Hyprland Headless Container

## Yapılan Değişiklikler ve Önemli Noktalar

### pkgs.writeTextDir Kullanımı:
Bu fonksiyon sayesinde `hyprland.conf` dosyasını Nix store içinde oluşturup, imajın içinde tam olarak `/root/.config/hypr/hyprland.conf` yoluna yerleştirdim.

Artık container açıldığında script'in dosya oluşturmasını beklemeye gerek yok; dosya zaten orada, hazır.

### Otomatik Başlatma Komutları (exec-once):
* wayvnc (VNC Server)
* novnc (Web Socket)
* google-chrome (Tarayıcı)

Bu üçü Hyprland açıldığı anda otomatik başlayacak şekilde config dosyasına gömüldü.

### Chrome Ayarı:
Chrome'u `--start-maximized` parametresiyle başlattım, böylece açıldığında tüm ekranı kaplar.

## Nasıl Kullanacaksın?

1. Bu dosyayı `flake.nix` olarak kaydet.

2. İmajı oluştur:
   ```bash
   nix build .#dockerImage
   ```

3. Docker'a yükle:
   ```bash
   docker load < result
   ```

4. Çalıştır:
   ```bash
   docker run -d -p 6080:6080 --name hypr-web nixos-hyprland-web:latest
   ```
