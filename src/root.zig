const builtin = @import("builtin");
const platform = switch (builtin.target.isWasm()) {
    true => @import("platform/web.zig"),
    false => @import("platform/native.zig"),
};

pub const Zeng = struct {
    const Self = @This();

    platform: platform.State,

    pub fn init() Self {
        return .{
            .platform = platform.State.init(),
        };
    }
    pub fn deinit(self: Self) void {
        self.platform.deinit();
    }
};
