const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "zigworks",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(lib);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_step = b.step("test", "Run library unit tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    const docs_lib = b.addLibrary(.{
        .name = "zigworks_docs",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate HTML documentation");
    docs_step.dependOn(&install_docs.step);

    const serve_exe = b.addExecutable(.{
        .name = "serve_docs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/serve_docs.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run_server = b.addRunArtifact(serve_exe);
    run_server.setCwd(b.path("zig-out/docs"));
    run_server.step.dependOn(&install_docs.step);

    const serve_step = b.step("docs-serve", "Build docs and serve on localhost");
    serve_step.dependOn(&run_server.step);
}
