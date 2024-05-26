const std = @import("std");
const c = @cImport({
    @cInclude("GL/glew.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("GL/gl.h");
});

fn glfw_error_callback(@"error": c_int, description: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW error: {s}", .{description});
    _ = @"error";
}

pub const State = struct {
    const Self = @This();
    window: *c.GLFWwindow,
    pub fn init() Self {
        std.log.debug("Initializing GLFW", .{});
        if (c.glfwInit() != c.GLFW_TRUE) {
            @panic("oh no");
        }
        std.log.debug("GLFW initialized", .{});
        const prev_error = c.glfwSetErrorCallback(glfw_error_callback);
        if (prev_error != null) {
            @panic("ho no");
        }

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
        c.glfwWindowHint(c.GLFW_OPENGL_DEBUG_CONTEXT, c.GLFW_TRUE);
        const window: *c.GLFWwindow = c.glfwCreateWindow(640, 480, "My Title", null, null) orelse {
            @panic("no window");
        };

        c.glfwMakeContextCurrent(window);
        const glew_error = c.glewInit();
        if (glew_error != c.GLEW_OK) {
            const error_string = c.glewGetErrorString(glew_error);
            std.log.err("GLEW initialization error: {s}", .{error_string});
            // TODO wtf glew not ok but actually ok @panic("glew not ok");
        }
        return .{
            .window = window,
        };
    }
    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        c.glClearColor(r, g, b, a);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
    }
    pub fn deinit(self: Self) void {
        c.glfwTerminate();
        c.glfwDestroyWindow(self.window);
    }
};
