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

        # Create a wrapper for ESP-IDF tools with proper dynamic linking
        esp-toolchain-wrapper = pkgs.stdenv.mkDerivation {
          name = "esp-toolchain-wrapper";

          # Create a dummy source file that's required by mkDerivation
          src = pkgs.writeTextDir "source" "Dummy source file for esp-toolchain-wrapper";

          buildInputs = with pkgs; [
            # Basic requirements
            stdenv.cc.cc.lib
            ncurses5
            zlib
            libusb1
            flex
            bison
            gperf
          ];

          # Nothing to build
          dontBuild = true;

          # Set up environment variables for ESP-IDF tools
          installPhase = ''
            mkdir -p $out/bin

            # Create a wrapper script for the ESP-IDF environment
            cat > $out/bin/setup-esp-env.sh << 'EOF'
            #!/bin/sh
            # This script sets up the ESP-IDF environment with proper library paths

            # Set up library paths for dynamically linked executables
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.ncurses5
              pkgs.zlib
              pkgs.libusb1
            ]}:$LD_LIBRARY_PATH

            # Allow Nix to run dynamically linked binaries
            export NIX_ENFORCE_PURITY=0

            # Source the ESP environment if it exists
            if [ -f "$HOME/export-esp.sh" ]; then
              source "$HOME/export-esp.sh"
              echo "ESP environment successfully loaded!"
            else
              echo "ESP environment not found. Run espup install to set it up."
            fi
            EOF

            chmod +x $out/bin/setup-esp-env.sh

            # Create a patched espup install script that uses Nix tools
            cat > $out/bin/espup-nix-install.sh << 'EOF'
            #!/bin/sh
            # This script wraps espup install to use Nix tools instead of downloading binaries

            echo "Installing ESP-RS tools with Nix integration..."

            # Run espup with the no-download flag to prevent it from downloading binaries
            # that won't work on NixOS
            espup install \
              --no-download \
              --export-file ~/export-esp.sh \
              --no-modify-path \
              "$@"

            # Create a modified export-esp.sh that uses Nix tools
            cat > ~/export-esp.sh << 'END'
            # ESP environment variables - configured by espup
            export ESP_ARCH="riscv32imc-unknown-none-elf"
            export LIBCLANG_PATH="${pkgs.libclang.lib}/lib"

            # Use Nix-provided tools instead of downloaded binaries
            export PATH="${pkgs.cmake}/bin:${pkgs.ninja}/bin:$PATH"

            echo "ESP-RS environment set up with Nix tools"
            END

            echo "ESP-RS environment setup complete."
            echo "To use the ESP-RS environment, run: source ~/export-esp.sh"
            EOF

            chmod +x $out/bin/espup-nix-install.sh
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell.override { stdenv = pkgs.llvmPackages_16.stdenv; } {
          nativeBuildInputs = with pkgs; [
            # Rust
            rustToolchain

            # ESP toolchain wrapper
            esp-toolchain-wrapper

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
            llvmPackages_16.clang
            llvmPackages_16.libclang.lib

            # Libraries needed for ESP-IDF tools
            ncurses5
            zlib
            libusb1
            openssl

            # Additional tools
            python3
            python3Packages.pip
            python3Packages.virtualenv
            just
            libiconv
          ];

          shellHook = ''
            # Set up environment for dynamic linking
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.ncurses5
              pkgs.zlib
              pkgs.libusb1
              pkgs.libiconv
              pkgs.llvmPackages_16.libclang.lib
              pkgs.openssl
            ]}:$LD_LIBRARY_PATH

            # Allow Nix to run dynamically linked binaries
            export NIX_ENFORCE_PURITY=0

            # Set LLVM/Clang paths
            export LIBCLANG_PATH="${pkgs.llvmPackages_16.libclang.lib}/lib"
            export CLANG_PATH="${pkgs.llvmPackages_16.clang}/bin/clang"

            # Welcome message
            echo "🦀 ESP32 Rust development environment"
            echo "Commands available:"
            echo "  - cargo build"
            echo "  - cargo-espflash <PORT> --release"

            # Instructions for ESP toolchain
            echo ""
            echo "To set up the ESP32 environment:"
            echo "1. Run: espup-nix-install.sh --targets esp32"
            echo "2. After installation, run: source ~/export-esp.sh"
            echo ""

            # Try to source existing ESP environment if available
            if [ -f "$HOME/export-esp.sh" ]; then
              echo "Found existing ESP environment, loading it..."
              source "$HOME/export-esp.sh"
            fi
          '';

          # Enable shell with impure features (required for downloading some deps)
          shellArgs = ["--impure"];

          # Include libraries with special linking requirements
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.libiconv
            pkgs.stdenv.cc.cc.lib
            pkgs.ncurses5
            pkgs.zlib
            pkgs.libusb1
            pkgs.llvmPackages_16.libclang.lib
            pkgs.openssl
          ];
        };
      });
}
