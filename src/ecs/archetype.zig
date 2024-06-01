const std = @import("std");
const skore = @import("../skore.zig");


pub fn makeArchetypeHash(ids : []const skore.TypeId) u128 {
    var hash: u128 = 0;
    for(ids) |id| {
        hash = @addWithOverflow(hash, id)[0];
    }
    return hash;
}

pub const Archetype = struct {
    id: u32,
    hash : u128
};

pub const ArchetypeHashMap = std.AutoHashMap(u128,  std.ArrayList(*Archetype));