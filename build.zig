// Farming clicks by offending rust devs.
// riir
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zeng_module = b.addModule("zeng", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const example_exe = b.addExecutable(.{
        .name = "zeng-example",
        .root_source_file = b.path("examples/example.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (!target.result.isWasm()) {
        example_exe.linkSystemLibrary("GLEW");
        example_exe.linkSystemLibrary("glfw");
        example_exe.linkSystemLibrary("GL");
        example_exe.linkLibC();
    }
    example_exe.root_module.addImport("zeng", zeng_module);
    // example_exe.modu(lib);

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
        for ([_][]const u8{ "index.html", "zeng.js", "zeng.css" }) |file| {
            const install = b.addInstallFile(b.path(file), std.fs.path.join(b.allocator, &.{ "dist", file }) catch @panic("oom"));
            install.step.dependOn(&dist_clean.step);
            dist.dependOn(&install.step);
        }
        example_exe.rdynamic = true;
    }

    const run = b.step("run", "Run the example");
    const run_cmd = b.addRunArtifact(example_exe);
    if (b.args) |args| {
        // TODO set cwd to dist
        run_cmd.addArgs(args);
    }
    run.dependOn(&run_cmd.step);
}
