# zldr

A fast [tldr](https://tldr.sh/) client written in [Zig](https://ziglang.org/).

## Usage

```
-h, --help                  Print help
-v, --version               Get zldr version 
-p, --platform <platform>   Search using a specific platform
-u, --update                Update the tldr pages cache
-l, --list                  List all available pages
    --list_platforms        List all available platforms
<page>
```

### Building

Currently requires Zig Nightly from 05/05/2024, due to a dependency on `std.zip`.

I plan on adding a Nix flake to make building easier. 

## Tasks
In no particular order:
- [x] Download tldr pages
- [x] Unzip pages to an offline cache
- [x] Search for and print a page
- [ ] Find and use system cache directory 
- [ ] Prettify markdown output
- [ ] Nix flake for building
- [ ] GitHub Actions
- [ ] Support language selection and detection
- [ ] tldr Client Specification Conformance
- [ ] Shell autocompletions

## Credits


- [src/tmpfile.zig](./src/tmpfile.zig) is a modified version of [liyu1981/tmpfile.zig](https://github.com/liyu1981/tmpfile.zig).
- [zig-clap](https://github.com/liyu1981/tmpfile.zig) is used for CLI argument parsing.

