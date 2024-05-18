const std = @import("std");

const c = @cImport({
    @cInclude("GL/glew.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("GL/gl.h");
});

fn error_callback(@"error": c_int, description: [*c]const u8) callconv(.C) void {
    std.log.err("{s}", .{description});
    _ = @"error";
}

const Shader = struct {
    shader: c.GLuint,

    fn init(@"type": c.GLuint, source: []const u8, alloc: std.mem.Allocator) Shader {
        // https://github.com/ziglang/zig/issues/8898
        const shader = c.__glewCreateShader.?(@"type");
        if (shader == 0) {
            @panic("shader zero");
        }
        c.__glewShaderSource.?(shader, 1, &source.ptr, &@as(c.GLint, @intCast(source.len)));
        c.__glewCompileShader.?(shader);
        var status: c.GLint = undefined;
        c.__glewGetShaderiv.?(shader, c.GL_COMPILE_STATUS, &status);
        if (status != c.GL_TRUE) {
            var log_len: c.GLint = undefined;
            c.__glewGetShaderiv.?(shader, c.GL_INFO_LOG_LENGTH, &log_len);
            const buffer: []u8 = alloc.alloc(u8, @intCast(log_len)) catch {
                @panic("out of memory while getting shader compilation log");
            };
            var actual_len: c.GLint = undefined;
            c.__glewGetShaderInfoLog.?(shader, log_len, &actual_len, buffer.ptr);
            std.debug.assert(log_len == actual_len + 1);
            std.log.err("{s}", .{buffer});
            @panic("shader no compile");
        }
        return .{
            .shader = shader,
        };
    }

    fn deinit(self: Shader) void {
        c.__glewDeleteShader.?(self.shader);
    }
};

const Attribute = struct {};
const Uniform = struct {};

const Program = struct {
    const Self = @This();
    program: c.GLuint,
    attributes: std.StringHashMap(Attribute),
    uniforms: std.StringHashMap(Uniform),

    fn init(shaders: []const Shader, alloc: std.mem.Allocator) Self {
        const program = c.__glewCreateProgram.?();
        if (program == 0) {
            @panic("program zero");
        }

        for (shaders) |shader| {
            c.__glewAttachShader.?(program, shader.shader);
        }

        c.__glewLinkProgram.?(program);
        var status: c.GLint = undefined;
        c.__glewGetProgramiv.?(program, c.GL_LINK_STATUS, &status);
        if (status != c.GL_TRUE) {
            var log_len: c.GLint = undefined;
            c.__glewGetProgramiv.?(program, c.GL_INFO_LOG_LENGTH, &log_len);
            const buffer: []u8 = alloc.alloc(u8, @intCast(log_len)) catch {
                @panic("out of memory while getting program link log");
            };
            var actual_len: c.GLint = undefined;
            c.__glewGetProgramInfoLog.?(program, log_len, &actual_len, buffer.ptr);
            std.debug.assert(log_len == actual_len + 1);
            std.log.err("{s}", .{buffer});
            @panic("program no link");
        }

        const attributes = attributes: {
            var attribute_count: c.GLint = undefined;
            c.__glewGetProgramiv.?(program, c.GL_ACTIVE_ATTRIBUTES, &attribute_count);
            std.log.debug("attribute count = {d}", .{attribute_count});

            const attributes = std.StringHashMap(Attribute).init(alloc);

            var max_attribute_name_len: c.GLint = undefined;
            c.__glewGetProgramiv.?(program, c.GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, &max_attribute_name_len);

            var buffer: []u8 = alloc.alloc(u8, @intCast(max_attribute_name_len)) catch {
                @panic("oom");
            };
            for (0..@intCast(attribute_count)) |attribute| {
                var len: c.GLsizei = undefined;
                var size: c.GLint = undefined;
                var @"type": c.GLenum = undefined;
                c.__glewGetActiveAttrib.?(program, @intCast(attribute), @intCast(buffer.len), &len, &size, &@"type", buffer.ptr);
                const name = buffer[0..@intCast(len)];
                std.log.debug("attibute {s}", .{name});
            }
            break :attributes attributes;
        };

        const uniforms = uniforms: {
            var uniform_count: c.GLint = undefined;
            c.__glewGetProgramiv.?(program, c.GL_ACTIVE_UNIFORMS, &uniform_count);
            std.log.debug("uniform count = {d}", .{uniform_count});

            const uniforms = std.StringHashMap(Uniform).init(alloc);

            var max_uniform_name_len: c.GLint = undefined;
            c.__glewGetProgramiv.?(program, c.GL_ACTIVE_UNIFORM_MAX_LENGTH, &max_uniform_name_len);

            var buffer: []u8 = alloc.alloc(u8, @intCast(max_uniform_name_len)) catch {
                @panic("oom");
            };
            for (0..@intCast(uniform_count)) |uniform| {
                var len: c.GLsizei = undefined;
                var size: c.GLint = undefined;
                var @"type": c.GLenum = undefined;
                c.__glewGetActiveUniform.?(program, @intCast(uniform), @intCast(buffer.len), &len, &size, &@"type", buffer.ptr);
                const name = buffer[0..@intCast(len)];
                std.log.debug("uniform {s}", .{name});
            }
            break :uniforms uniforms;
        };

        return .{
            .program = program,
            .attributes = attributes,
            .uniforms = uniforms,
        };
    }

    fn use(self: Self) void {
        c.__glewUseProgram.?(self.program);
    }

    fn deinit(self: Self) void {
        c.__glewDeleteProgram.?(self.program);
    }
};

fn VertexBuffer(comptime vertex: type) type {
    return struct {
        const Self = @This();

        buffer: c.GLuint,

        fn init(data: []const vertex) Self {
            var buffer: c.GLuint = undefined;
            c.__glewCreateBuffers.?(1, &buffer);
            if (buffer == 0) {
                @panic("no buffer");
            }
            c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, buffer);
            c.__glewBufferData.?(c.GL_ARRAY_BUFFER, @intCast(data.len * @sizeOf(vertex)), data.ptr, c.GL_STATIC_DRAW);
            return .{
                .buffer = buffer,
            };
        }

        fn deinit(self: Self) void {
            c.__glewDeleteBuffers.?(1, &self.buffer);
        }
    };
}

fn check_gl_error() void {
    const err = c.glGetError();
    if (err != c.GL_NO_ERROR) {
        @panic("gl error");
    }
}

const VAO = struct {
    const Self = @This();
    object: c.GLuint,
    fn init() Self {
        var object: c.GLuint = undefined;
        c.__glewGenVertexArrays.?(1, &object);
        return .{ .object = object };
    }
    fn bind(self: Self) void {
        c.__glewBindVertexArray.?(self.object);
    }
    fn deinit(self: Self) void {
        c.__glewDeleteVertexArrays.?(1, &self.object);
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    std.log.debug("Initializing GLFW", .{});
    if (c.glfwInit() != c.GLFW_TRUE) {
        @panic("oh no");
    }
    defer c.glfwTerminate();
    std.log.debug("GLFW initialized", .{});
    const prev_error = c.glfwSetErrorCallback(error_callback);
    if (prev_error != null) {
        @panic("ho no");
    }

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    const window: *c.GLFWwindow = c.glfwCreateWindow(640, 480, "My Title", null, null) orelse {
        @panic("no window");
    };
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);
    const glew_error = c.glewInit();
    if (glew_error != c.GLEW_OK) {
        const error_string = c.glewGetErrorString(glew_error);
        std.log.err("{s}", .{error_string});
        // TODO wtf glew not ok but actually ok @panic("glew not ok");
    }

    const program = program: {
        // align does nothing
        const vertex_source align(4) = @embedFile("vertex.glsl").*;
        const vertex = Shader.init(c.GL_VERTEX_SHADER, &vertex_source, alloc);
        defer vertex.deinit();
        const fragment_source align(4) = @embedFile("fragment.glsl").*;
        const fragment = Shader.init(c.GL_FRAGMENT_SHADER, &fragment_source, alloc);
        defer fragment.deinit();
        break :program Program.init(&.{fragment}, alloc);
    };
    defer program.deinit();

    program.use();

    const Vertex = [2]f32;

    const buffer = VertexBuffer(Vertex).init(&.{ .{ 0.0, 1.0 }, .{ -1.0, -1.0 }, .{ 1.0, -1.0 } });
    defer buffer.deinit();

    const vao = VAO.init();
    defer vao.deinit();

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        var width: c_int = undefined;
        var height: c_int = undefined;
        c.glfwGetFramebufferSize(window, &width, &height);
        c.glViewport(0, 0, width, height);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        vao.bind();
        c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, buffer.buffer);
        c.__glewEnableVertexAttribArray.?(0);
        c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
        check_gl_error();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
