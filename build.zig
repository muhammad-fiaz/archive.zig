const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Resolve zstd dependency
    const zstd_dep = b.dependency("zstd", .{
        .target = target,
        .optimize = optimize,
    });
    const zstd_mod = zstd_dep.module("zstd");

    // Resolve brotli dependency
    const brotli_dep = b.dependency("brotli", .{
        .target = target,
        .optimize = optimize,
    });
    const brotli_mod = brotli_dep.module("brotli");

    // Create the archive module with zstd and brotli support
    const archive_module = b.createModule(.{
        .root_source_file = b.path("src/archive.zig"),
    });
    archive_module.addImport("zstd", zstd_mod);
    archive_module.addImport("brotli", brotli_mod);

    // Expose the module for external projects that depend on this package.
    // This allows users to do: `const archive = @import("archive");` in their code
    // after adding archive as a dependency and calling `dep.module("archive")` in their build.zig
    const exposed_module = b.addModule("archive", .{
        .root_source_file = b.path("src/archive.zig"),
    });
    exposed_module.addImport("zstd", zstd_mod);
    exposed_module.addImport("brotli", brotli_mod);

    const examples = [_]struct { name: []const u8, path: []const u8, skip_run_all: bool = false }{
        .{ .name = "main", .path = "examples/main.zig" },
    };

    // Create run-all-examples step that runs all examples sequentially
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

        const install_exe = b.addInstallArtifact(exe, .{});
        const example_step = b.step("example-" ++ example.name, "Build " ++ example.name ++ " example");
        example_step.dependOn(&install_exe.step);
        install_step = &install_exe.step;

        // Add run step for each example
        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        const run_step = b.step("run-" ++ example.name, "Run " ++ example.name ++ " example");
        run_step.dependOn(&run_exe.step);

        if (!example.skip_run_all) {
            // Re-use the same executable artifact for run-all sequence
            const run_all_exe = b.addRunArtifact(exe);
            // Make each run step depend on the previous run step to ensure sequential execution
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
        // For cross-compilation, just build the examples
        if (install_step) |step| {
            run_all_examples.dependOn(step);
        }
    }

    // Add a 'run' step that runs all examples
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
    tests.root_module.addImport("zstd", zstd_mod);
    tests.root_module.addImport("brotli", brotli_mod);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");

    // Only run tests if compatible with host
    if (target.result.os.tag == builtin.os.tag and target.result.cpu.arch == builtin.cpu.arch) {
        test_step.dependOn(&run_tests.step);
    } else {
        const install_tests = b.addInstallArtifact(tests, .{});
        test_step.dependOn(&install_tests.step);
    }

    // Docs generation
    const docs_step = b.step("docs", "Generate documentation");
    const docs_obj = b.addObject(.{
        .name = "archive",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/archive.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    docs_obj.root_module.addImport("zstd", zstd_mod);
    docs_obj.root_module.addImport("brotli", brotli_mod);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    // Create comprehensive test-all step that runs everything sequentially
    const test_all_step = b.step("test-all", "Run all tests and examples sequentially");
    // First run unit tests
    test_all_step.dependOn(test_step);
    // Then run all examples
    test_all_step.dependOn(run_all_examples);

    // Install step for library
    const lib = b.addLibrary(.{
        .name = "archive",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/archive.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib.root_module.addImport("zstd", zstd_mod);
    lib.root_module.addImport("brotli", brotli_mod);
    b.installArtifact(lib);
}
