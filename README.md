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

## Fast?

Here are some rudimentary benchmarks of `zldr` against [tealdeer](https://github.com/dbrgn/tealdeer), [tlrc](https://github.com/tldr-pages/tlrc), and [tldr-c-client](https://github.com/tldr-pages/tldr-c-client) using [hyperfine](https://github.com/sharkdp/hyperfine) on my machine. Each of the other clients was downloaded from nixpkgs, presumably build their respective release modes, and `zldr` was built with `--release=fast`.

```
~/code/zldr main* 11s  impure λ hyperfine "/nix/store/...-tealdeer-1.6.1/bin/tldr ip" -n "tealdeer (rust, unoffical)" "/nix/store/...-tlrc-1.9.2/bin/tldr ip" -n "tlrc (rust, offical)" "/nix/store/...-tldr-1.6.1/bin/tldr ip" -n "tldr-c (c, offical)" "./zig-out/bin/zldr ip" -n "zldr (zig, unoffical)" -N --warmup 10

Benchmark 1: tealdeer (rust, unoffical)
  Time (mean ± σ):     806.1 µs ±  61.6 µs    [User: 258.8 µs, System: 480.5 µs]
  Range (min … max):   659.9 µs … 1045.6 µs    2886 runs
 
Benchmark 2: tlrc (rust, offical)
  Time (mean ± σ):     913.7 µs ±  65.5 µs    [User: 257.1 µs, System: 585.5 µs]
  Range (min … max):   754.0 µs … 1201.1 µs    3819 runs
 
Benchmark 3: tldr-c (c, offical)
  Time (mean ± σ):       2.4 ms ±   0.1 ms    [User: 0.8 ms, System: 1.5 ms]
  Range (min … max):     2.2 ms …   2.9 ms    1298 runs
 
Benchmark 4: zldr (zig, unoffical)
  Time (mean ± σ):     432.2 µs ±  41.0 µs    [User: 253.4 µs, System: 121.4 µs]
  Range (min … max):   360.7 µs … 656.8 µs    7077 runs
 
Summary
  zldr (zig, unoffical) ran
    1.87 ± 0.23 times faster than tealdeer (rust, unoffical)
    2.11 ± 0.25 times faster than tlrc (rust, offical)
    5.54 ± 0.56 times faster than tldr-c (c, offical)
```

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

## Building

Currently requires the latest Zig Nightly (`0.13.0-dev.351+64ef45eb0`).

```sh
# A Nix flake is provided to ease both building and development:
nix build
nix develop # or use direnv

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
- [x] Find and use system cache directory
- [x] If page not in platform or common folder, search other platforms with a warning
- [x] Prettify markdown output
- [x] Nix flake for building
- [ ] GitHub Actions
- [ ] Support language selection and detection
- [ ] [tldr-pages client specification](https://github.com/tldr-pages/tldr/blob/main/CLIENT-SPECIFICATION.md) conformance
- [ ] Shell autocompletions
- [ ] [charmbracelet/vhs](https://github.com/charmbracelet/vhs) GIF for README
- [ ] Add tests
- [ ] use `std.Progress`

## Credits


- [GitRepoStep.zig](./GitRepoStep.zig) is a modified version of [marler8997/zig-build-repos](https://github.com/marler8997/zig-build-repos) used for package management.
- [src/tmpfile.zig](./src/tmpfile.zig) is a modified version of [liyu1981/tmpfile.zig](https://github.com/liyu1981/tmpfile.zig).
- [zig-clap](https://github.com/liyu1981/tmpfile.zig) is used for CLI argument parsing.
- [ziglibs/known-folders](https://github.com/ziglibs/known-folders) is used to find the cache directory.

