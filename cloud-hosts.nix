{
  bot =
    { config, pkgs, lib, ... }:
    let
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      flake = builtins.getFlake (toString ./.);
      urbit-pkgs = import flake.inputs.urbit { system = pkgs.system; };
    in
    {
      imports = [
        ./hardware-configuration.nix
        ./networking.nix # generated at runtime by nixos-infect
                         # download this from your server (I'm not including it here)
      ];

      config = {
        deployment.targetHost = "$YOUR_SHIP";

        environment.systemPackages = with pkgs; [
          cloud-utils
        ]
        ++
        (with urbit-pkgs; [
          arvo
          # brass
          ent
          # herb
          # ivory
          # solid
          urbit
          urcrypt
        ]);

        networking.hostName = "bot";
        networking.firewall = {
          allowPing = true;
          allowedTCPPorts = [
            80
            443
          ];
          allowedUDPPorts = [
            34543 # urbit
          ];
        };

        services.openssh = {
          enable = true;
          passwordAuthentication = false;
        };
        users.users.root.openssh.authorizedKeys.keyFiles = [
          # !!! ADD YOUR KEY HERE SO YOU DON'T GET LOCKED OUT !!!
        ];

        # reverse proxy
        services.caddy = {
          enable = true;
          email = "$YOUR_EMAIL";
          extraConfig =
            ''
              ur.$YOUR_SHIP {
                reverse_proxy localhost:8080
              }
              console.s3.$YOUR_SHIP {
                reverse_proxy localhost:9001
              }
              s3.$YOUR_SHIP media.s3.$YOUR_SHIP {
                reverse_proxy localhost:9000
              }
            '';
        };

        # minio s3 bucket setup (used to serve media which your urbit can link-to)
        services.minio = {
          enable = true;
          region = "us-west-2";
          listenAddress = ":9000";
          consoleAddress = ":9001";
          rootCredentialsFile = "/etc/nixos/minio-root-credentials";
        };

        # setup swap file
        systemd.services = {
          create-swapfile = {
            serviceConfig.Type = "oneshot";
            wantedBy = [ "swap-swapfile.swap" ];
            script = ''
              swapfile="/swapfile"
              if [[ -f "$swapfile" ]]; then
                echo "Swap file $swapfile already exists, taking no action"
              else
                echo "Setting up swap file $swapfile"
                fallocate -l 1G $swapfile
                chmod 600 $swapfile
                mkswap $swapfile
                swapon $swapfile
              fi
            '';
          };

          minio = {
            environment = {
              MINIO_ROOT_USER = "minioadmin";
              MINIO_DOMAIN = "s3.$YOUR_SHIP";
              MINIO_SERVER_URL = "https://s3.$YOUR_SHIP";
            };
          };
        };
      };
    }
}
