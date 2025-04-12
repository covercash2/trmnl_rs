{
  description = "trmnl_rs - ESP32 E-ink display firmware in Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system;
          overlays = overlays;
        };

        # Use nightly Rust for ESP32 development
        rustToolchain = pkgs.rust-bin.nightly.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
          targets = [ "riscv32imc-unknown-none-elf" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust
            rustToolchain

            # Cargo tools
            cargo-espflash
            cargo-generate
            cargo-watch
            rustup

            # ESP tools
            esptool
            espup

            # Build dependencies
            pkg-config
            cmake
            ninja

            # Additional tools
            python3
            just
            libiconv
          ];
          shellHook = ''
            export LIBCLANG_PATH="/home/chrash/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-19.1.2_20250225/esp-clang/lib"
            export PATH="/home/chrash/.rustup/toolchains/esp/xtensa-esp-elf/esp-14.2.0_20240906/xtensa-esp-elf/bin:$PATH"

            # Welcome message
            echo "🦀 ESP32 Rust development environment"
            echo "Commands available:"
            echo "  - cargo build"
            echo "  - cargo-espflash <PORT> --release"

            # You'll need to run 'espup install' once to set up the ESP32 Rust environment
            echo "Note: After entering the environment, you may need to run:"
            echo "  curl -sSf https://esp-rs.github.io/espup/install.sh | sh"
            echo "to install the ESP Rust toolchain"
          '';

          # Include libraries with special linking requirements
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.libiconv
          ];
        };
      });
}
