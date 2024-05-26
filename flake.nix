{
  # name it zeng
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      with pkgs;
      {
        devShells.default = mkShell
          {
            buildInputs = [
              just
              caddy
              glew
              glfw3
              cmake
              zig
              zls
              wayland-scanner
              libGL
              xorg.libX11
              xorg.libXcursor
              xorg.libXrandr
              xorg.libXinerama
              xorg.libXi
              wayland
              libxkbcommon
              renderdoc
            ];
            shellHook = ''
              export LD_LIBRARY_PATH=${wayland}/lib:$LD_LIBRARY_PATH
            '';
          };
      }
    );
}
