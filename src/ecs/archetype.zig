const std = @import("std");
const skore = @import("../skore.zig");

pub const ComponentState = struct {
    last_change: u64 = 0,
    last_check: u64 = 0,
};

pub const ArchetypeType = struct {
    type_id: skore.TypeId,
    type_handler: *skore.TypeHandler,
    type_size: usize = 0,
    data_offset: usize = 0,
    state_offset: usize = 0,
};

pub const ArchetypeChunk = [*]u8;

pub const Archetype = struct {
    id: u32,
    hash: u128,
    max_entity_chunk_count: usize = 0,
    chunk_total_alloc_size: usize = 0,
    chunk_data_size: usize = 0,
    entity_array_offset: usize = 0,
    entity_count_offset: usize = 0,
    chunk_state_offset: usize = 0,
    types: std.ArrayList(ArchetypeType) = undefined,
    typeIndex  : std.AutoHashMap(u128, usize) = undefined,
    chunks: std.ArrayList(ArchetypeChunk) = undefined,

    pub inline fn getEntityCount(archetype: *Archetype, chunk :ArchetypeChunk) *usize {
        return @alignCast(@ptrCast(&chunk[archetype.entity_count_offset]));
    }

    pub inline fn getChunkEntity(archetype: *Archetype, chunk :ArchetypeChunk, index: usize) *skore.ecs.Entity {
        return @alignCast(@ptrCast(&chunk[archetype.entity_array_offset + (index * @sizeOf(skore.ecs.Entity))]));
    }

    pub inline fn addEntityChunk(archetype: *Archetype, chunk :ArchetypeChunk, entity : skore.ecs.Entity) usize {
        const entity_count = getEntityCount(archetype, chunk);
        const new_index = entity_count.*;
        entity_count.* += 1;
        archetype.getChunkEntity(chunk, new_index).* = entity;
        return new_index;
    }

    pub inline fn getChunkComponentData(archetype_type: ArchetypeType, chunk :ArchetypeChunk, index: usize) []u8 {
        const index_data = archetype_type.data_offset + (index * archetype_type.type_size);
        return chunk[index_data..archetype_type.type_size + index_data];
    }
};

pub const ArchetypeHashMap = std.AutoHashMap(u128, std.ArrayList(*Archetype));
