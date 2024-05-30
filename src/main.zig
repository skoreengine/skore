const std = @import("std");

pub const platform = @import("core/platform.zig");
pub const math = @import("core/math.zig");
pub const graphics = @import("graphics/main.zig");
pub const registry = @import("core/registry.zig");
pub const ecs = @import("ecs/world.zig");


//TODO temporary.

const TestComp = struct {
    x : i32
};

pub fn main() !void {

    std.debug.print("Hello, skore\n", .{});

    var reg = registry.Registry.init(std.heap.page_allocator);
    defer reg.deinit();

    try platform.init();
    defer platform.deinit();

    var world  = ecs.World.init(std.heap.page_allocator);
    defer world.deinit();

    _ = try world.spawn(.{TestComp});

    var window = try platform.createWindow(800, 600, "Skore Engine");
    defer window.deinit();

    while (!window.shouldClose()) {

        platform.pollEvents();

        graphics.clearBuffer(math.CORNFLOWER_BLUE);

        window.swapBuffers();
    }
}


test {
    _ = ecs;
}
