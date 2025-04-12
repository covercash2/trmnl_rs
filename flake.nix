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

        # Create .cargo/config.toml with proper settings for ESP32-C3
        espCargoConfig = pkgs.writeTextFile {
          name = "cargo-config";
          destination = "/cargo-config/config.toml";
          text = ''
            [build]
            target = "riscv32imc-unknown-none-elf"

            [target.riscv32imc-unknown-none-elf]
            runner = "espflash flash --monitor"
            rustflags = [
              "-C", "link-arg=-nostartfiles",
              "-C", "link-arg=-Wl,-Tlink.x",
              "-C", "force-frame-pointers=yes",
            ]

            [unstable]
            build-std = ["std", "panic_abort", "core", "alloc"]
            build-std-features = ["panic_immediate_abort"]

            [env]
            ESP_IDF_VERSION = "v${espIdfVersion}"
            MCU = "${espBoard}"
            ESP_IDF_SDKCONFIG_DEFAULTS = "./sdkconfig.defaults"
            ESP_IDF_TOOLS_INSTALL_DIR = "~/.espressif"
            RUST_ESP32_STD_HELLO_GPIO = "2"
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
            CONFIG_ESP_SYSTEM_PANIC_PRINT_REBOOT=y
            CONFIG_ESP_CONSOLE_UART_DEFAULT=y
          '';
        };

        # Create a script to install ESP tools
        espToolsInstaller = pkgs.writeShellScriptBin "install-esp-tools" ''
          #!/usr/bin/env bash
          echo "Installing ESP tools..."
          cargo install espup
          espup install --targets riscv32imc-esp-espidf
          echo "ESP tools installed. You'll need to restart your shell."
          echo 'Make sure to run `source $HOME/.espressif/esp-idf/export.sh` in your shell before building.'
        '';

        # Create a script to build the project
        buildScript = pkgs.writeShellScriptBin "esp-build" ''
          #!/usr/bin/env bash
          echo "Building ESP32-C3 project..."
          RUSTFLAGS="--cfg espidf_time64" cargo build --release -Z build-std=std,panic_abort --target riscv32imc-unknown-none-elf
        '';

        # Create a script to flash the project
        flashScript = pkgs.writeShellScriptBin "esp-flash" ''
          #!/usr/bin/env bash
          if [ -z "$1" ]; then
            echo "Usage: esp-flash <PORT>"
            echo "Example: esp-flash /dev/ttyUSB0"
            exit 1
          fi
          echo "Flashing to $1..."
          cargo-espflash $1 --target riscv32imc-unknown-none-elf --release
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

            # ESP tools
            esptool

            # Custom scripts
            espToolsInstaller
            buildScript
            flashScript

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

            # ESP environment variables
            export ESP_ARCH="${espArch}"
            export ESP_BOARD="${espBoard}"
            export ESP_IDF_VERSION="v${espIdfVersion}"
            export ESP_IDF_TOOLS_INSTALL_DIR="$HOME/.espressif"
            export ESP_IDF_SDKCONFIG_DEFAULTS="$(pwd)/sdkconfig.defaults"
            export MCU="${espBoard}"

            # Rust environment variables
            export RUSTFLAGS="--cfg espidf_time64"
            export RUST_BACKTRACE=1

            # Allow Nix to run dynamically linked binaries
            export NIX_ENFORCE_PURITY=0

            # Source ESP-IDF export script if it exists
            if [ -f "$HOME/.espressif/esp-idf/export.sh" ]; then
              source "$HOME/.espressif/esp-idf/export.sh" > /dev/null 2>&1 || true
            fi

            # Welcome message
            echo "🦀 ESP32-C3 Rust development environment ready"
            echo ""
            echo "Environment variables set:"
            echo "  ESP_ARCH=${espArch}"
            echo "  ESP_BOARD=${espBoard}"
            echo "  ESP_IDF_VERSION=v${espIdfVersion}"
            echo ""
            echo "Setup Instructions:"
            echo "  1. First time? Run: install-esp-tools"
            echo "     This installs ESP-IDF tools in $HOME/.espressif"
            echo ""
            echo "  2. After installation, run: source $HOME/.espressif/esp-idf/export.sh"
            echo ""
            echo "Building Commands:"
            echo "  - Build:  esp-build"
            echo "  - Flash:  esp-flash <PORT>  (e.g., esp-flash /dev/ttyUSB0)"
            echo ""
            echo "Manual Commands:"
            echo "  - Build:  RUSTFLAGS=\"--cfg espidf_time64\" cargo build --release -Z build-std=std,panic_abort --target riscv32imc-unknown-none-elf"
            echo "  - Flash:  cargo-espflash <PORT> --target riscv32imc-unknown-none-elf --release"
            echo ""
          '';

          # Include necessary environment variables
          ESP_ARCH = espArch;
          ESP_BOARD = espBoard;
          ESP_IDF_VERSION = "v${espIdfVersion}";
          MCU = espBoard;
          NIX_ENFORCE_PURITY = 0;
          RUSTFLAGS = "--cfg espidf_time64";
          RUST_BACKTRACE = 1;
        };
      });
}
