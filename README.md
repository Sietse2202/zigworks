# zigworks
Zig bindings for [eadk.h](https://github.com/numworks/epsilon/blob/master/eadk/include/eadk/eadk.h)

## How to use
```sh
$ zig fetch --save=zigworks https://github.com/Sietse2202/zigworks/archive/refs/tags/v1.0.0-rc.1.tar.gz
```

and then in your `build.zig`, add these two lines:
```zig
const eadk = b.dependency("zigworks", .{});
<obj>.root_module.addImport("eadk", eadk.module("eadk"));
```
where `<obj>` is your output exe/object

## License
This project is dual licensed under [Apache-2.0](LICENSE-APACHE) and [MIT](LICENSE-MIT) at your wish.
