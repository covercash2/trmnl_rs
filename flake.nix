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
        rustToolchain = pkgs.rust-bin.nightly.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
          targets = [ "riscv32imc-unknown-none-elf" ];  # ESP32-C3 uses RISC-V architecture
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
        ]);

        # Define ESP-IDF version
        esp-idf-version = "5.3.2";

        # Create a simple ESP-IDF environment
        esp-idf-tools = pkgs.stdenv.mkDerivation {
          name = "esp-idf-tools";
          version = esp-idf-version;

          # Use a simple empty directory as source
          src = pkgs.emptyDirectory;

          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontBuild = true;
          dontConfigure = true;

          # Create a minimal directory structure with essential ESP-IDF files
          installPhase = ''
            mkdir -p $out/tools/cmake
            mkdir -p $out/components/esp_system/include

            # Create version.cmake file
            cat > $out/tools/cmake/version.cmake << EOF
            # This file was generated
            set(IDF_VERSION_MAJOR 5)
            set(IDF_VERSION_MINOR 3)
            set(IDF_VERSION_PATCH 2)
            set(IDF_VERSION "v5.3.2")
            EOF

            # Create a minimal project_include.cmake
            cat > $out/tools/cmake/project.cmake << EOF
            # Minimal project.cmake
            set(IDF_PATH "$out")
            EOF

            # Create a minimal sdkconfig.h file
            cat > $out/components/esp_system/include/sdkconfig.h << EOF
            // Minimal sdkconfig.h
            #define CONFIG_IDF_TARGET_ESP32C3 1
            EOF

            # Create version.txt file
            echo "${esp-idf-version}" > $out/version.txt

            # Create version.json file
            echo '{"version": "v${esp-idf-version}", "git_revision": "v${esp-idf-version}"}' > $out/version.json
          '';
        };

        # Define ESP-IDF environment variables
        idfPath = "${esp-idf-tools}";
        espArch = "riscv32imc-unknown-none-elf";
        libclangPath = "${pkgs.llvmPackages_16.libclang.lib}/lib";
        espBoard = "esp32c3";

        # Create a script to set ESP-IDF environment variables
        esp-env-script = pkgs.writeShellScriptBin "esp-env.sh" ''
          # This script sets ESP-IDF environment variables

          # Set paths
          export IDF_PATH="${idfPath}"
          export ESP_ARCH="${espArch}"
          export LIBCLANG_PATH="${libclangPath}"
          export ESP_BOARD="${espBoard}"
          export ESP_IDF_VERSION="v${esp-idf-version}"

          # Configure esp-idf-sys to use files from our ESP-IDF directory
          export ESP_IDF_SDKCONFIG_DEFAULTS="${idfPath}/components/esp_system/include/sdkconfig.h"

          # Allow dynamic binaries to run
          export NIX_ENFORCE_PURITY=0

          echo "ESP-IDF environment set up successfully"
        '';
      in
      {
        devShells.default = pkgs.mkShell.override { stdenv = pkgs.llvmPackages_16.stdenv; } {
          name = "esp32c3-dev-env";

          nativeBuildInputs = with pkgs; [
            # Rust
            rustToolchain

            # ESP environment
            esp-env-script
            esp-idf-tools

            # Cargo tools
            cargo-espflash
            cargo-generate
            cargo-watch

            # ESP tools
            esptool

            # Build tools
            cmake
            ninja
            pkg-config
            llvmPackages_16.clang

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
            ]}:$LD_LIBRARY_PATH

            # Source ESP environment script
            source ${esp-env-script}/bin/esp-env.sh

            # Additional environment variables for esp-idf-sys
            export ESP_IDF_VERSION="v${esp-idf-version}"
            export ESP_IDF_TOOLS_INSTALL_DIR="$HOME/.espressif"

            # Welcome message
            echo "🦀 ESP32-C3 Rust development environment ready"
            echo ""
            echo "Environment variables set:"
            echo "  IDF_PATH=${idfPath}"
            echo "  ESP_ARCH=${espArch}"
            echo "  LIBCLANG_PATH=${libclangPath}"
            echo "  ESP_BOARD=${espBoard}"
            echo "  ESP_IDF_VERSION=v${esp-idf-version}"
            echo ""
            echo "Commands available:"
            echo "  - cargo build --target riscv32imc-unknown-none-elf [--release]"
            echo "  - cargo-espflash <PORT> --target riscv32imc-unknown-none-elf [--release]"
            echo ""
            echo "First-time setup:"
            echo "  To prepare the build environment, run:"
            echo "    mkdir -p $HOME/.espressif"
            echo ""
          '';

          # Include necessary environment variables
          LIBCLANG_PATH = libclangPath;
          IDF_PATH = idfPath;
          ESP_ARCH = espArch;
          ESP_BOARD = espBoard;
          ESP_IDF_VERSION = "v${esp-idf-version}";
          ESP_IDF_TOOLS_INSTALL_DIR = "$HOME/.espressif";
          NIX_ENFORCE_PURITY = 0;
        };
      });
}
