const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.addModule("eadk", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "zigworks",
        .linkage = .static,
        .root_module = root_module,
    });

    b.installArtifact(lib);

    const unit_tests = b.addTest(.{
        .root_module = root_module,
    });

    const test_step = b.step("test", "Run library unit tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    const docs_lib = b.addLibrary(.{
        .name = "zigworks_docs",
        .linkage = .static,
        .root_module = root_module,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate HTML documentation");
    docs_step.dependOn(&install_docs.step);
}
