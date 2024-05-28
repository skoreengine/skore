const std = @import("std");

const platform = @import("core/platform.zig");
const math = @import("core/math.zig");
const graphics = @import("graphics/main.zig");

pub fn main() !void {
    std.debug.print("Hello, skore", .{});

    try platform.init();

    var window = try platform.createWindow(800, 600, "Skore Engine");
    defer window.deinit();

    while (!window.shouldClose()) {
        platform.pollEvents();

        graphics.clearBuffer(math.CORNFLOWER_BLUE);

        window.swapBuffers();
    }

    defer platform.deinit();
}
