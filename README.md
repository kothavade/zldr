# zldr

A fast [tldr](https://tldr.sh/) client written in [Zig](https://ziglang.org/).

## tldr?

tldr-pages are a collection of short and simple help pages for command line tools, like `man` but simpler.

For example, here is the tldr page for `tar`:

<details>
  <summary>Click to expand</summary>
  
  ### tar

> Archiving utility.
> Often combined with a compression method, such as `gzip` or `bzip2`.
> More information: <https://www.gnu.org/software/tar>.

- [c]reate an archive and write it to a [f]ile:

`tar cf {{path/to/target.tar}} {{path/to/file1 path/to/file2 ...}}`

- [c]reate a g[z]ipped archive and write it to a [f]ile:

`tar czf {{path/to/target.tar.gz}} {{path/to/file1 path/to/file2 ...}}`

- [c]reate a g[z]ipped archive from a directory using relative paths:

`tar czf {{path/to/target.tar.gz}} --directory={{path/to/directory}} .`

- E[x]tract a (compressed) archive [f]ile into the current directory [v]erbosely:

`tar xvf {{path/to/source.tar[.gz|.bz2|.xz]}}`

- E[x]tract a (compressed) archive [f]ile into the target directory:

`tar xf {{path/to/source.tar[.gz|.bz2|.xz]}} --directory={{path/to/directory}}`

- [c]reate a compressed archive and write it to a [f]ile, using the file extension to [a]utomatically determine the compression program:

`tar caf {{path/to/target.tar.xz}} {{path/to/file1 path/to/file2 ...}}`

- Lis[t] the contents of a tar [f]ile [v]erbosely:

`tar tvf {{path/to/source.tar}}`

- E[x]tract files matching a pattern from an archive [f]ile:

`tar xf {{path/to/source.tar}} --wildcards "{{*.html}}"`


</details>


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

```sh
# Debug build
zig build

# Release build
zig build --release=fast # or --release=safe, --release=small depending on your preferences

# Run (after building)
./zig-out/bin/zldr
```


## Tasks
In no particular order:
- [x] Download tldr pages
- [x] Unzip pages to an offline cache
- [x] Search for and print a page
- [ ] Find and use system cache directory
- [ ] If page not in platform or common folder, search other platforms with a warning
- [ ] Prettify markdown output
- [ ] Nix flake for building
- [ ] GitHub Actions
- [ ] Support language selection and detection
- [ ] [tldr-pages client specification](https://github.com/tldr-pages/tldr/blob/main/CLIENT-SPECIFICATION.md) conformance
- [ ] Shell autocompletions
- [ ] Charmbracelet/vhs GIF for README

## Credits


- [src/tmpfile.zig](./src/tmpfile.zig) is a modified version of [liyu1981/tmpfile.zig](https://github.com/liyu1981/tmpfile.zig).
- [zig-clap](https://github.com/liyu1981/tmpfile.zig) is used for CLI argument parsing.

