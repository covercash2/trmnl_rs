{
  description = "RISC-V GDB for ESP32";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    with flake-utils.lib; eachSystem allSystems (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in rec {
      packages = {
        risc32-esp-elf-gdb = pkgs.stdenv.mkDerivation {
          name = "risc32-esp-elf-gdb";
          version = "14.2";
          src = builtins.fetchGit {
            url = "https://github.com/espressif/binutils-gdb.git";
            ref = "esp-gdb-14.2";
            rev = "e69f44938cdf43fd73f6adba2575de9121fbf683";
          };
          buildPhase = ''
            ./configure
            make
          '';
          installPhase = ''
            runHook preInstall
            install -m755 risc32-esp-elf-gdb $out/bin/risc32-esp-elf-gdb
            runHook postInstall
          '';
        };
      };
      defaultPackage = packages.risc32-esp-elf-gdb;
    });
}
