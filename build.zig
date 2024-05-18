// Farming clicks by offending rust devs.
const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zeng",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    const triangle_exe = b.addExecutable(.{
        .name = "zeng-triangle",
        .root_source_file = b.path("examples/triangle.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(triangle_exe);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    // b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const triangle_run_cmd = b.addRunArtifact(triangle_exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    // run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        triangle_run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run-triangle", "Run the triangle example");
    run_step.dependOn(&triangle_run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    triangle_exe.linkSystemLibrary("GLEW");
    triangle_exe.linkSystemLibrary("glfw");
    triangle_exe.linkSystemLibrary("GL");
    triangle_exe.linkLibC();

    // const glfw_cmake_command = b.addSystemCommand(&[_][]const u8{"cmake"});
    // const glfw_step = b.step("glfw", "Do the GLFW");
    // glfw_step.dependOn(&glfw_cmake_command.step);
    //
    // const glfw_dep = b.dependency("glfw", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // glfw_cmake_command.addArgs(&.{ "-S", glfw_dep.path("").getPath(b) });

    // const glfw_library = b.addStaticLibrary(.{
    //     .name = "glfw",
    //     .target = target,
    //     .optimize = optimize,
    // });

    // glfw_library.addCSourceFiles(.{
    //     .root = glfw_dep.path(""),
    //     .files = &.{"btree.c"},
    // });
    // glfw_library.installHeadersDirectory(dep_btree_c.path(""), "", .{
    //     .include_extensions = &.{"btree.h"},
    // });

    // const raylib_dep = b.dependency("raylib-zig", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .linux_display_backend = .Wayland,
    // });

    // const glfw_artifact = glfw_dep.artifact("glfw");
    //
    // triangle_exe.linkLibrary(glfw_artifact);

    // const raylib = raylib_dep.module("raylib"); // main raylib module
    // const raylib_math = raylib_dep.module("raylib-math"); // raymath module
    // const rlgl = raylib_dep.module("rlgl"); // rlgl module
    // const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    // exe.linkLibrary(raylib_artifact);
    // exe.root_module.addImport("raylib", raylib);
    // exe.root_module.addImport("raylib-math", raylib_math);
    // exe.root_module.addImport("rlgl", rlgl);
}
