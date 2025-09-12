# zigworks
Zig bindings for [EADK]()

## How to use
```bash
$ zig fetch --save=zigworks https://github.com/Sietse2202/zigworks/archive/refs/tags/v1.0.0-rc.1.tar.gz
```
then add these two lines to your `build.zig`:
```zig
const eadk = b.dependency("zigworks", .{});
obj.root_module.addImport("eadk", eadk.module("eadk"));
```

## License
This project is dual licensed under [Apache-2.0](LICENSE-APACHE) and [MIT](LICENSE-MIT) at your wish.
