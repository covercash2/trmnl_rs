# list recipes
default:
  just --list

# open a shell with the development environment
shell:
  devenv shell

# flash, run, and monitor a release
run_release:
  cargo espflash flash --release --monitor

flash:
  espflash target/riscv32imc-esp-espidf/release/trmnl

test:
  cargo test
