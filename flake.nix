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

        # Create a proper ESP-IDF environment by fetching the ESP-IDF repo
        esp-idf = pkgs.fetchFromGitHub {
          owner = "espressif";
          repo = "esp-idf";
          rev = "v5.3.2";
          sha256 = "sha256-KHoKgv8yHv+a+HIVkrceeI5eF7MR62UU7ex/lI0jyKM=`";
          fetchSubmodules = false; # We don't need all submodules
        };

        # Create our ESP-IDF tools package
        esp-idf-tools = pkgs.stdenv.mkDerivation {
          name = "esp-idf-tools";
          version = "5.3.2";

          src = esp-idf;

          nativeBuildInputs = [ pkgs.makeWrapper pkgs.git pythonEnv ];

          # Skip configure and build
          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            mkdir -p $out
            cp -r $src/* $out/

            # Create a script to set up environment variables
            mkdir -p $out/bin
            cat > $out/bin/esp-idf-export.sh << EOF
            #!/bin/sh

            # ESP-IDF environment variables
            export IDF_PATH="$out"
            export ESP_ARCH="riscv32imc-unknown-none-elf"
            export LIBCLANG_PATH="${pkgs.llvmPackages_16.libclang.lib}/lib"

            # Set up the build environment
            export ESP_BOARD="esp32c3"

            # Add tools to path
            export PATH="${pkgs.cmake}/bin:${pkgs.ninja}/bin:$PATH"
            EOF

            chmod +x $out/bin/esp-idf-export.sh

            # Create version.json for esp-idf-sys to recognize
            echo '{"version": "v5.3.2", "git_revision": "v5.3.2"}' > $out/version.json

            # Create a git repo to make esp-idf-sys happy
            cd $out
            git init .
            git config --local user.email "nix@example.com"
            git config --local user.name "Nix Build"
            git add .
            git commit -m "Initial commit"
            git tag -a v5.3.2 -m "v5.3.2"
          '';
        };

        # Define these values for shellHook
        idfPath = "${esp-idf-tools}";
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
            git

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
