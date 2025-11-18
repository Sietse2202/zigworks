const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const eadk_mod = b.addModule("eadk", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
    });

    eadk_mod.addCSourceFile(.{ .file = b.path("src/storage.c") });
    eadk_mod.addIncludePath(b.path("src"));
}
