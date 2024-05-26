const zeng = @import("../root.zig");

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

pub const Shader = struct {
    const Self = @This();

    shader: c.GLuint,

    pub fn init(engine: zeng.Zeng, @"type": zeng.ShaderType, source: []const u8) Self {
        const gl_type: c.GLuint = switch (@"type") {
            .Vertex => c.GL_VERTEX_SHADER,
            .Fragment => c.GL_FRAGMENT_SHADER,
        };

        // https://github.com/ziglang/zig/issues/8898
        const shader = c.__glewCreateShader.?(gl_type);
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
            const buffer: []u8 = engine.allocator.alloc(u8, @intCast(log_len)) catch {
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

    pub fn deinit(self: Self) void {
        c.__glewDeleteShader.?(self.shader);
    }
};

const Attribute = struct {
    index: usize,
};
const Uniform = struct {};

pub const Program = struct {
    const Self = @This();
    program: c.GLuint,
    attributes: std.StringHashMap(Attribute),
    uniforms: std.StringHashMap(Uniform),

    pub fn init(engine: zeng.Zeng, shaders: []const Shader) Self {
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
            const buffer: []u8 = engine.allocator.alloc(u8, @intCast(log_len)) catch {
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

            var attributes = std.StringHashMap(Attribute).init(engine.allocator);

            var max_attribute_name_len: c.GLint = undefined;
            c.__glewGetProgramiv.?(program, c.GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, &max_attribute_name_len);

            var buffer: []u8 = engine.allocator.alloc(u8, @intCast(max_attribute_name_len)) catch {
                @panic("oom");
            };
            for (0..@intCast(attribute_count)) |index| {
                var len: c.GLsizei = undefined;
                var size: c.GLint = undefined;
                var @"type": c.GLenum = undefined;
                c.__glewGetActiveAttrib.?(program, @intCast(index), @intCast(buffer.len), &len, &size, &@"type", buffer.ptr);
                const name = buffer[0..@intCast(len)];
                std.log.debug("attibute {s}", .{name});
                const name_copy = engine.allocator.dupe(u8, name) catch @panic("oom");
                attributes.put(name_copy, .{
                    .index = index,
                }) catch @panic("oom");
            }
            break :attributes attributes;
        };

        const uniforms = uniforms: {
            var uniform_count: c.GLint = undefined;
            c.__glewGetProgramiv.?(program, c.GL_ACTIVE_UNIFORMS, &uniform_count);
            std.log.debug("uniform count = {d}", .{uniform_count});

            const uniforms = std.StringHashMap(Uniform).init(engine.allocator);

            var max_uniform_name_len: c.GLint = undefined;
            c.__glewGetProgramiv.?(program, c.GL_ACTIVE_UNIFORM_MAX_LENGTH, &max_uniform_name_len);

            var buffer: []u8 = engine.allocator.alloc(u8, @intCast(max_uniform_name_len)) catch {
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

    pub fn use(self: Self) void {
        c.__glewUseProgram.?(self.program);
    }

    pub fn deinit(self: *Self) void {
        c.__glewDeleteProgram.?(self.program);
        self.attributes.deinit();
    }
};

pub const VertexBuffer = struct {
    const Self = @This();

    buffer: c.GLuint,

    pub fn init(data: []const u8) Self {
        var buffer: c.GLuint = undefined;
        c.__glewCreateBuffers.?(1, &buffer);
        if (buffer == 0) {
            @panic("no buffer");
        }
        c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, buffer);
        c.__glewBufferData.?(c.GL_ARRAY_BUFFER, @intCast(data.len), data.ptr, c.GL_STATIC_DRAW);
        return .{
            .buffer = buffer,
        };
    }

    pub fn bind(self: Self) void {
        c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, self.buffer);
    }

    pub fn deinit(self: Self) void {
        c.__glewDeleteBuffers.?(1, &self.buffer);
    }
};

pub const VAO = struct {
    const Self = @This();
    object: c.GLuint,
    pub fn init() Self {
        var object: c.GLuint = undefined;
        c.__glewGenVertexArrays.?(1, &object);
        return .{ .object = object };
    }
    pub fn bind(self: Self) void {
        c.__glewBindVertexArray.?(self.object);
    }
    pub fn deinit(self: Self) void {
        c.__glewDeleteVertexArrays.?(1, &self.object);
    }
};

pub const State = struct {
    const Self = @This();
    window: *c.GLFWwindow,
    pub fn init() Self {
        const prev_error = c.glfwSetErrorCallback(glfw_error_callback);
        if (prev_error != null) {
            @panic("ho no");
        }

        std.log.debug("Initializing GLFW", .{});
        if (c.glfwInit() != c.GLFW_TRUE) {
            @panic("oh no");
        }
        std.log.debug("GLFW initialized", .{});

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
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();
    }
    fn check_gl_error(_: Self) void {
        const err = c.glGetError();
        if (err != c.GL_NO_ERROR) {
            @panic("gl error");
        }
    }
    pub fn current_time(_: Self) f32 {
        return @floatCast(c.glfwGetTime());
    }
    pub fn run(self: Self, state: zeng.State) void {
        while (c.glfwWindowShouldClose(self.window) == c.GLFW_FALSE) {
            state.draw();

            self.check_gl_error();

            c.glfwSwapBuffers(self.window);
            c.glfwPollEvents();
        }
    }

    pub fn vertex_attrib_pointer(
        _: Self,
        program: Program,
        comptime vertex: type,
        comptime field: std.builtin.Type.StructField,
        normalized: bool,
    ) void {
        const attribute_info = program.attributes.get(field.name) orelse return;
        c.__glewEnableVertexAttribArray.?(@intCast(attribute_info.index));
        const size, const gl_type = switch (@typeInfo(field.type)) {
            .Array => |array| .{ array.len, gl_type_for(array.child) },
            else => @compileError("field type must be array"),
        };
        // std.log.debug("{s} = {d}", .{ field.name, attribute_info.index });
        c.__glewVertexAttribPointer.?(
            @intCast(attribute_info.index),
            size,
            gl_type,
            if (normalized) c.GL_TRUE else c.GL_FALSE,
            @sizeOf(vertex),
            @ptrFromInt(@offsetOf(vertex, field.name)),
        );
    }

    pub fn draw_arrays(_: Self, mode: zeng.DrawMode, first: usize, count: usize) void {
        const gl_mode = switch (mode) {
            .Triangles => c.GL_TRIANGLES,
        };
        c.glDrawArrays(gl_mode, @intCast(first), @intCast(count));
    }
};

fn gl_type_for(comptime t: type) c.GLenum {
    if (t == f32) {
        return c.GL_FLOAT;
    }
    @compileError("Unknown type for OpenGL");
}
