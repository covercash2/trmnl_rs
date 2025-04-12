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

        # Define constants
        espArch = "riscv32imc-unknown-none-elf";
        espBoard = "esp32c3";
        espIdfVersion = "5.3.2";

        # Create a dummy esp-idf-sys .cargo/config.toml to help with cargo build
        espCargoConfig = pkgs.writeTextFile {
          name = "cargo-config";
          destination = "/cargo-config/config.toml";
          text = ''
            [target.riscv32imc-unknown-none-elf]
            runner = "espflash flash --monitor"
            rustflags = [
              "-C", "link-arg=-nostartfiles",
            ]

            [build]
            target = "riscv32imc-unknown-none-elf"

            [env]
            ESP_IDF_VERSION = "v${espIdfVersion}"
            MCU = "${espBoard}"
            ESP_IDF_SDKCONFIG_DEFAULTS = "./sdkconfig.defaults"
          '';
        };

        # Create sdkconfig.defaults file
        sdkConfig = pkgs.writeTextFile {
          name = "sdkconfig-defaults";
          destination = "/sdkconfig/sdkconfig.defaults";
          text = ''
            CONFIG_IDF_TARGET="${espBoard}"
            CONFIG_IDF_TARGET_ESP32C3=y
            CONFIG_IDF_FIRMWARE_CHIP_ID=0x0005
          '';
        };
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

            # ESP tools
            esptool

            # Build tools
            cmake
            ninja
            pkg-config
            llvmPackages_16.clang
            git

            # Python environment
            pythonEnv

            # Configuration files
            espCargoConfig
            sdkConfig

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

            # Create sdkconfig.defaults in the project directory
            cp ${sdkConfig}/sdkconfig/sdkconfig.defaults ./sdkconfig.defaults

            # Create .cargo/config.toml
            mkdir -p .cargo
            cp ${espCargoConfig}/cargo-config/config.toml .cargo/config.toml

            # Use Rust's cc to build C code
            export CC=gcc
            export CXX=g++

            # ESP environment variables
            export ESP_ARCH="${espArch}"
            export ESP_BOARD="${espBoard}"
            export ESP_IDF_VERSION="v${espIdfVersion}"
            export ESP_IDF_TOOLS_INSTALL_DIR="$HOME/.espressif"
            export ESP_IDF_SDKCONFIG_DEFAULTS="$(pwd)/sdkconfig.defaults"
            export MCU="${espBoard}"

            # Allow Nix to run dynamically linked binaries
            export NIX_ENFORCE_PURITY=0

            # Welcome message
            echo "🦀 ESP32-C3 Rust development environment ready"
            echo ""
            echo "Environment variables set:"
            echo "  ESP_ARCH=${espArch}"
            echo "  ESP_BOARD=${espBoard}"
            echo "  ESP_IDF_VERSION=v${espIdfVersion}"
            echo "  ESP_IDF_SDKCONFIG_DEFAULTS=$(pwd)/sdkconfig.defaults"
            echo "  MCU=${espBoard}"
            echo ""
            echo "Copied configuration files:"
            echo "  sdkconfig.defaults - ESP-IDF configuration"
            echo "  .cargo/config.toml - Cargo configuration"
            echo ""
            echo "Commands:"
            echo "  - cargo build [--release]"
            echo "  - cargo-espflash <PORT> [--release]"
            echo ""
            echo "First-time setup:"
            echo "  To prepare the build environment, you'll need to install ESP-IDF tools."
            echo "  Run: cargo install espup && espup install"
            echo ""
            echo "  This will install ESP-IDF tools in $HOME/.espressif"
            echo ""
          '';

          # Include necessary environment variables
          ESP_ARCH = espArch;
          ESP_BOARD = espBoard;
          ESP_IDF_VERSION = "v${espIdfVersion}";
          MCU = espBoard;
          NIX_ENFORCE_PURITY = 0;

          # Use Rust's cc to build C code
          CC = "gcc";
          CXX = "g++";
        };
      });
}
