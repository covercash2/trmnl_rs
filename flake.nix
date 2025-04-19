{
  description = "trmnl_rs - ESP32-C3 E-ink display firmware in Rust";

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

        # Use nightly Rust for ESP32-C3 development (RISC-V target)
        # https://github.com/esp-rs/esp-idf-template?tab=readme-ov-file#flash
        rustToolchain = pkgs.rust-bin.nightly.latest.default.override {
          extensions = [
            "rust-src"
            "rust-analyzer"
            "llvm-tools-preview"
          ];
          # targets = [ "riscv32imc-esp-espidf" ];  # ESP32-C3 uses RISC-V architecture
        };

        # Python dependencies for ESP-IDF
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          pip
          setuptools
          wheel
          virtualenv
          pyserial
          pyparsing
          future
          cryptography
          packaging
          pyyaml
          click
          GitPython
        ]);

        # Define constants
        espArch = "riscv32imc-unknown-none-elf";
        espBoard = "esp32c3";
        espIdfVersion = "5.3.2";

        # Create a script to install ESP tools
        espToolsInstaller = pkgs.writeShellScriptBin "install-esp-tools" ''
          #!/usr/bin/env bash
          echo "Installing ESP tools..."

          # install espup with cargo since nixpkgs is behind
          cargo install espup

          # Install ESP-IDF with esp32c3 target
          echo "Installing ESP-IDF for ESP32-C3..."
          espup install --targets ${espBoard} --stable-version nightly --export-file esp-idf-export.sh

          echo ""
          echo "ESP tools installed successfully!"
          echo ""
          echo "To set up your environment for building:"
          echo "Run: source esp-idf-export.sh"
        '';

        # Create a monitor script
        monitorScript = pkgs.writeShellScriptBin "esp-monitor" ''
          #!/usr/bin/env bash
          if [ -z "$1" ]; then
            echo "Usage: esp-monitor <PORT> [BAUD]"
            echo "Example: esp-monitor /dev/ttyUSB0 115200"
            exit 1
          fi

          BAUD=''${2:-115200}

          echo "Opening serial monitor on $1 at $BAUD baud..."
          ${pkgs.screen}/bin/screen $1 $BAUD
        '';

        # Create build helper tools
        espBuildHelpers = pkgs.writeShellScriptBin "esp-debug" ''
          #!/usr/bin/env bash

          echo "ESP32-C3 Build Environment Debug Information"
          echo "==========================================="
          echo ""

          echo "Environment Variables:"
          echo "ESP_ARCH=$ESP_ARCH"
          echo "ESP_BOARD=$ESP_BOARD"
          echo "ESP_IDF_VERSION=$ESP_IDF_VERSION"
          echo "MCU=$MCU"
          echo "RUSTFLAGS=$RUSTFLAGS"
          echo ""

          echo "ESP-IDF installation:"
          if [ -d "$HOME/.espressif" ]; then
            echo "~/.espressif directory exists"
            if [ -d "$HOME/.espressif/esp-idf" ]; then
              echo "ESP-IDF appears to be installed"
              if [ -f "$HOME/.espressif/esp-idf/export.sh" ]; then
                echo "ESP-IDF export script exists"
              else
                echo "ESP-IDF export script missing"
              fi
            else
              echo "ESP-IDF not found in ~/.espressif"
            fi
          else
            echo "~/.espressif directory not found"
          fi
          echo ""

          echo "Rust environment:"
          cargo --version
          rustc --version
          echo ""

          echo "Cargo metadata:"
          cargo metadata --format-version=1 | grep -E 'esp-idf-sys|esp-idf-hal|features.*esp32c3' || echo "esp-idf-* packages not found or esp32c3 feature not enabled"
          echo ""

          echo "Checking ESP32-C3 toolchain:"
          ls -la ~/.rustup/toolchains/*/lib/rustlib/${espArch} 2>/dev/null || echo "ESP32-C3 target not found in rustup toolchains"
          echo ""
        '';
      in
      {
        devShells.default = pkgs.mkShell.override { stdenv = pkgs.llvmPackages_16.stdenv; } {
          name = "esp32c3-dev-env";

          nativeBuildInputs = with pkgs; [
            # Rust
            rustToolchain

            # Cargo tools
            cargo-espflash
            cargo-generate
            cargo-watch
            cargo-binutils
            rustup

            # ESP tools
            espflash
            esptool
            # espup

            # Custom scripts
            espToolsInstaller
            monitorScript
            espBuildHelpers

            # Build tools
            # https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/linux-macos-setup.html#step-1-install-prerequisites
            ccache
            cmake
            dfu-util
            ninja
            pkg-config
            libusb1
            llvmPackages_16.clang
            git

            # Serial tools
            screen

            # Python environment
            pythonEnv

            # Additional tools
            just
            jq
            openssl
          ];

          shellHook = ''
            # Set up libraries
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.llvmPackages_16.libclang.lib
              pkgs.openssl
              pkgs.zlib
              pkgs.glib
              ".embuild/espressif/tools/riscv32-esp-elf/esp-13.2.0_20240530/riscv32-esp-elf/lib"
            ]}:$LD_LIBRARY_PATH

            # Set NIX_LD if it's not already set
            export NIX_LD="${pkgs.glibc}/lib/ld-linux-x86-64.so.2"

            # Allow Nix to find the dynamic linker
            export NIX_DYNAMIC_LINKER="${pkgs.glibc}/lib/ld-linux-x86-64.so.2"

            # ESP environment variables
            export ESP_ARCH="${espArch}"
            export ESP_BOARD="${espBoard}"
            export ESP_IDF_VERSION="v${espIdfVersion}"
            export MCU="${espBoard}"

            # Rust environment variables
            export RUSTFLAGS="--cfg espidf_time64"

            # Allow Nix to run dynamically linked binaries
            export NIX_ENFORCE_PURITY=0

            # Source ESP-IDF export script if it exists in current directory
            if [ -f "esp-idf-export.sh" ]; then
              source "esp-idf-export.sh" > /dev/null 2>&1 || true
              echo "Sourced esp-idf-export.sh from current directory"
            fi

            # Welcome message
            echo "🦀 ESP32-C3 Rust development environment ready"
            echo ""
            echo "Environment variables set:"
            echo "  ESP_ARCH=${espArch}"
            echo "  ESP_BOARD=${espBoard}"
            echo "  ESP_IDF_VERSION=v${espIdfVersion}"
            echo "  MCU=${espBoard}"
            echo ""
            echo "Workflow:"
            echo "  1. Install:      install-esp-tools"
            echo "  2. Set up env:   source esp-idf-export.sh"
            echo "  3. Build:        esp-build"
            echo "  4. Flash:        esp-flash <PORT>"
            echo "  5. Monitor:      esp-monitor <PORT> [BAUD]"
            echo ""
            echo "Debugging:"
            echo "  - Show config:   esp-debug"
            echo ""
          '';

          # Include necessary environment variables
          ESP_ARCH = espArch;
          ESP_BOARD = espBoard;
          ESP_IDF_VERSION = "v${espIdfVersion}";
          MCU = espBoard;
          NIX_ENFORCE_PURITY = 0;
          RUSTFLAGS = "--cfg espidf_time64";
        };
      });
}
