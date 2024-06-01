const std = @import("std");
const skore = @import("../skore.zig");


pub fn makeArchetypeHash(ids : [*]const skore.TypeId, size: u32) u128 {
    var hash: u128 = 0;
    for (0..size) |i| {
        hash = @addWithOverflow(hash, ids[i])[0];
    }
    return hash;
}

pub const Archetype = struct {
    id: u32,
    hash : u128,
    ids : std.ArrayList(skore.TypeId)
};

pub const ArchetypeHashMap = std.AutoHashMap(u128,  std.ArrayList(*Archetype));