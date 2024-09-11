{
  description = "A Nix flake for SumatraPDF";

  inputs.erosanix.url = "github:emmanuelrosa/erosanix";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";

  outputs = { self, nixpkgs, erosanix }: {

    packages.x86_64-linux = let
      pkgs = import "${nixpkgs}" {
        system = "x86_64-linux";
      };

    in with (pkgs // erosanix.packages.x86_64-linux // erosanix.lib.x86_64-linux); {
      default = self.packages.x86_64-linux.moi3d;

      moi3d = callPackage ./moi3d.nix {
        inherit mkWindowsApp makeDesktopIcon copyDesktopIcons;

        wine = wineWowPackages.full;
      };
    };

    apps.x86_64-linux.moi3d = {
      type = "app";
      program = "${self.packages.x86_64-linux.moi3d}/bin/moi3d";
    };

    apps.x86_64-linux.default = self.apps.x86_64-linux.moi3d;
  };
}
