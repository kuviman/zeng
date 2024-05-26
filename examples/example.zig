const std = @import("std");
const zeng = @import("zeng");

pub const std_options = .{
    // Set the log level to info
    .log_level = .debug,

    // Define logFn to override the std implementation
    .logFn = zeng.logFn,
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    return zeng.panic(msg, error_return_trace, ret_addr);
}

const Vertex = struct {
    a_pos: [2]f32,
    a_offset: [2]f32,
};

const State = struct {
    const Self = @This();

    vertex_buffer: zeng.VertexBuffer(Vertex),
    program: zeng.Program,
    engine: zeng.Zeng,

    fn init(engine: zeng.Zeng) Self {
        const vertex_shader = zeng.Shader.init(engine, zeng.ShaderType.Vertex, @embedFile("vertex.glsl"));
        defer vertex_shader.deinit();
        const fragment_shader = zeng.Shader.init(engine, zeng.ShaderType.Fragment, @embedFile("fragment.glsl"));
        defer fragment_shader.deinit();
        const program = zeng.Program.init(engine, &.{ vertex_shader, fragment_shader });
        const vertex_buffer = zeng.VertexBuffer(Vertex).init(&.{
            Vertex{
                .a_pos = [2]f32{ -1.0, -1.0 },
                .a_offset = [2]f32{ 1.23, 2.34 },
            },
            Vertex{
                .a_pos = [2]f32{ 1.0, -1.0 },
                .a_offset = [2]f32{ -1.23, 2.34 },
            },
            Vertex{
                .a_pos = [2]f32{ 0.0, 1.0 },
                .a_offset = [2]f32{ 1.23, -2.34 },
            },
        });
        return .{
            .program = program,
            .engine = engine,
            .vertex_buffer = vertex_buffer,
        };
    }

    fn deinit(self: *Self) void {
        self.program.deinit();
        self.vertex_buffer.deinit();
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
        self.engine.draw(Vertex, self.program, self.vertex_buffer);
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
    defer state.deinit();
    engine.run(state.zeng_state());
}
