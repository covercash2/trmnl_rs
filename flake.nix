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
        ]);

        # Create a custom esp-idf-tools package with Nix tools
        # This avoids the dynamic linking issues with pre-built binaries
        esp-idf-tools = pkgs.stdenv.mkDerivation {
          name = "esp-idf-tools";
          version = "5.3.2";

          # Create a dummy source
          src = pkgs.writeTextDir "source" "Dummy source for esp-idf-tools";

          nativeBuildInputs = [ pkgs.makeWrapper ];

          # Explicitly disable configure phase to avoid CMake errors
          dontConfigure = true;

          # Disable build phase as we're not building anything
          dontBuild = true;

          installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/share/esp-idf-tools

            # Create a simple IDF_PATH directory structure
            mkdir -p $out/share/esp-idf-tools/esp-idf
            echo "5.3.2" > $out/share/esp-idf-tools/esp-idf/version.txt

            # Create a script to set up the ESP-IDF environment
            cat > $out/bin/esp-idf-export.sh << EOF
            #!/bin/sh

            # ESP-IDF environment variables
            export IDF_PATH="$out/share/esp-idf-tools/esp-idf"
            export ESP_ARCH="riscv32imc-unknown-none-elf"
            export LIBCLANG_PATH="${pkgs.llvmPackages_16.libclang.lib}/lib"

            # Add tools to path
            export PATH="${pkgs.cmake}/bin:${pkgs.ninja}/bin:$PATH"

            # Export environment variables for cargo-espflash
            export ESP_BOARD="esp32c3"
            EOF

            chmod +x $out/bin/esp-idf-export.sh

            # Create drop-in replacements for ESP-IDF tools that use Nix tools
            makeWrapper ${pkgs.cmake}/bin/cmake $out/bin/cmake --set IDF_PATH "$out/share/esp-idf-tools/esp-idf"
            makeWrapper ${pkgs.ninja}/bin/ninja $out/bin/ninja --set IDF_PATH "$out/share/esp-idf-tools/esp-idf"
          '';
        };

        # Define these values here so we can reference them in shellHook
        idfPath = "${esp-idf-tools}/share/esp-idf-tools/esp-idf";
        espArch = "riscv32imc-unknown-none-elf";
        libclangPath = "${pkgs.llvmPackages_16.libclang.lib}/lib";
        espBoard = "esp32c3";
      in
      {
        devShells.default = pkgs.mkShell.override { stdenv = pkgs.llvmPackages_16.stdenv; } {
          name = "esp32c3-dev-env";

          nativeBuildInputs = with pkgs; [
            # Rust
            rustToolchain

            # ESP-IDF tools
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

            # Set up ESP-IDF environment
            export IDF_PATH="${idfPath}"
            export ESP_ARCH="${espArch}"
            export LIBCLANG_PATH="${libclangPath}"
            export ESP_BOARD="${espBoard}"

            # Allow Nix to run dynamically linked binaries
            export NIX_ENFORCE_PURITY=0

            # Welcome message
            echo "🦀 ESP32-C3 Rust development environment ready"
            echo ""
            echo "Environment variables set:"
            echo "  IDF_PATH=${idfPath}"
            echo "  ESP_ARCH=${espArch}"
            echo "  LIBCLANG_PATH=${libclangPath}"
            echo "  ESP_BOARD=${espBoard}"
            echo ""
            echo "Commands available:"
            echo "  - cargo build --target riscv32imc-unknown-none-elf [--release]"
            echo "  - cargo-espflash <PORT> --target riscv32imc-unknown-none-elf [--release]"
            echo ""
          '';

          # Include necessary environment variables
          LIBCLANG_PATH = libclangPath;
          IDF_PATH = idfPath;
          ESP_ARCH = espArch;
          ESP_BOARD = espBoard;
          NIX_ENFORCE_PURITY = 0;
        };
      });
}
