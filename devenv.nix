{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env = {
    TOML_CFG = "require_cfg_present";
    LIBCLANG_PATH = "/Users/chrash/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-18.1.2_20240912/esp-clang/lib";
    PATH = "/Users/chrash/.rustup/toolchains/esp/xtensa-esp-elf/esp-14.2.0_20240906/xtensa-esp-elf/bin:$PATH";
  };

  # https://devenv.sh/packages/
  # https://github.com/esp-rs/esp-idf-template?tab=readme-ov-file#prerequisites
  packages = with pkgs; [
    cargo-espflash
    cargo-generate
    ccache
    cmake
    curl
    dfu-util
    espflash
    esptool # Python utility for messing with the bootloader
    espup
    git
    gperf
    ldproxy
    libffi
    libusb1
    ninja
    nushell
    openssl
    rustup
    uv
    wget
  ];

  # https://devenv.sh/languages/
  languages = {
    rust = {
      enable = true;
      channel = "nightly";
      components = [
        "rustc" "cargo" "clippy" "rustfmt" "rust-analyzer" "rust-src"
      ];
      # targets = [
      #   "riscv32imc-unknown-none-elf"
      #   "riscv32imac-unknown-none-elf"
      #   "riscv32imafc-unknown-none-elf"
      # ];
      # rustflags = "-Z build-std";
    };
    python = {
      enable = true;
    };
  };

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts = {
    generate-project = {
      exec = ''
        cargo generate esp-rs/esp-idf-template cargo
      '';
    };
  };

  enterShell = ''
    git --version
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };
  # tasks = {
  #   "cargo:init" = {
  #     # https://docs.esp-rs.org/book/writing-your-own-application/generate-project/index.html#esp-idf-template
  #     exec = "cargo generate esp-rs/esp-idf-template cargo";
  #   };
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    cargo test
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
