// Farming clicks by offending rust devs.
// riir
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zeng",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const example_exe = b.addExecutable(.{
        .name = "zeng-example",
        .root_source_file = b.path("examples/example.zig"),
        .target = target,
        .optimize = optimize,
    });

    const dist = b.step("dist", "do dist");
    const dist_clean = b.addRemoveDirTree(std.fs.path.join(b.allocator, &.{
        b.install_prefix,
        "dist",
    }) catch @panic("oom"));
    dist.dependOn(&dist_clean.step);
    dist.dependOn(&example_exe.step);
    const dist_install_exe = b.addInstallArtifact(example_exe, .{ .dest_dir = .{ .override = .{
        .custom = "dist",
    } } });
    dist_install_exe.step.dependOn(&dist_clean.step);
    dist.dependOn(&dist_install_exe.step);

    if (target.result.isWasm()) {
        const index_html = b.addInstallFile(b.path("index.html"), "dist/index.html");
        index_html.step.dependOn(&dist_clean.step);
        dist.dependOn(&index_html.step);
    }

    const run_example = b.step("run-example", "Run the example");
    const example_run_cmd = b.addRunArtifact(example_exe);
    if (b.args) |args| {
        example_run_cmd.addArgs(args);
    }
    run_example.dependOn(&example_run_cmd.step);

    const triangle_exe = b.addExecutable(.{
        .name = "zeng-triangle",
        .root_source_file = b.path("examples/triangle.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(triangle_exe);
    const triangle_run_cmd = b.addRunArtifact(triangle_exe);
    if (b.args) |args| {
        triangle_run_cmd.addArgs(args);
    }
    const run_step = b.step("run-triangle", "Run the triangle example");
    run_step.dependOn(&triangle_run_cmd.step);
    if (!target.result.isWasm()) {
        triangle_exe.linkSystemLibrary("GLEW");
        triangle_exe.linkSystemLibrary("glfw");
        triangle_exe.linkSystemLibrary("GL");
        triangle_exe.linkLibC();
    }
}
