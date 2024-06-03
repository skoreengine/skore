const std = @import("std");
const skore = @import("../skore.zig");
const ecs = skore.ecs;

pub fn QueryIter(comptime _: anytype) type {
    return struct {
        const This = @This();

        pub fn get(_: This, comptime T: type) *const T {}

        pub fn getMut(_: This, comptime T: type) *T {}
    };
}

pub fn Query(comptime T: anytype) type {
    return struct {
        const This = @This();

        pub fn next(_: *This) ?QueryIter(T) {
            return null;
        }
    };
}

const EntityStorage = struct {
    archetype: ?*ecs.Archetype,
    chunk: ?ecs.ArchetypeChunk,
    chunk_index: usize = 0,
};

pub const World = struct {
    allocator: std.mem.Allocator,
    registry: *skore.Registry,
    archetypes: ecs.ArchetypeHashMap,
    entity_storage: std.ArrayList(EntityStorage),
    entity_counter: ecs.Entity,

    pub fn init(registry: *skore.Registry, allocator: std.mem.Allocator) World {
        return .{
            .allocator = allocator,
            .registry = registry,
            .archetypes = ecs.ArchetypeHashMap.init(allocator),
            .entity_storage = std.ArrayList(EntityStorage).init(allocator),
            .entity_counter = 1,
        };
    }

    pub fn deinit(self: *World) void {
        var iter = self.archetypes.iterator();

        while (iter.next()) |archetypes| {
            for (archetypes.value_ptr.items) |archetype| {
                archetype.types.deinit();
                for (archetype.chunks.items) |chunk| {
                    self.allocator.rawFree(chunk[0..archetype.chunk_total_alloc_size], 1, 0);
                }
                archetype.chunks.deinit();
                archetype.typeIndex.deinit();
                self.allocator.destroy(archetype);
            }
            archetypes.value_ptr.deinit();
        }
        self.archetypes.deinit();
        self.entity_storage.deinit();
    }

    fn findOrCreateStorage(self: *World, entity: ecs.Entity) *EntityStorage {
        if (self.entity_storage.items.len <= entity) {
            const old_len = self.entity_storage.items.len;
            const new_len = ((entity * 3) / 2) + 1;
            self.entity_storage.resize(new_len) catch unreachable;

            for (old_len..new_len) |value| {
                self.entity_storage.items[value].archetype = null;
            }
        }
        return &self.entity_storage.items[entity];
    }

    fn new(self: *World) ecs.Entity {
        const count = @atomicLoad(ecs.Entity, &self.entity_counter, std.builtin.AtomicOrder.acquire);
        @atomicStore(ecs.Entity, &self.entity_counter, count + 1, std.builtin.AtomicOrder.release);
        return count;
    }

    fn createArchetype(world: *World, hash: u128, ids: []skore.TypeId) !*ecs.Archetype {
        var archetype = try world.allocator.create(ecs.Archetype);
        archetype.hash = hash;
        archetype.id = world.archetypes.count();
        archetype.chunk_total_alloc_size = 0;
        archetype.chunk_data_size = 0;
        archetype.entity_array_offset = 0;
        archetype.entity_count_offset = 0;
        archetype.chunk_state_offset = 0;
        archetype.types = try std.ArrayList(ecs.ArchetypeType).initCapacity(world.allocator, ids.len);
        archetype.typeIndex = std.AutoHashMap(u128, usize).init(world.allocator);
        archetype.chunks = std.ArrayList(ecs.ArchetypeChunk).init(world.allocator);

        var stride: usize = 0;

        if (ids.len > 0) {
            for (ids) |id| {
                if (world.registry.findTypeById(id)) |type_handler| {
                    try archetype.typeIndex.put(id, archetype.types.items.len);

                    try archetype.types.append(.{
                        .type_id = id,
                        .type_handler = type_handler,
                        .type_size = type_handler.getSize(type_handler.ctx),
                    });
                    stride += type_handler.getSize(type_handler.ctx);
                } else {
                    return error.TypeNotFound;
                }
            }

            archetype.max_entity_chunk_count = @max(ecs.chunk_component_size / stride, 1);
            archetype.chunk_total_alloc_size = archetype.max_entity_chunk_count * @sizeOf(ecs.Entity);
            archetype.entity_count_offset = archetype.chunk_total_alloc_size;
            archetype.chunk_total_alloc_size += @sizeOf(u32);
            archetype.chunk_state_offset = archetype.chunk_total_alloc_size;
            archetype.chunk_total_alloc_size += ids.len * @sizeOf(ecs.ComponentState);
            archetype.chunk_data_size = archetype.chunk_total_alloc_size;

            for (0..ids.len) |i| {
                archetype.types.items[i].data_offset = archetype.chunk_total_alloc_size;
                archetype.chunk_total_alloc_size += archetype.max_entity_chunk_count * archetype.types.items[i].type_size;
                archetype.types.items[i].state_offset = archetype.chunk_total_alloc_size;
                archetype.chunk_total_alloc_size += archetype.max_entity_chunk_count * @sizeOf(ecs.ComponentState);
            }
        } else {
            //empty archetype.
            archetype.max_entity_chunk_count = ecs.chunk_component_size / @sizeOf(ecs.Entity);
            archetype.chunk_total_alloc_size = archetype.max_entity_chunk_count * @sizeOf(ecs.Entity);
            archetype.entity_count_offset = archetype.chunk_total_alloc_size;
            archetype.chunk_total_alloc_size += @sizeOf(u32);
        }

        const res = try world.archetypes.getOrPut(hash);
        if (!res.found_existing) {
            res.value_ptr.* = std.ArrayList(*ecs.Archetype).init(world.allocator);
        }
        try res.value_ptr.append(archetype);
        return archetype;
    }

    fn findOrCreateArchetype(world: *World, ids: [*]skore.TypeId, size: u32) *ecs.Archetype {
        const hash = ecs.archetype.makeArchetypeHash(ids, size);

        if (world.archetypes.get(hash)) |archetype| {
            //TODO - check multiple archetypes with same id
            if (archetype.items.len > 1) {
                std.debug.print("multiple archetypes found for id {d}", .{hash});
                unreachable;
            }
            return archetype.getLast();
        }

        var new_ids: [ecs.archetype_max_components]u128 = undefined;
        for (0..size) |i| {
            new_ids[i] = ids[i];
        }
        std.mem.sort(skore.TypeId, new_ids[0..size], {}, std.sort.asc(skore.TypeId));

        return world.createArchetype(hash, new_ids[0..size]) catch unreachable;
    }

    fn findOrCreateChunk(world: *World, archetype_opt: ?*ecs.Archetype) ?ecs.ArchetypeChunk {
        if (archetype_opt) |archetype| {
            if (archetype.chunks.items.len > 0) {
                const active_chunk = archetype.chunks.getLast();
                if (archetype.max_entity_chunk_count > archetype.getEntityCount(active_chunk).*) {
                    return active_chunk;
                }
            }
            const chunk_opt = world.allocator.rawAlloc(archetype.chunk_total_alloc_size, 1, 0);
            if (chunk_opt) |chunk| {
                for (0..archetype.chunk_total_alloc_size) |i| {
                    chunk[i] = 0;
                }
                archetype.chunks.append(chunk) catch undefined;
            }
            return chunk_opt;
        }
        return null;
    }

    fn removeEntityFromChunk(world: *World, entity: ecs.Entity, entity_storage: *EntityStorage) void {
        if (entity_storage.archetype) |archetype| {
            //move last entity from active chunk to the current position
            if (archetype.chunks.getLastOrNull()) |active_chunk| {
                if (entity_storage.chunk) |chunk| {
                    const entity_count = archetype.getEntityCount(active_chunk);
                    const last_index = entity_count.* - 1;
                    const last_entity = archetype.getChunkEntity(active_chunk, last_index).*;
                    const chunk_entity = archetype.getChunkEntity(chunk, entity_storage.chunk_index);

                    if (last_entity != entity) {
                        for (archetype.types.items) |archetype_type| {
                            const src = ecs.Archetype.getChunkComponentData(archetype_type, active_chunk, last_index);
                            const dst = ecs.Archetype.getChunkComponentData(archetype_type, chunk, entity_storage.chunk_index);

                            if (archetype_type.type_handler.copy != undefined) {
                                archetype_type.type_handler.copy(archetype_type.type_handler.ctx, world.allocator, dst.ptr, src.ptr);
                            }

                            //TODO copy state
                            // FY_CHUNK_COMPONENT_STATE(type, entityContainer.chunk, entityContainer.chunkIndex) = FY_CHUNK_COMPONENT_STATE(type, activeChunk, lastIndex);
                            // type.sparse->Emplace(lastEntity, dst);
                        }
                    }
                    chunk_entity.* = last_entity;
                    world.entity_storage.items[last_entity].chunk = chunk;
                    world.entity_storage.items[last_entity].chunk_index = entity_storage.chunk_index;

                    entity_count.* = entity_count.* - 1;
                    if (entity_count.* == 0) {
                        world.allocator.rawFree(chunk[0..archetype.chunk_total_alloc_size], 1, 0);
                        _ = archetype.chunks.popOrNull();
                    }
                }
            }
        }
    }

    fn moveEntityArchetype(world: *World, entity: ecs.Entity, entity_storage: *EntityStorage, new_archetype: *ecs.Archetype) void {
        if (entity_storage.archetype) |old_archetype| {
            if (old_archetype == new_archetype) return;
            if (entity_storage.chunk) |old_chunk| {
                if (world.findOrCreateChunk(new_archetype)) |new_chunk| {
                    const new_index = new_archetype.addEntityChunk(new_chunk, entity);
                    for (old_archetype.types.items) |archetype_type| {
                        const src = ecs.Archetype.getChunkComponentData(archetype_type, old_chunk, entity_storage.chunk_index);

                        if (new_archetype.typeIndex.get(archetype_type.type_id)) |new_type_index| {
                            const new_archetype_type = new_archetype.types.items[new_type_index];
                            const dst = ecs.Archetype.getChunkComponentData(new_archetype_type, new_chunk, new_index);
                            @memcpy(dst, src);
                            //destType.sparse->Emplace(entity, src);
                        } else {
                            //type.sparse->Remove(entity);
                        }
                    }

                    world.removeEntityFromChunk(entity, entity_storage);

                    entity_storage.chunk_index = new_index;
                    entity_storage.chunk = new_chunk;
                    entity_storage.archetype = new_archetype;
                }
            }
        }
    }

    fn addWithIds(world: *World, entity: ecs.Entity, ids: [*]skore.TypeId, components: [*]const ?*anyopaque, size: u32) void {
        var entity_storage = world.findOrCreateStorage(entity);
        if (entity_storage.archetype == null) {
            entity_storage.archetype = world.findOrCreateArchetype(ids, size);
            entity_storage.chunk = world.findOrCreateChunk(entity_storage.archetype);
            entity_storage.chunk_index = entity_storage.archetype.?.addEntityChunk(entity_storage.chunk.?, entity);
        } else if (entity_storage.archetype) |archetype| {
            var arr: [ecs.archetype_max_components]skore.TypeId = undefined;
            var i: u32 = 0;

            for (archetype.types.items) |archetype_type| {
                arr[i] = archetype_type.type_id;
                i += 1;
            }
            for (0..size) |i_id| {
                arr[i] = ids[i_id];
                i += 1;
            }
            world.moveEntityArchetype(entity, entity_storage, world.findOrCreateArchetype(&arr, i));
        }

        if (entity_storage.archetype) |archetype| {
            if (entity_storage.chunk) |chunk| {
                for (0..size) |i| {
                    const id = ids[i];
                    if (archetype.typeIndex.get(id)) |index| {
                        const archetype_type = archetype.types.items[index];
                        const data = ecs.Archetype.getChunkComponentData(archetype_type, chunk, entity_storage.chunk_index);
                        if (components[i]) |comp_data| {
                            if (archetype_type.type_handler.copy != undefined) {
                                archetype_type.type_handler.copy(archetype_type.type_handler.ctx, world.allocator, data.ptr, comp_data);
                            }
                        } else if (archetype_type.type_handler.init != undefined) {
                            archetype_type.type_handler.init(archetype_type.type_handler.ctx, world.allocator, data.ptr);
                        }
                    }
                }
            }
        }
    }

    fn removeWithIds(world: *World, entity: ecs.Entity, ids: [*]skore.TypeId, size: u32) void {
        const entity_storage = &world.entity_storage.items[entity];

        if (entity_storage.archetype) |archetype| {
            var arr: [ecs.archetype_max_components]skore.TypeId = undefined;
            var arr_size: u32 = 0;

            for (archetype.types.items) |archetype_type| {
                var found = false;
                for (0..size) |i| {
                    if (ids[i] == archetype_type.type_id) {
                        found = true;
                        break;
                    }
                }
                //not found on list to remove (ids). keep it
                if (!found) {
                    arr[arr_size] = archetype_type.type_id;
                    arr_size += 1;
                }
            }

            //same len, so no type found to remove
            if (arr_size == archetype.types.items.len) {
                return;
            }

            world.moveEntityArchetype(entity, entity_storage, world.findOrCreateArchetype(&arr, arr_size));
        }
    }

    fn getCompNum(comptime types: anytype) usize {
        const struct_type = @typeInfo(@TypeOf(types));
        return struct_type.Struct.fields.len;
    }

    fn getComps(comptime types: anytype, comptime ids: []skore.TypeId, comptime components_opt: ?[]?*anyopaque) void {
        const struct_type = @typeInfo(@TypeOf(types));
        for (struct_type.Struct.fields, 0..) |field, i| {
            const field_type = @typeInfo(field.type);
            if (field_type == .Type) {
                if (field.default_value) |default_value| {
                    const typ: *type = @ptrCast(@constCast(default_value));
                    ids[i] = skore.registry.getTypeId(typ.*);
                    if (components_opt) |components| {
                        components[i] = null;
                    }
                }
            } else if (field_type == .Struct) {
                ids[i] = skore.registry.getTypeId(field.type);
                if (field.default_value) |default_value| {
                    if (components_opt) |components| {
                        components[i] = @constCast(default_value);
                    }
                }
            }
        }
    }

    pub fn add(world: *World, entity: ecs.Entity, comptime types: anytype) void {
        const size = comptime getCompNum(types);
        comptime var new_ids: [size]skore.TypeId = undefined;
        comptime var new_comps: [size]?*anyopaque = undefined;
        comptime getComps(types, &new_ids, &new_comps);

        var runtime_ids = new_ids;
        var runtime_compts = new_comps;
        world.addWithIds(entity, &runtime_ids, &runtime_compts, size);
    }

    pub fn spawn(self: *World, comptime types: anytype) ecs.Entity {
        const entity = self.new();
        self.add(entity, types);
        return entity;
    }

    pub fn destroy(world: *World, entity: ecs.Entity) void {
        if (world.entity_storage.items.len > entity) {
            var entity_storage = &world.entity_storage.items[entity];
            world.removeEntityFromChunk(entity, entity_storage);
            entity_storage.chunk_index = 0;
            entity_storage.chunk = null;
            entity_storage.archetype = null;
        }
    }

    pub fn remove(world: *World, comptime types: anytype, entity: ecs.Entity) void {
        const size = comptime getCompNum(types);
        comptime var new_ids: [size]skore.TypeId = undefined;
        comptime getComps(types, &new_ids, null);
        var runtime_ids = new_ids;
        world.removeWithIds(entity, &runtime_ids, size);
    }

    pub fn get(world: *World, comptime T: type, entity: ecs.Entity) ?*const T {
        const entity_storage = world.entity_storage.items[entity];
        if (entity_storage.archetype) |archetype| {
            if (entity_storage.chunk) |chunk| {
                if (archetype.typeIndex.get(skore.registry.getTypeId(T))) |index| {
                    return @alignCast(@ptrCast(ecs.Archetype.getChunkComponentData(archetype.types.items[index], chunk, entity_storage.chunk_index)));
                }
            }
        }
        return null;
    }

    pub fn has(world: *World, comptime T: type, entity: ecs.Entity) bool {
        return world.get(T, entity) != null;
    }

    pub fn query(_: *World, comptime T: anytype) Query(T) {
        return Query(T){};
    }
};

const Position = struct { x: f32 = 0, y: f32 = 0 };
const Speed = struct { x: f32 = 1.0, y: f32 = 1.0 };
const AnotherComp = struct { t: bool };

test "test basic world" {
    var registry = skore.Registry.init(std.testing.allocator);
    defer registry.deinit();

    registry.add(Position);
    registry.add(Speed);
    registry.add(AnotherComp);

    var world = World.init(&registry, std.testing.allocator);
    defer world.deinit();

    var a = ecs.Archetype{ .hash = 0, .id = 1 };

    var storage = world.findOrCreateStorage(0);
    storage.archetype = &a;
    try std.testing.expect(storage.archetype != null);
    try std.testing.expectEqual(1, storage.archetype.?.id);

    const entityOne = world.spawn(.{ Position, Speed });
    try std.testing.expectEqual(1, entityOne);
    try std.testing.expect(world.findOrCreateStorage(entityOne).archetype != null);

    try std.testing.expect(world.has(Position, entityOne));
    try std.testing.expect(world.has(Speed, entityOne));

    if (world.get(Speed, entityOne)) |speed| {
        try std.testing.expectEqual(1.0, speed.x);
        try std.testing.expectEqual(1.0, speed.y);
    } else {
        return error.TestExpectedEqual;
    }

    const entityTwo = world.spawn(.{ Position{ .x = 10, .y = 20 }, Speed{ .x = 1.2, .y = 1.2 } });
    try std.testing.expectEqual(2, entityTwo);
    try std.testing.expectEqual(world.findOrCreateStorage(entityOne).archetype, world.findOrCreateStorage(entityTwo).archetype);

    world.destroy(entityOne);

    try std.testing.expect(!world.has(Position, entityOne));
    try std.testing.expect(!world.has(Speed, entityOne));

    if (world.get(Position, entityTwo)) |position| {
        try std.testing.expectEqual(10, position.x);
        try std.testing.expectEqual(20, position.y);
    } else {
        return error.TestExpectedEqual;
    }

    const entityThree = world.spawn(.{Position{ .x = 100, .y = 200 }});
    try std.testing.expect(world.findOrCreateStorage(entityThree).archetype != world.findOrCreateStorage(entityTwo).archetype);

    try std.testing.expect(!world.has(AnotherComp, entityThree));
    try std.testing.expect(!world.has(Speed, entityThree));

    world.add(entityThree, .{ AnotherComp{ .t = true }, Speed{ .x = 1.5, .y = 1.7 } });

    try std.testing.expect(world.findOrCreateStorage(entityThree).archetype != world.findOrCreateStorage(entityTwo).archetype);
    try std.testing.expect(world.has(Position, entityThree));
    try std.testing.expect(world.has(AnotherComp, entityThree));
    try std.testing.expect(world.has(Speed, entityThree));

    if (world.get(Position, entityThree)) |position| {
        try std.testing.expectEqual(100, position.x);
        try std.testing.expectEqual(200, position.y);
    }

    if (world.get(Speed, entityThree)) |speed| {
        try std.testing.expectEqual(1.5, speed.x);
        try std.testing.expectEqual(1.7, speed.y);
    }

    if (world.get(AnotherComp, entityThree)) |another_comp| {
        try std.testing.expectEqual(true, another_comp.t);
    }

    world.remove(.{AnotherComp}, entityThree);

    //check if backs to the same archetype with Position/Speed
    try std.testing.expect(world.findOrCreateStorage(entityThree).archetype == world.findOrCreateStorage(entityTwo).archetype);
}
