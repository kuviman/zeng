extern fn zeng_init() void;

extern fn gl_clear(r: f32, g: f32, b: f32, a: f32) void;

pub const State = struct {
    const Self = @This();
    pub fn init() Self {
        zeng_init();
        return .{};
    }
    pub fn clear(_: Self, r: f32, g: f32, b: f32, a: f32) void {
        gl_clear(r, g, b, a);
    }
    pub fn deinit(_: Self) void {}
};
