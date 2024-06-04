pub const Entity = u64;

pub const archetype = @import("archetype.zig");
pub const world = @import("world.zig");
pub const query = @import("query.zig");
const skore = @import("../skore.zig");

pub const World = world.World;
pub const Archetype = archetype.Archetype;
pub const ArchetypeType = archetype.ArchetypeType;
pub const ArchetypeChunk = archetype.ArchetypeChunk;
pub const ArchetypeHashMap = archetype.ArchetypeHashMap;
pub const ComponentState = archetype.ComponentState;

pub const Query = query.Query;
pub const QueryIter = query.QueryIter;
pub const QueryData = query.QueryData;

pub const archetype_max_components: u8 = 32;
pub const chunk_component_size: u16 = 16 * 1024;

pub fn makeHash(ids: [*]const skore.TypeId, size: u32) u128 {
    var hash: u128 = 0;
    for (0..size) |i| {
        hash = @addWithOverflow(hash, ids[i])[0];
    }
    return hash;
}

pub fn getIds(types: anytype, ids: []skore.TypeId) void {
    const struct_type = @typeInfo(@TypeOf(types));
    const fields_info = struct_type.Struct.fields;
    inline for (fields_info, 0..) |field, i| {
        const field_type = @typeInfo(field.type);
        if (field_type == .Type) {
            if (field.default_value) |default_value| {
                const typ: *type = @ptrCast(@constCast(default_value));
                ids[i] = skore.registry.getTypeId(typ.*);
            }
        } else if (field_type == .Struct) {
            ids[i] = skore.registry.getTypeId(field.type);
        }
    }
}

test {
    _ = world;
    _ = archetype;
    _ = query;
}