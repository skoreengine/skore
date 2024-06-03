const std = @import("std");

const skore = @import("../skore.zig");
const ecs = skore.ecs;

pub const QueryArchetype = struct { archetype: *const ecs.Archetype, indices: std.ArrayList(usize) };

pub const QueryData = struct {
    types: std.ArrayList(skore.TypeId),
    archetypes: std.ArrayList(QueryArchetype),

    pub fn checkArchetypes(query_data: *QueryData, world: *ecs.World, archetype: *ecs.Archetype) !void {
        for (query_data.types.items) |type_id| {
            const opt = archetype.typeIndex.get(type_id);
            if (opt == null) {
                return;
            }
        }

        var query_archetype = QueryArchetype{
            .archetype = archetype,
            .indices = try std.ArrayList(usize).initCapacity(world.allocator, query_data.types.items.len),
        };

        for (query_data.types.items) |type_id| {
            if (archetype.typeIndex.get(type_id)) |index| {
                try query_archetype.indices.append(index);
            }
        }

        try query_data.archetypes.append(query_archetype);
    }
};

pub const QueryHashMap = std.AutoHashMap(skore.TypeId, std.ArrayList(*QueryData));

pub fn QueryIter(comptime _: anytype) type {
    return struct {
        const This = @This();

        query_data: *QueryData,
        current_archetype_index: usize,
        current_chunk_index: usize,
        current_entity_index: usize,

        pub fn next(iter: *This) ?*This {
            while (true) {

                if (iter.query_data.archetypes.items.len <= iter.current_archetype_index) {
                    return null;
                }

                const current_archetype = &iter.query_data.archetypes.items[iter.current_archetype_index];
                const chunks = &current_archetype.archetype.chunks;

                if (chunks.items.len > iter.current_chunk_index) {
                    const current_chunk = chunks.items[iter.current_chunk_index];
                    if (current_archetype.archetype.getEntityCount(current_chunk).* > iter.current_entity_index) {
                        iter.current_entity_index +=1;
                        return iter;
                    } else {
                        iter.current_chunk_index += 1;
                        iter.current_entity_index = 0;
                    }
                } else {
                    iter.current_archetype_index += 1;
                    iter.current_entity_index = 0;
                    iter.current_chunk_index = 0;
                }
            }
        }

        pub fn getEntity(iter: This) ecs.Entity {
            const current_archetype = iter.query_data.archetypes.items[iter.current_archetype_index].archetype;
            const current_chunk = current_archetype.chunks.items[iter.current_chunk_index];
            return current_archetype.getChunkEntity(current_chunk, iter.current_entity_index - 1).*;
        }

        pub fn get(_: This, comptime T: type) *const T {}

        pub fn getMut(_: This, comptime T: type) *T {}
    };
}

pub fn Query(comptime T: anytype) type {
    const len: u32 = @typeInfo(@TypeOf(T)).Struct.fields.len;
    comptime var _ids: [len]skore.TypeId = undefined;
    comptime ecs.getIds(T, &_ids);
    const _hash = ecs.makeHash(&_ids, len);

    return struct {
        const This = @This();
        pub const hash = _hash;
        pub const ids = _ids;

        query_data: *QueryData,

        pub fn iter(self: *This) QueryIter(T) {
            return QueryIter(T){
                .query_data = self.query_data,
                .current_archetype_index = 0,
                .current_chunk_index = 0,
                .current_entity_index = 0,
            };
        }
    };
}

const Comp1 = struct {};
const Comp2 = struct {};

test "query basics" {
    const QueryTypes = Query(.{ Comp1, Comp2 });
    try std.testing.expectEqual(2, QueryTypes.ids.len);
    try std.testing.expectEqual(skore.registry.getTypeId(Comp1), QueryTypes.ids[0]);
    try std.testing.expectEqual(skore.registry.getTypeId(Comp2), QueryTypes.ids[1]);
    try std.testing.expect(QueryTypes.hash != 0);
}
