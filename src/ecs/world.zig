const std = @import("std");
const ecs = @import("main.zig");

pub const WorldData = opaque {};

pub const WorldApi = struct {
    spawn: *const fn (data: *WorldData, components: [*]const u8) ecs.Entity,
};

pub const World = struct {
    data: *WorldData,
    api: WorldApi,

    pub fn init(_: *World, _: *std.mem.Allocator) void {}

    pub fn deinit(_: *World) void {}

    pub fn spawn(self: *World, _: anytype) ecs.Entity {
        return self.api.spawn(self.data, &[_]u8{});
    }
};

test "test outside" {
    const TestStruct = struct {};

    const api = WorldApi{ .spawn = undefined };

    var world = ecs.World{ .data = undefined, .api = api };

    try std.testing.expectEqual(world.spawn(.{TestStruct}), 0);
}
