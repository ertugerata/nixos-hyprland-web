{
  description = "NixOS Hyprland Headless Container (Refactored)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: 
  let
    system = "x86_64-linux";

    # Instantiate the NixOS system configuration
    nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
      ];
    };

    # Helper to access the system configuration and packages
    sysConfig = nixos.config;
    sysPkgs = nixos.pkgs;

    # Extract the entrypoint script
    entrypoint = sysConfig.system.build.entrypoint;

    # Create a derivation for the home directory structure
    homeDir = sysPkgs.runCommand "home-dir" {} ''
      mkdir -p $out/home/nixos
    '';

  in {
    packages.${system}.dockerImage = sysPkgs.dockerTools.buildLayeredImage {
      name = "nixos-hyprland-web";
      tag = "latest";
      
      # Include system packages and the /etc tree in the image
      contents = sysConfig.environment.systemPackages ++ [
        sysConfig.system.build.etc
        homeDir
      ];

      # Prepare home directory for the user defined in configuration.nix
      fakeRootCommands = ''
        chown ${toString sysConfig.users.users.nixos.uid}:100 /home/nixos
        chmod 700 /home/nixos
      '';

      config = {
        Cmd = [ "${entrypoint}/bin/entrypoint" ];
        ExposedPorts = {
          "6080/tcp" = {};
        };

        # Extract environment variables defined in configuration.nix
        Env = nixpkgs.lib.mapAttrsToList (n: v: "${n}=${v}") sysConfig.environment.variables;
      };
    };
  };
}
