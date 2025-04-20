# list recipes
default:
  just --list

flash_debug:
  cargo espflash flash

# flash, run, and monitor a release
flash_release:
  cargo espflash flash --release --monitor

check_board:
  espflash board-info

test:
  cargo test
