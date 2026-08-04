const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const is_freestanding = target.result.os.tag == .freestanding;
    const is_wasm = target.result.cpu.arch == .wasm32 or target.result.cpu.arch == .wasm64 or target.result.os.tag == .wasi;

    const zstd_enabled = b.option(bool, "zstd", "Enable Zstandard support") orelse (!is_freestanding and !is_wasm);
    const brotli_enabled = b.option(bool, "brotli", "Enable Brotli support") orelse (!is_freestanding and !is_wasm);

    const build_options = b.addOptions();
    build_options.addOption(bool, "zstd_enabled", zstd_enabled);
    build_options.addOption(bool, "brotli_enabled", brotli_enabled);
    const build_options_mod = build_options.createModule();

    var zstd_mod: ?*std.Build.Module = null;
    var brotli_mod: ?*std.Build.Module = null;

    if (zstd_enabled) {
        const zstd_dep = b.dependency("zstd", .{
            .target = target,
            .optimize = optimize,
        });
        zstd_mod = zstd_dep.module("zstd");
    }

    if (brotli_enabled) {
        const brotli_dep = b.dependency("brotli", .{
            .target = target,
            .optimize = optimize,
        });
        brotli_mod = brotli_dep.module("brotli");
    }

    const archive_module = b.createModule(.{
        .root_source_file = b.path("src/archive.zig"),
    });
    archive_module.addImport("build_options", build_options_mod);
    if (zstd_mod) |mod| archive_module.addImport("zstd", mod);
    if (brotli_mod) |mod| archive_module.addImport("brotli", mod);

    const exposed_module = b.addModule("archive", .{
        .root_source_file = b.path("src/archive.zig"),
    });
    exposed_module.addImport("build_options", build_options_mod);
    if (zstd_mod) |mod| exposed_module.addImport("zstd", mod);
    if (brotli_mod) |mod| exposed_module.addImport("brotli", mod);

    const examples = [_]struct { name: []const u8, path: []const u8, skip_run_all: bool = false }{
        .{ .name = "main", .path = "examples/main.zig" },
    };

    const run_all_examples = b.step("run-all-examples", "Run all examples sequentially");
    var previous_run_step: ?*std.Build.Step = null;
    var install_step: ?*std.Build.Step = null;

    inline for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        exe.root_module.addImport("archive", archive_module);
        exe.root_module.addImport("build_options", build_options_mod);

        const install_exe = b.addInstallArtifact(exe, .{});
        const example_step = b.step("example-" ++ example.name, "Build " ++ example.name ++ " example");
        example_step.dependOn(&install_exe.step);
        install_step = &install_exe.step;

        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        const run_step = b.step("run-" ++ example.name, "Run " ++ example.name ++ " example");
        run_step.dependOn(&run_exe.step);

        if (!example.skip_run_all) {
            const run_all_exe = b.addRunArtifact(exe);
            if (previous_run_step) |prev| {
                run_all_exe.step.dependOn(prev);
            }
            previous_run_step = &run_all_exe.step;
        }
    }

    if (target.result.os.tag == builtin.os.tag and target.result.cpu.arch == builtin.cpu.arch) {
        if (previous_run_step) |last| {
            run_all_examples.dependOn(last);
        }
    } else {
        if (install_step) |step| {
            run_all_examples.dependOn(step);
        }
    }

    const run_step = b.step("run", "Run examples");
    run_step.dependOn(run_all_examples);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/archive.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    tests.root_module.addImport("build_options", build_options_mod);
    if (zstd_mod) |mod| tests.root_module.addImport("zstd", mod);
    if (brotli_mod) |mod| tests.root_module.addImport("brotli", mod);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");

    if (target.result.os.tag == builtin.os.tag and target.result.cpu.arch == builtin.cpu.arch) {
        test_step.dependOn(&run_tests.step);
    } else {
        const install_tests = b.addInstallArtifact(tests, .{});
        test_step.dependOn(&install_tests.step);
    }

    const docs_step = b.step("docs", "Generate documentation");
    const docs_obj = b.addObject(.{
        .name = "archive",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/archive.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    docs_obj.root_module.addImport("build_options", build_options_mod);
    if (zstd_mod) |mod| docs_obj.root_module.addImport("zstd", mod);
    if (brotli_mod) |mod| docs_obj.root_module.addImport("brotli", mod);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    const test_all_step = b.step("test-all", "Run all tests and examples sequentially");
    test_all_step.dependOn(test_step);
    test_all_step.dependOn(run_all_examples);

    const lib = b.addLibrary(.{
        .name = "archive",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/archive.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib.root_module.addImport("build_options", build_options_mod);
    if (zstd_mod) |mod| lib.root_module.addImport("zstd", mod);
    if (brotli_mod) |mod| lib.root_module.addImport("brotli", mod);
    b.installArtifact(lib);
}
