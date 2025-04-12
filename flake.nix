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
          '';
        };

        # Create a Cargo.toml patch to enforce ESP32-C3 compatibility
        cargoTomlPatch = pkgs.writeTextFile {
          name = "cargo-toml-patch";
          destination = "/cargo-patch/patch-dependencies.sh";
          executable = true;
          text = ''
            #!/usr/bin/env bash

            # Check if Cargo.toml exists
            if [ ! -f "Cargo.toml" ]; then
              echo "Error: Cargo.toml not found in current directory."
              exit 1
            fi

            # Backup original Cargo.toml
            cp Cargo.toml Cargo.toml.bak

            # Ensure esp-idf-sys has esp32c3 feature enabled
            if grep -q "esp-idf-sys" Cargo.toml; then
              # If dependencies are in [dependencies] section with version numbers
              sed -i 's/esp-idf-sys\s*=\s*{\s*version\s*=\s*"\([^"]*\)"[^}]*}/esp-idf-sys = { version = "\1", features = ["esp32c3"] }/g' Cargo.toml
              # If dependencies are just version strings
              sed -i 's/esp-idf-sys\s*=\s*"\([^"]*\)"/esp-idf-sys = { version = "\1", features = ["esp32c3"] }/g' Cargo.toml
              # If esp-idf-sys is already a table but doesn't have features
              sed -i '/esp-idf-sys\s*=\s*{/ {
                /features\s*=/ ! s/esp-idf-sys\s*=\s*{/esp-idf-sys = { features = ["esp32c3"], /
              }' Cargo.toml
            else
              # Add esp-idf-sys dependency if it doesn't exist
              echo 'esp-idf-sys = { version = "0.36.1", features = ["esp32c3"] }' >> Cargo.toml
            fi

            echo "Updated Cargo.toml to use esp-idf-sys with esp32c3 feature"
            echo "Original file saved as Cargo.toml.bak"
          '';
        };

        # Create a script to install ESP tools
        espToolsInstaller = pkgs.writeShellScriptBin "install-esp-tools" ''
          #!/usr/bin/env bash
          echo "Installing ESP tools..."
          cargo install espup
          espup install --targets riscv32imc-esp-espidf
          echo ""
          echo "ESP tools installed. You'll need to restart your shell."
          echo 'Make sure to run `source $HOME/.espressif/esp-idf/export.sh` in your shell before building.'
        '';

        # Create a script to initialize a new project
        projectInitializer = pkgs.writeShellScriptBin "init-esp-project" ''
          #!/usr/bin/env bash
          echo "Initializing ESP32-C3 project..."

          # Apply the Cargo.toml patch
          bash ${cargoTomlPatch}/cargo-patch/patch-dependencies.sh

          # Create a basic .cargo/config.toml file
          mkdir -p .cargo
          cp ${espCargoConfig}/cargo-config/config.toml .cargo/config.toml

          # Create an sdkconfig.defaults file for ESP32-C3
          cat > sdkconfig.defaults << EOF
          CONFIG_IDF_TARGET="${espBoard}"
          CONFIG_IDF_TARGET_ESP32C3=y
          CONFIG_IDF_FIRMWARE_CHIP_ID=0x0005
          CONFIG_ESP_SYSTEM_PANIC_PRINT_REBOOT=y
          CONFIG_ESP_CONSOLE_UART_DEFAULT=y
          EOF

          echo ""
          echo "Project initialized for ESP32-C3."
          echo "Make sure to run 'install-esp-tools' if you haven't already."
        '';

        # Create a script to build the project
        buildScript = pkgs.writeShellScriptBin "esp-build" ''
          #!/usr/bin/env bash
          echo "Building ESP32-C3 project..."

          if [ ! -f "$HOME/.espressif/esp-idf/export.sh" ]; then
            echo "Error: ESP-IDF not found. Please run 'install-esp-tools' first."
            exit 1
          fi

          # Source ESP-IDF environment
          source "$HOME/.espressif/esp-idf/export.sh" > /dev/null 2>&1

          # Build with appropriate flags
          RUSTFLAGS="--cfg espidf_time64" cargo build --release -Z build-std=std,panic_abort --target riscv32imc-unknown-none-elf

          if [ $? -eq 0 ]; then
            echo ""
            echo "Build succeeded! Use 'esp-flash <PORT>' to flash to your device."
          else
            echo ""
            echo "Build failed."
          fi
        '';

        # Create a script to flash the project
        flashScript = pkgs.writeShellScriptBin "esp-flash" ''
          #!/usr/bin/env bash
          if [ -z "$1" ]; then
            echo "Usage: esp-flash <PORT>"
            echo "Example: esp-flash /dev/ttyUSB0"
            exit 1
          fi

          if [ ! -f "$HOME/.espressif/esp-idf/export.sh" ]; then
            echo "Error: ESP-IDF not found. Please run 'install-esp-tools' first."
            exit 1
          fi

          # Source ESP-IDF environment
          source "$HOME/.espressif/esp-idf/export.sh" > /dev/null 2>&1

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
            projectInitializer
            buildScript
            flashScript
            cargoTomlPatch

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

            # ESP environment variables
            export ESP_ARCH="${espArch}"
            export ESP_BOARD="${espBoard}"
            export ESP_IDF_VERSION="v${espIdfVersion}"
            export ESP_IDF_TOOLS_INSTALL_DIR="$HOME/.espressif"
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
            echo "Getting Started:"
            echo "  1. Initialize project: init-esp-project"
            echo "  2. Install ESP-IDF:   install-esp-tools"
            echo "  3. Build project:     esp-build"
            echo "  4. Flash to device:   esp-flash <PORT>"
            echo ""
            echo "Make sure your Cargo.toml includes:"
            echo "  esp-idf-sys = { version = \"0.36.1\", features = [\"esp32c3\"] }"
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
