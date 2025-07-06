const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libsodium = b.dependency("libsodium", .{
        .static = true,
        .shared = false,
    });

    const mod_zodium = b.addModule("zodium", .{
        .root_source_file = b.path("src/root.zig"),
        .link_libc = true,
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "zodium",
        .root_module = mod_zodium,
    });

    b.installArtifact(lib);

    // Documentation generation
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = mod_zodium,
    });

    mod_zodium.linkLibrary(libsodium.artifact(if (target.result.isMinGW()) "libsodium-static" else "sodium")));

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const bench = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&bench.step);

    const zbench_dep = b.dependency("zbench", .{});
    const zbench_mod = zbench_dep.module("zbench");
    bench.root_module.addImport("zodium", mod_zodium);
    bench.root_module.addImport("zbench", zbench_mod);
    bench.linkLibrary(libsodium.artifact(if (target.result.isMinGW()) "libsodium-static" else "sodium")));

    const bench_install = b.addRunArtifact(bench);
    bench_step.dependOn(&bench_install.step);
}
