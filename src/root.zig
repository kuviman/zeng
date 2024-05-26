const std = @import("std");
const builtin = @import("builtin");
const platform = switch (builtin.target.isWasm()) {
    true => @import("platform/web.zig"),
    false => @import("platform/native.zig"),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("{s}", .{msg});
    if (error_return_trace) |trace| {
        _ = trace;
        // TODO maybe later?
    }
    return std.builtin.default_panic(msg, error_return_trace, ret_addr);
}

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Ignore all non-error logging from sources other than
    // .my_project, .nice_library and the default
    const scope_prefix = "(" ++ switch (scope) {
        .my_project, .nice_library, std.log.default_log_scope => @tagName(scope),
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err))
            @tagName(scope)
        else
            return,
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    // Print the message to stderr, silently ignoring any errors
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    const formatStr = prefix ++ format ++ "\n";
    if (builtin.target.isWasm()) {
        var alloc = gpa.allocator();
        const text = std.fmt.allocPrint(alloc, formatStr, args) catch return;
        defer alloc.free(text);
        platform.log(text);
    } else {
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(formatStr, args) catch return;
    }
}

pub const ShaderType = enum(u32) {
    Vertex = 0,
    Fragment = 1,
};

pub const Shader = struct {
    const Self = @This();

    platform: platform.Shader,

    pub fn init(engine: Zeng, @"type": ShaderType, source: []const u8) Self {
        return .{
            .platform = platform.Shader.init(engine, @"type", source),
        };
    }

    pub fn deinit(self: Self) void {
        self.platform.deinit();
    }
};

pub const Program = struct {
    const Self = @This();

    platform: platform.Program,

    pub fn init(engine: Zeng, shaders: []const Shader) Self {
        const platform_shaders = engine.allocator.alloc(platform.Shader, shaders.len) catch @panic("oom");
        for (0..shaders.len) |i| {
            platform_shaders[i] = shaders[i].platform;
        }
        return .{
            .platform = platform.Program.init(engine, platform_shaders),
        };
    }

    pub fn deinit(self: Self) void {
        self.platform.deinit();
    }
};

pub const State = struct {
    const Self = @This();

    ptr: *anyopaque,
    drawFn: *const fn (ptr: *anyopaque) callconv(.C) void,

    pub fn draw(self: Self) void {
        self.drawFn(self.ptr);
    }
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const Zeng = struct {
    const Self = @This();

    platform: platform.State,
    allocator: std.mem.Allocator,

    pub fn init() Self {
        return .{
            .allocator = gpa.allocator(),
            .platform = platform.State.init(),
        };
    }
    pub fn deinit(self: Self) void {
        self.platform.deinit();
    }

    pub fn clear(self: Self, r: f32, g: f32, b: f32, a: f32) void {
        self.platform.clear(r, g, b, a);
    }

    pub fn current_time(self: Self) f32 {
        return self.platform.current_time();
    }

    pub fn run(self: Self, state: State) void {
        self.platform.run(state);
    }
};
