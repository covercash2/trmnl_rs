# `trmnl_rs`

an alternative firmware the [official trmnl firmware](https://github.com/usetrmnl/firmware).

just a hobby project.

## setup

i'm just trying out this `devenv` thing.
my gut says `flakes` is better long term,
but this was simple to setup.

needs to be installed:
```nu
nix profile install nixpkgs#devenv
```

oh, and you need to have `nix` installed: https://nixos.org/download.html

> [!NOTE] i use macOS and nushell and may have built in some opinions.
> i'm open to contributions if there's interest,
> but you can pry nushell out of my cold, dead laptop.

### `devenv`

[`devenv`](https://devenv.sh/getting-started/) is supposed to simplify Nix build environments.
it's not exactly compatible with `nix flakes` yet,
but heck it was kinda easy to setup in comparison.

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
