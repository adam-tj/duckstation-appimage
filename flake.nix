{
  description = "DuckStation AppImage";

  inputs = {
    nixpkgs.url = "github:Nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      version = "v0.1-11580";

      duckstationAppImage = pkgs.fetchurl {
        url = "https://github.com/stenzek/duckstation/releases/download/${version}/DuckStation-x64.AppImage";
        sha256 = "sha256-HEjypHirDlh5CaaMTkelDKW33ZMhATB21RcVUbasrj8=";
      };

      extracted = pkgs.appimageTools.extractType2 {
        pname = "duckstation";
        inherit version;
        src = duckstationAppImage;
      };

      duckstationPackage = pkgs.stdenv.mkDerivation {
        pname = "duckstation";
        inherit version;
        src = extracted;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin $out/share
          cp -r $src/* $out/

          chmod -R +w $out

          TARGET="$out/usr/bin/duckstation-qt"
          if [ ! -f "$TARGET" ]; then
            TARGET="$out/bin/duckstation-qt"
          fi

          wrapProgram "$TARGET" \
            --set QT_PLUGIN_PATH "$out/usr/plugins" \
            --set QT_QPA_PLATFORM_PLUGIN_PATH "$out/usr/plugins/platforms" \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [
              pkgs.libGL
              pkgs.libGLX
              pkgs.mesa
              pkgs.libglvnd
              pkgs.wayland
              pkgs.libxkbcommon
              pkgs.xcb-util-cursor
              pkgs.fontconfig
              pkgs.freetype
            ]}"

          # Expose duckstation-qt as the primary executable binary
          ln -s "$TARGET" $out/bin/duckstation-qt
          ln -s "$TARGET" $out/bin/duckstation

          # Install desktop entry and icon for system launchers
          mkdir -p $out/share/applications
          mkdir -p $out/share/icons/hicolor/512x512/apps

          if [ -f "$out/org.duckstation.DuckStation.desktop" ]; then
            cp "$out/org.duckstation.DuckStation.desktop" $out/share/applications/
          elif [ -f "$out/usr/share/applications/org.duckstation.DuckStation.desktop" ]; then
            cp "$out/usr/share/applications/org.duckstation.DuckStation.desktop" $out/share/applications/
          fi

          if [ -f "$out/org.duckstation.DuckStation.png" ]; then
            cp "$out/org.duckstation.DuckStation.png" $out/share/icons/hicolor/512x512/apps/
          elif [ -f "$out/usr/share/icons/hicolor/512x512/apps/org.duckstation.DuckStation.png" ]; then
            cp "$out/usr/share/icons/hicolor/512x512/apps/org.duckstation.DuckStation.png" $out/share/icons/hicolor/512x512/apps/
          fi

          # Fix the Exec path in the desktop file to point to the wrapped target
          if [ -f "$out/share/applications/org.duckstation.DuckStation.desktop" ]; then
            substituteInPlace $out/share/applications/org.duckstation.DuckStation.desktop \
              --replace "Exec=duckstation-qt" "Exec=$out/bin/duckstation-qt" \
              --replace "Exec=duckstation" "Exec=$out/bin/duckstation-qt"
          fi

          runHook postInstall
        '';
      };
    in
    {
      packages.${system}.default = duckstationPackage;

      apps.${system}.default = {
        type = "app";
        program = "${duckstationPackage}/bin/duckstation-qt";
      };
    };
}
