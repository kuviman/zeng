const std = @import("std");
const zeng = @import("../root.zig");

const js = struct {
    extern fn zeng_init() void;
    extern fn gl_clear(r: f32, g: f32, b: f32, a: f32) void;
    extern fn zeng_run(ptr: *anyopaque, draw: *const fn (ptr: *anyopaque) callconv(.C) void) void;
    extern fn zeng_time() f32;
    extern fn zeng_log(str_ptr: [*c]const u8, str_len: usize) void;
    extern fn zeng_init_shader(@"type": u32, source_ptr: [*c]const u8, source_len: usize) i32;
    extern fn zeng_deinit_shader(js_handle: i32) void;
    extern fn zeng_init_program(shader1: i32, shader2: i32) i32;
    extern fn zeng_use_program(js_handle: i32) void;
    extern fn zeng_deinit_program(js_handle: i32) void;
    extern fn zeng_init_vertex_buffer(data_ptr: [*c]const u8, data_len: usize) i32;
    extern fn zeng_bind_vertex_buffer(handle: i32) void;
    extern fn zeng_deinit_vertex_buffer(handle: i32) void;
    extern fn zeng_vertex_attrib_pointer(
        program_handle: i32,
        name_ptr: [*c]const u8,
        name_len: usize,
        size: usize,
        gl_type: GlType,
        normalized: bool,
        stride: usize,
        offset: usize,
    ) void;
    extern fn zeng_draw_arrays(mode: zeng.DrawMode, first: usize, count: usize) void;
};

export fn call_ptr(f: *const fn (ptr: *anyopaque) callconv(.C) void, ptr: *anyopaque) void {
    f(ptr);
}

pub fn log(text: []const u8) void {
    js.zeng_log(text.ptr, text.len);
}

pub const Shader = struct {
    const Self = @This();
    js_handle: i32,
    pub fn init(engine: zeng.Zeng, @"type": zeng.ShaderType, source: []const u8) Self {
        _ = engine;
        return .{
            .js_handle = js.zeng_init_shader(@intFromEnum(@"type"), source.ptr, source.len),
        };
    }
    pub fn deinit(self: Self) void {
        js.zeng_deinit_shader(self.js_handle);
    }
};

pub const Program = struct {
    const Self = @This();
    js_handle: i32,
    pub fn init(engine: zeng.Zeng, shaders: []const Shader) Self {
        if (shaders.len != 2) {
            @panic("Expected 2 shaders");
        }
        _ = engine;
        return .{
            .js_handle = js.zeng_init_program(shaders[0].js_handle, shaders[1].js_handle),
        };
    }
    pub fn use(self: Self) void {
        js.zeng_use_program(self.js_handle);
    }
    pub fn deinit(self: Self) void {
        js.zeng_deinit_program(self.js_handle);
    }
};

pub const VertexBuffer = struct {
    const Self = @This();

    js_handle: i32,

    pub fn init(data: []const u8) Self {
        return .{
            .js_handle = js.zeng_init_vertex_buffer(data.ptr, data.len),
        };
    }

    pub fn bind(self: Self) void {
        js.zeng_bind_vertex_buffer(self.js_handle);
    }

    pub fn deinit(self: Self) void {
        js.zeng_deinit_vertex_buffer(self.js_handle);
    }
};

pub const VAO = struct {
    const Self = @This();
    pub fn init() Self {
        return .{};
    }
    pub fn bind(_: Self) void {}
    pub fn deinit(_: *Self) void {}
};

const GlType = enum(u32) {
    Float = 0,
};

fn gl_type_for(comptime t: type) GlType {
    if (t == f32) {
        return .Float;
    }
    @compileError("Unknown type for OpenGL");
}

pub const State = struct {
    const Self = @This();
    pub fn init() Self {
        js.zeng_init();
        return .{};
    }
    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        js.gl_clear(r, g, b, a);
    }
    pub fn deinit(_: Self) void {}
    pub fn current_time(_: Self) f32 {
        return js.zeng_time();
    }
    pub fn run(_: Self, state: zeng.State) void {
        js.zeng_run(state.ptr, state.drawFn);
    }

    pub fn vertex_attrib_pointer(
        _: Self,
        program: Program,
        comptime vertex: type,
        comptime field: std.builtin.Type.StructField,
        normalized: bool,
    ) void {
        const size, const gl_type = switch (@typeInfo(field.type)) {
            .Array => |array| .{ array.len, gl_type_for(array.child) },
            else => @compileError("field type must be array"),
        };
        js.zeng_vertex_attrib_pointer(
            program.js_handle,
            field.name.ptr,
            field.name.len,
            size,
            gl_type,
            normalized,
            @sizeOf(vertex),
            @offsetOf(vertex, field.name),
        );
    }

    pub fn draw_arrays(_: Self, mode: zeng.DrawMode, first: usize, count: usize) void {
        js.zeng_draw_arrays(mode, first, count);
    }
};
