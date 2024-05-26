const std = @import("std");

extern fn wasm_log([*c]const u8, usize) void;

fn log(s: []const u8) void {
    wasm_log(s.ptr, s.len);
}

// getting ziggy with it
pub fn main() void {
    // std.debug.print("hello", .{});
    // std.log.warn("hello", .{});
    log("Hello, world");
}
