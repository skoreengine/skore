const std = @import("std");

pub const Float = f32;

pub const Vec2 = struct {
    x: Float,
    y: Float,
};

pub const Vec3 = struct {
    x: Float,
    y: Float,
    z: Float,
};

pub const Vec4 = struct {
    x: Float,
    y: Float,
    z: Float,
    w: Float,
};

pub const CORNFLOWER_BLUE = Vec4{
    .x = 0.392,
    .y = 0.584,
    .z = 0.929,
    .w = 1.0
};

test "vec4 basics" {
    const vec2 = Vec2{
        .x = 10,
        .y = 20,
    };
    try std.testing.expectEqual(vec2.x, 10);
    try std.testing.expectEqual(vec2.y, 20);
}
