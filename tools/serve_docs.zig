const std = @import("std");
const builtin = @import("builtin");

const gpa = std.heap.smp_allocator;
var root_dir: std.fs.Dir = undefined;

const no_cache: std.http.Header = .{
    .name  = "cache-control",
    .value = "max-age=0, must-revalidate",
};

pub fn main() !void {
    root_dir = std.fs.cwd();
    defer root_dir.close();

    const address = try std.net.Address.parseIp("127.0.0.1", 0);
    var server  = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    const port = server.listen_address.in.getPort();
    const url  = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/", .{port});
    defer gpa.free(url);

    std.log.info("Docs available at {s}", .{url});
    try openBrowser(url);

    while (true) {
        const conn = try server.accept();
        _ = std.Thread.spawn(.{}, handleConn, .{conn}) catch |e| {
            std.log.err("spawn failed: {}", .{e});
            conn.stream.close();
        };
    }
}

fn handleConn(conn: std.net.Server.Connection) void {
    defer conn.stream.close();
    var rbuf: [8192]u8 = undefined;
    var wbuf: [8192]u8 = undefined;
    var rdr = conn.stream.reader(&rbuf);
    var wtr = conn.stream.writer(&wbuf);
    var http = std.http.Server.init(rdr.interface(), &wtr.interface);

    while (http.reader.state == .ready) {
        var req = http.receiveHead() catch |e| switch (e) {
            error.HttpConnectionClosing => return,
            else => { std.log.err("receiveHead: {}", .{e}); return; },
        };
        serveFile(&req) catch |e| std.log.err("serve: {}", .{e});
    }
}

fn serveFile(req: *std.http.Server.Request) !void {
    const target = req.head.target;
    const path = if (std.mem.indexOfScalar(u8, target, '?')) |i| target[0..i] else target;
    const file_path: []const u8 = if (std.mem.eql(u8, path, "/"))
        "index.html"
    else
        path[1..];

    const content_type = sniffType(file_path);

    const body = root_dir.readFileAlloc(gpa, file_path, 64 * 1024 * 1024) catch |e| {
        const msg = std.fmt.allocPrint(gpa, "not found: {}", .{e}) catch "not found";
        try req.respond(msg, .{ .status = .not_found });
        return;
    };
    defer gpa.free(body);

    try req.respond(body, .{
        .extra_headers = &.{
            .{ .name = "content-type", .value = content_type },
            no_cache,
        },
    });
}

fn sniffType(path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, path, ".html")) return "text/html";
    if (std.mem.endsWith(u8, path, ".js"))   return "application/javascript";
    if (std.mem.endsWith(u8, path, ".wasm")) return "application/wasm";
    if (std.mem.endsWith(u8, path, ".tar"))  return "application/x-tar";
    return "application/octet-stream";
}

fn openBrowser(url: []const u8) !void {
    const cmd: []const []const u8 = switch (builtin.os.tag) {
        .macos   => &.{ "open",    url },
        .windows => &.{ "cmd", "/c", "start", url },
        else     => &.{ "xdg-open", url },
    };
    var child = std.process.Child.init(cmd, gpa);
    child.stdin_behavior  = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = try child.spawnAndWait();
}
