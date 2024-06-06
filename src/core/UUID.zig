const std = @import("std");

const UUID = @This();

first_value: u64 = 0,
second_value: u64 = 0,

pub fn randomUUID() @This() {
    var rand_impl = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    return .{
        .first_value = rand_impl.random().int(u64),
        .second_value = rand_impl.random().int(u64),
    };
}

test "test uuid" {
    const random = UUID.randomUUID();
    try std.testing.expect(0 != random.first_value);
    try std.testing.expect(0 != random.second_value);
}
