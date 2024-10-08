{
  stdenv,
  lib,
  mkWindowsApp,
  wine,
  fetchurl,
  makeDesktopItem,
  makeDesktopIcon, # This comes with erosanix. It's a handy way to generate desktop icons.
  copyDesktopItems,
  copyDesktopIcons, # This comes with erosanix. It's a handy way to generate desktop icons.
  unzip,
  writeText,
  setDPI ? null,
}: let
  # This registry file sets winebrowser (xdg-open) as the default handler for
  # text files, instead of Wine's notepad.
  # Selecting "Settings -> Advanced Options" should then use xdg-open to open the SumatraPDF config file.
  txtReg = ./txt.reg;

  setDPIReg = writeText "set-dpi-${toString setDPI}.reg" ''
    Windows Registry Editor Version 5.00
    [HKEY_LOCAL_MACHINE\System\CurrentControlSet\Hardware Profiles\Current\Software\Fonts]
    "LogPixels"=dword:${toString setDPI}
  '';
in
  mkWindowsApp rec {
    inherit wine;

    pname = "moi3d";
    version = "4.0";

    src = builtins.fetchurl {
      url = "https://moi3d.com/4.0/trial/moi_v4_trial_setup.exe";
      sha256 = "sha256:19vf1lnpjw5nn7xdapjzaw1ns9zpaqsyz3wgzml5iccx9m1445rx";
    };

    # In most cases, you'll either be using an .exe or .zip as the src.
    # Even in the case of a .zip, you probably want to unpack with the launcher script.
    dontUnpack = true;

    # You need to set the WINEARCH, which can be either "win32" or "win64".
    # Note that the wine package you choose must be compatible with the Wine architecture.
    wineArch = "win64";

    # Sometimes it can take a while to install an application to generate an app layer.
    # `enableInstallNotification`, which is set to true by default, uses notify-send
    # to generate a system notification so that the user is aware that something is happening.
    # There are two notifications: one before the app installation and one after.
    # The notification will attempt to use the app's icon, if it can find it. And will fallback
    # to hard-coded icons if needed.
    # If an app installs quickly, these notifications can actually be distracting.
    # In such a case, it's better to set this option to false.
    # This package doesn't benefit from the notifications, but I've explicitly enabled them
    # for demonstration purposes.
    enableInstallNotification = true;

    # `fileMap` can be used to set up automatic symlinks to files which need to be persisted.
    # The attribute name is the source path and the value is the path within the $WINEPREFIX.
    # But note that you must ommit $WINEPREFIX from the path.
    # To figure out what needs to be persisted, take at look at $(dirname $WINEPREFIX)/upper,
    # while the app is running.
    fileMap = {
      "$HOME/Desktop" = "drive_c/Users/$USER/Desktop";
      "$HOME/Documents" = "drive_c/Users/$USER/$Documents";
    };

    # By default, `fileMap` is applied right before running the app and is cleaned up after the app terminates. If the following option is set to "true", then `fileMap` is also applied prior to `winAppInstall`. This is set to "false" by default.
    fileMapDuringAppInstall = false;

    # By default `mkWindowsApp` doesn't persist registry changes made during runtime. Therefore, if an app uses the registry then set this to "true". The registry files are saved to `$HOME/.local/share/mkWindowsApp/$pname/`.
    persistRegistry = false;

    # By default mkWindowsApp creates ephemeral (temporary) WINEPREFIX(es).
    # Setting persistRuntimeLayer to true causes mkWindowsApp to retain the WINEPREFIX, for the short term.
    # This option is designed for apps which can't have their automatic updates disabled.
    # It allows package maintainers to not have to constantly update their mkWindowsApp packages.
    # It is NOT meant for long-term persistance; If the Windows or App layers change, the Runtime layer will be discarded.
    persistRuntimeLayer = false;

    # The method used to calculate the input hashes for the layers.
    # This should be set to "store-path", which is the strictest and most reproduceable method. But it results in many rebuilds of the layers since the slightest change to the package inputs will change the input hashes.
    # An alternative is "version" which is a relaxed method and results in fewer rebuilds but is less reproduceable. If you are considering using "version", contact me first. There may be a better way.
    inputHashMethod = "store-path";

    nativeBuildInputs = [unzip copyDesktopItems copyDesktopIcons];

    winAppInstall =
      ''
        $WINE ${src} /silent
        regedit ${./use-theme-none.reg}
        regedit ${./wine-breeze-dark.reg}
        regedit ${txtReg}
      ''
      + lib.optionalString (setDPI != null) ''
        regedit ${setDPIReg}
      '';

    # cp -v -n "${defaultSettings}" "$config_dir/SumatraPDF-settings.txt"
    # chmod ug+w "$config_dir/SumatraPDF-settings.txt"

    # This code runs before winAppRun, but only for the first instance.
    # Therefore, if the app is already running, winAppRun will not execute.
    # Use this to do any setup prior to running the app.
    winAppPreRun = ''
    '';

    # This code will become part of the launcher script.
    # It will execute after winAppInstall and winAppPreRun (if needed),
    # to run the application.
    # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
    # and wine, winetricks, and cabextract are in the environment.
    # Command line arguments are in $ARGS, not $@
    # DO NOT BLOCK. For example, don't run: wineserver -w
    winAppRun = ''
      wine "$WINEPREFIX/drive_c/Program Files/MoI 4.0 trial/MoI.exe" "$ARGS"
    '';

    # This code will run after winAppRun, but only for the first instance.
    # Therefore, if the app was already running, winAppPostRun will not execute.
    # In other words, winAppPostRun is only executed if winAppPreRun is executed.
    # Use this to do any cleanup after the app has terminated
    winAppPostRun = "";

    # This is a normal mkDerivation installPhase, with some caveats.
    # The launcher script will be installed at $out/bin/.launcher
    # DO NOT DELETE OR RENAME the launcher. Instead, link to it as shown.
    installPhase = ''
      runHook preInstall

      ln -s $out/bin/.launcher $out/bin/${pname}

      runHook postInstall
    '';

    desktopItems = let
      # mimeTypes = [
      #   "application/pdf"
      #   "application/epub+zip"
      #   "application/x-mobipocket-ebook"
      #   "application/vnd.amazon.mobi8-ebook"
      #   "application/x-zip-compressed-fb2"
      #   "application/x-cbt"
      #   "application/x-cb7"
      #   "application/x-7z-compressed"
      #   "application/vnd.rar"
      #   "application/x-tar"
      #   "application/zip"
      #   "image/vnd.djvu"
      #   "image/vnd.djvu+multipage"
      #   "application/vnd.ms-xpsdocument"
      #   "application/oxps"
      #   "image/jpeg"
      #   "image/png"
      #   "image/gif"
      #   "image/webp"
      #   "image/tiff"
      #   "image/tiff-multipage"
      #   "image/x-tga"
      #   "image/bmp"
      #   "image/x-dib"
      # ];
    in [
      (makeDesktopItem {
        # inherit mimeTypes;

        name = pname;
        exec = pname;
        icon = pname;
        desktopName = "Moi3D";
        genericName = "3D CAD software";
        categories = ["Graphics" "Viewer"];
      })
    ];

    desktopIcon = makeDesktopIcon {
      name = "moi3d";

      src = fetchurl {
        url = "https://moi3d.com/images/moi001.png";
        sha256 = "sha256-c+B847cKvtp5ZUvpoJ7JvgKRH95gdTngS6jyBxkXBvA=";
      };
    };

    meta = with lib; {
      description = "Moment of Inspiration (moi3d) is CAD software";
      homepage = "https://www.moi3dreader.org/free-pdf-reader";
      license = licenses.unfree;
      maintainers = with maintainers; [];
      platforms = ["x86_64-linux"];
    };
  }
