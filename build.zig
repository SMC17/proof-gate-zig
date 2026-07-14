const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("proof-gate-zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    _ = mod;

    const lib = b.addLibrary(.{
        .name = "proof-gate-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    b.installArtifact(lib);

    // Tests (default + debug)
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run proof-gate-zig tests");
    test_step.dependOn(&run_tests.step);

    // Release build of the library (compiler as optimizer: -O ReleaseFast).
    const release_opt = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });
    const release_lib = b.addLibrary(.{
        .name = "proof-gate-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = release_opt,
        }),
        .linkage = .static,
    });
    const release_step = b.step("build-release", "Build optimized static library");
    release_step.dependOn(&release_lib.step);

    // Negative CI gate: a refuted claim must NOT compile. `zig build gate-refuted`
    // is expected to FAIL; the workflow treats that failure as the pass signal.
    const neg = b.addExecutable(.{
        .name = "gate_refuted_probe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("ci/gate_refuted_probe.zig"),
            .target = target,
            .optimize = .Debug,
        }),
    });
    const neg_step = b.step("gate-refuted", "Probe that refuted claims are rejected (must FAIL to compile)");
    neg_step.dependOn(&neg.step);
}
