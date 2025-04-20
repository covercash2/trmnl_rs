{
  description = "A minimal Rust project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        rust = pkgs.rust-bin.nightly.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };

        # Create FHS environment in order to build `esp-idf`
        fhs = pkgs.buildFHSUserEnv {
          name = "esp-idf-env";
          targetPkgs = pkgs: (with pkgs; [
            rust
            python3

            # ESP-IDF prereqs
            # https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/linux-macos-setup.html#for-linux-users
            bison
            ccache
            cmake
            dfu-util
            flex
            git
            gnumake
            gperf
            libusb1
            libxml2
            ninja
            python3

            ldproxy

            stdenv.cc
            zlib
            ncurses5

            nushell
          ]);
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            fhs
            rust

            cargo-espflash
            espflash
            ldproxy
            python3

            just
          ];

          shellHook = ''
            # exec esp-idf-env
          '';
        };
      }
    );
}
