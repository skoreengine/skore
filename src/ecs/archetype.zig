const std = @import("std");
const skore = @import("../skore.zig");

pub fn makeArchetypeHash(ids: [*]const skore.TypeId, size: u32) u128 {
    var hash: u128 = 0;
    for (0..size) |i| {
        hash = @addWithOverflow(hash, ids[i])[0];
    }
    return hash;
}

pub const ComponentState = struct {
    last_change: u64 = 0,
    last_check: u64 = 0,
};

pub const ArchetypeType = struct {
    id: skore.TypeId,
    type_handler: *skore.TypeHandler,
    type_size: usize = 0,
    data_offset: usize = 0,
    state_offset: usize = 0,
};

pub const ArchetypeChunk = struct {
    data: [:0]const u8,
};

pub const Archetype = struct {
    id: u32,
    hash: u128,
    max_entity_chunk_count: usize = 0,
    chunk_alloc_size: usize = 0,
    chunk_data_size: usize = 0,
    entity_array_offset: usize = 0,
    entity_count_offset: usize = 0,
    chunk_state_offset: usize = 0,
    types: std.ArrayList(ArchetypeType) = undefined,
    chunks: std.ArrayList(ArchetypeChunk) = undefined,
};

pub const ArchetypeHashMap = std.AutoHashMap(u128, std.ArrayList(*Archetype));
