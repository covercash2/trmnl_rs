# `trmnl_rs`

an alternative firmware the [official trmnl firmware](https://github.com/usetrmnl/firmware).

just a hobby project.

## setup

you need to have `nix` installed with flakes enabled: https://nixos.org/download.html

> [!NOTE]
> i use macOS and nushell and may have built in some opinions.
> i'm open to contributions if there's interest,
> but you can pry nushell out of my cold, dead laptop.

### NixOS weirdness

NixOS doesn't use the [Linux Filesystem Hierarchy Standard (FHS)]
and also doesn't support dynamic linking by default.
while generally dynamic linking is just a pain in the ass,
the consequences of disallowing this is also a pain in the ass.
but me and Copilot figured it out 👍

drop into a [FHS] compatible shell with:

```nu
esp-idf-env
```

this is defined in the `flake.nix` file and is necessary
to build [`esp-idf`] project which is necessary
to install [`esp-idf-sys`], a Rust crate that wraps [`esp-idf`].
you can then call `nu` to use an objectively better shell.

### shell

if you've got [`direnv`](https://direnv.net/),
you can just run `direnv allow` in the root of the project.

otherwise, you can spawn a `bash` shell with Nix:

```nu
nix develop
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

[ESP32-C3]: https://www.espressif.com/sites/default/files/documentation/esp32-c3_datasheet_en.pdf
[Linux Filesystem Hierarchy Standard (FHS)]: https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
[FHS]: https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
[`esp-idf`]: https://github.com/espressif/esp-idf
[`esp-idf-sys`]: https://github.com/esp-rs/esp-idf-sys
