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
    extern fn zeng_deinit_program(js_handle: i32) void;
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
    pub fn deinit(self: Self) void {
        js.zeng_deinit_program(self.js_handle);
    }
};

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
};
