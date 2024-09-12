{
  description = "Moi3D for NixOS";

  inputs.erosanix.url = "github:emmanuelrosa/erosanix";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";
  inputs.nix-gaming.url = "github:fufexan/nix-gaming";

  outputs = {
    self,
    nixpkgs,
    erosanix,
  }: {
    packages.x86_64-linux = let
      pkgs = import "${nixpkgs}" {
        system = "x86_64-linux";
      };
      mono = pkgs.fetchurl rec {
        version = "8.1.0";
        url = "https://dl.winehq.org/wine/wine-mono/${version}/wine-mono-${version}-x86.msi";
        hash = "sha256-DtPsUzrvebLzEhVZMc97EIAAmsDFtMK8/rZ4rJSOCBA=";
      };
    in {
      default = self.packages.x86_64-linux.moi3d;

      moi3d = pkgs.callPackage ./moi3d.nix {
        inherit (erosanix.lib.x86_64-linux) mkWindowsApp makeDesktopIcon copyDesktopIcons;

        wine = self.inputs.nix-gaming.packages.x86_64-linux.wine-ge.override {
          monos = [
            mono
          ];
        };
      };
    };

    apps.x86_64-linux.moi3d = {
      type = "app";
      program = "${self.packages.x86_64-linux.moi3d}/bin/moi3d";
    };

    apps.x86_64-linux.default = self.apps.x86_64-linux.moi3d;
  };
}
