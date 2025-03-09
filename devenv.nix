{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  # https://github.com/esp-rs/esp-idf-template?tab=readme-ov-file#prerequisites
  packages = with pkgs; [
    cargo-espflash
    cargo-generate
    ccache
    cmake
    dfu-util
    espflash
    espup
    git
    gperf
    ldproxy
    libffi
    libusb1
    openssl
    ninja
    nushell
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
    hello
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
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
