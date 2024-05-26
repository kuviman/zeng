const zeng = @import("zeng");

pub fn main() void {
    const engine = zeng.Zeng.init();
    defer engine.deinit();
}
