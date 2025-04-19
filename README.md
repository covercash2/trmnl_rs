# `trmnl_rs`

an alternative firmware the [official trmnl firmware](https://github.com/usetrmnl/firmware).

just a hobby project.

## setup

you need to have `nix` installed with flakes enabled: https://nixos.org/download.html

> [!NOTE] i use macOS and nushell and may have built in some opinions.
> i'm open to contributions if there's interest,
> but you can pry nushell out of my cold, dead laptop.

### shell

if you've got [`direnv`](https://direnv.net/),
you can just run `direnv allow` in the root of the project.

otherwise, you can spawn a `bash` shell with `devenv`:

```nu
devenv shell
```

### `just`

can't remember the commands?

```nu
just
# or
just --list
```

## the board

this project is basically a firmware for the [ESP32-C3]

### Rust ESP stuff

a lot of work is based on the [`esp-idf-template`].

[ESP32-C3]: https://www.espressif.com/sites/default/files/documentation/esp32-c3_datasheet_en.pdf
[`esp-idf-template`]: https://github.com/esp-rs/esp-idf-template#prerequisites
