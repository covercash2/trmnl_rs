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
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rust

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
            ninja
            python3

            # build tools
            cargo-generate

            ldproxy
          ];
        };
      }
    );
}
