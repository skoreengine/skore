const std = @import("std");
const Repository = @import("Repository.zig");
const RID = @import("RID.zig");

pub fn Field(comptime T: type) type {
    return struct {
        const This = @This();

        pub fn get(_: *This) ?*const T {
            return null;
        }

        pub fn set(_: *This, _: T) void {}
    };
}

pub const SubobjectList = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SubobjectList {
        return .{
            .allocator = allocator,
        };
    }

    pub fn append(_: *SubobjectList, _: RID) void {}
};

test {
    _ = Repository;
    _ = RID;
}
