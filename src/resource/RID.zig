const std = @import("std");

const RID = @This();

pub const page_size = 4096;

offset: u32,
page: u32,

pub fn valid(rid: RID) bool {
    return rid.offset > 0 or rid.offset > 0;
}

pub fn eql(l: RID, r: RID) bool {
    return l.offset == r.offset and l.page == r.page;
}

pub inline fn page(index: usize) u32 {
    return @intCast(index / page_size);
}

pub inline fn offset(index: usize) u32 {
    return @intCast(index & (page_size - 1));
}

test "rid basics" {
    const p = page(5000);
    try std.testing.expectEqual(1, p);

    const o = offset(5000);
    try std.testing.expectEqual(904, o);

}
