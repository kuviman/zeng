const std = @import("std");
const zeng = @import("zeng");

pub const std_options = .{
    // Set the log level to info
    .log_level = .info,

    // Define logFn to override the std implementation
    .logFn = zeng.logFn,
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    return zeng.panic(msg, error_return_trace, ret_addr);
}

const State = struct {
    const Self = @This();

    program: zeng.Program,
    engine: zeng.Zeng,

    fn init(engine: zeng.Zeng) Self {
        const vertex_shader = zeng.Shader.init(engine, zeng.ShaderType.Vertex, @embedFile("vertex.glsl"));
        const fragment_shader = zeng.Shader.init(engine, zeng.ShaderType.Fragment, @embedFile("fragment.glsl"));
        const program = zeng.Program.init(engine, &.{ vertex_shader, fragment_shader });
        return .{ .program = program, .engine = engine };
    }

    fn drawFn(ptr: *anyopaque) callconv(.C) void {
        const state: *Self = @ptrCast(@alignCast(ptr));
        state.draw();
    }
    fn draw(self: Self) void {
        var t = self.engine.current_time();
        t *= 1.0;
        t = t - std.math.floor(t);
        t = t * 0.3;
        self.engine.clear(t, t, t, 1.0);
    }

    fn zeng_state(self: *Self) zeng.State {
        return .{
            .ptr = self,
            .drawFn = drawFn,
        };
    }
};

pub fn main() void {
    const engine = zeng.Zeng.init();
    defer engine.deinit();

    var state = State.init(engine);
    engine.run(state.zeng_state());
}
