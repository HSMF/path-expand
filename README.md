# path-expand

List files under PATH. In Zig btw.

## Installation

get zig [here](https://ziglang.org/download/)

```sh
$ zig build -Drelease-safe
$ ./zig-out/bin/path-expand
```

Move `./zig-out/bin/path-expand` to a directory in `$PATH`

## Usage Examples

```sh
$ path-expand "$PATH" # default behavior
$ path-expand -s "$PATH" | rg "^go" # list every available binary that starts with go
$ path-expand "$COWPATH" | rg '^vader.cow: (.*)' -r '$1' # print the path of the vader cowfile
```


## License

This project is licensed under [MIT](https://choosealicense.com/licenses/mit/)
