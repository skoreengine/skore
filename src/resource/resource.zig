const std = @import("std");
const repo = @import("repository.zig");

pub const RIDIndex = extern struct {
    offset: u32,
    page: u32,
};

pub const RID = extern union {
    index: RIDIndex,
    id: u64,
};

pub fn Field(comptime T: type) type {
    return struct {
        const This = @This();

        pub fn get(_: *This) ?T {
            return null;
        }

        pub fn set(_: *This, _: T) void {}
    };
}

pub const SubobjectList = struct {

    pub fn append(_: *SubobjectList, _: RID) void {

    }
};

test {
    _ = repo;
}
