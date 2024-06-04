const std = @import("std");
const skore = @import("../skore.zig");
const ecs = skore.ecs;

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
    queries: ecs.query.QueryHashMap,

    pub fn init(registry: *skore.Registry, allocator: std.mem.Allocator) World {
        return .{
            .allocator = allocator,
            .registry = registry,
            .archetypes = ecs.ArchetypeHashMap.init(allocator),
            .entity_storage = std.ArrayList(EntityStorage).init(allocator),
            .entity_counter = 1,
            .queries = ecs.query.QueryHashMap.init(allocator),
        };
    }

    pub fn deinit(self: *World) void {
        {
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
        }
        {
            var iter = self.queries.iterator();
            while (iter.next()) |query_arr| {
                for (query_arr.value_ptr.items) |query_data| {
                    query_data.deinit();
                    self.allocator.destroy(query_data);
                }
                query_arr.value_ptr.deinit();
            }
        }

        self.archetypes.deinit();
        self.entity_storage.deinit();
        self.queries.deinit();
    }

    fn findOrCreateStorage(self: *World, entity: ecs.Entity) !*EntityStorage {
        if (self.entity_storage.items.len <= entity) {
            const old_len = self.entity_storage.items.len;
            const new_len = ((entity * 3) / 2) + 1;
            try self.entity_storage.resize(new_len);

            for (old_len..new_len) |value| {
                self.entity_storage.items[value].archetype = null;
            }
        }
        return &self.entity_storage.items[entity];
    }

    fn genId(self: *World) ecs.Entity {
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

        var it = world.queries.iterator();
        while (it.next()) |queries| {
            for (queries.value_ptr.items) |query_it| {
                try query_it.checkArchetypes(world, archetype);
            }
        }

        const res = try world.archetypes.getOrPut(hash);
        if (!res.found_existing) {
            res.value_ptr.* = std.ArrayList(*ecs.Archetype).init(world.allocator);
        }
        try res.value_ptr.append(archetype);
        return archetype;
    }

    fn findOrCreateArchetype(world: *World, ids: [*]skore.TypeId, size: u32) !*ecs.Archetype {
        const hash = ecs.makeHash(ids, size);

        if (world.archetypes.get(hash)) |archetype| {
            //TODO - check multiple archetypes with same id
            if (archetype.items.len > 1) {
                std.debug.print("multiple archetypes found for id {d}", .{hash});
                return error.NotAvailableYet;
            }
            return archetype.getLast();
        }

        var new_ids: [ecs.archetype_max_components]u128 = undefined;
        for (0..size) |i| {
            new_ids[i] = ids[i];
        }
        std.mem.sort(skore.TypeId, new_ids[0..size], {}, std.sort.asc(skore.TypeId));

        return try world.createArchetype(hash, new_ids[0..size]);
    }

    fn findOrCreateChunk(world: *World, archetype_opt: ?*ecs.Archetype) !ecs.ArchetypeChunk {
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
                try archetype.chunks.append(chunk);
                return chunk;
            }
        }

        return error.ChunkCannotBeCreated;
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

    fn moveEntityArchetype(world: *World, entity: ecs.Entity, entity_storage: *EntityStorage, new_archetype: *ecs.Archetype) !void {
        if (entity_storage.archetype) |old_archetype| {
            if (old_archetype == new_archetype) return;
            if (entity_storage.chunk) |old_chunk| {
                const new_chunk = try world.findOrCreateChunk(new_archetype);

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

    fn addComponentsToEntity(world: *World, entity: ecs.Entity, ids: [*]skore.TypeId, len: u32) !void {
        var entity_storage = try world.findOrCreateStorage(entity);
        if (entity_storage.archetype == null) {
            entity_storage.archetype = try world.findOrCreateArchetype(ids, len);
            entity_storage.chunk = try world.findOrCreateChunk(entity_storage.archetype);
            entity_storage.chunk_index = entity_storage.archetype.?.addEntityChunk(entity_storage.chunk.?, entity);
        } else if (entity_storage.archetype) |archetype| {
            var arr: [ecs.archetype_max_components]skore.TypeId = undefined;
            var i: u32 = 0;

            for (archetype.types.items) |archetype_type| {
                arr[i] = archetype_type.type_id;
                i += 1;
            }
            for (0..len) |i_id| {
                arr[i] = ids[i_id];
                i += 1;
            }
            try world.moveEntityArchetype(entity, entity_storage, try world.findOrCreateArchetype(&arr, i));
        }
    }

    fn removeWithIds(world: *World, entity: ecs.Entity, ids: [*]skore.TypeId, size: u32) !void {
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

            try world.moveEntityArchetype(entity, entity_storage, try world.findOrCreateArchetype(&arr, arr_size));
        }
    }

    pub fn add(world: *World, entity: ecs.Entity, types: anytype) !void {
        const struct_type = @typeInfo(@TypeOf(types));
        const fields_info = struct_type.Struct.fields;
        const len = fields_info.len;

        var ids: [len]skore.TypeId = undefined;
        ecs.getIds(types, &ids);
        try world.addComponentsToEntity(entity, &ids, len);

        const entity_storage = &world.entity_storage.items[entity];
        if (entity_storage.archetype) |archetype| {
            if (entity_storage.chunk) |chunk| {
                inline for (fields_info, 0..) |field, i| {
                    const id = ids[i];
                    if (archetype.typeIndex.get(id)) |index| {
                        const archetype_type = archetype.types.items[index];
                        const data = ecs.Archetype.getChunkComponentData(archetype_type, chunk, entity_storage.chunk_index);

                        const field_type = @typeInfo(field.type);
                        if (field_type == .Struct) {
                            const value = @field(types, fields_info[i].name);
                            @memcpy(data.ptr, std.mem.asBytes(&value));
                        } else if (field_type == .Type and archetype_type.type_handler.init != undefined) {
                            archetype_type.type_handler.init(archetype_type.type_handler.ctx, world.allocator, data.ptr);
                        }
                    }
                }
            }
        }
    }

    pub fn create(self: *World, types: anytype) !ecs.Entity {
        const entity = self.genId();
        try self.add(entity, types);
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

    pub fn remove(world: *World, comptime types: anytype, entity: ecs.Entity) !void {
        const struct_type = @typeInfo(@TypeOf(types));
        const fields_info = struct_type.Struct.fields;
        const len = fields_info.len;

        var ids: [len]skore.TypeId = undefined;
        ecs.getIds(types, &ids);
        try world.removeWithIds(entity, &ids, len);
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

    pub fn findOrCreateQueryData(world: *World, hash_id: skore.TypeId, ids: [*]const skore.TypeId, num: u32) !*ecs.QueryData {
        const res = try world.queries.getOrPut(hash_id);
        if (!res.found_existing) {
            res.value_ptr.* = std.ArrayList(*ecs.QueryData).init(world.allocator);
        }

        if (res.value_ptr.items.len > 0) {
            //just in case same hash has more then one type.
            if (res.value_ptr.items.len > 1) {
                for (0..res.value_ptr.items.len) |i| {
                    const query_data = res.value_ptr.items[i];
                    var found = true;
                    if (query_data.types.items.len == num) {
                        for (0..num) |type_index| {
                            if (query_data.types.items[type_index] != ids[type_index]) {
                                found = false;
                                break;
                            }
                        }
                    }
                    if (found) {
                        return query_data;
                    }
                }
            } else {
                return res.value_ptr.getLast();
            }
        }

        var query_data = world.allocator.create(ecs.QueryData) catch undefined;
        query_data.types = std.ArrayList(skore.TypeId).initCapacity(world.allocator, num) catch undefined;
        query_data.archetypes = std.ArrayList(ecs.query.QueryArchetype).init(world.allocator);

        for (0..num) |i| {
            query_data.types.append(ids[i]) catch undefined;
        }

        var iter = world.archetypes.iterator();
        while (iter.next()) |archetypes| {
            for (0..archetypes.value_ptr.items.len) |value| {
                query_data.checkArchetypes(world, archetypes.value_ptr.items[value]) catch undefined;
            }
        }

        res.value_ptr.append(query_data) catch undefined;
        return query_data;
    }

    pub fn query(world: *World, comptime T: anytype) !ecs.Query(T) {
        const QueryType = ecs.Query(T);
        return .{ .query_data = try findOrCreateQueryData(world, QueryType.hash, &QueryType.ids, QueryType.ids.len) };
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

    var storage = try world.findOrCreateStorage(0);
    storage.archetype = &a;
    try std.testing.expect(storage.archetype != null);
    try std.testing.expectEqual(1, storage.archetype.?.id);

    const entity_one = try world.create(.{ Position, Speed });
    try std.testing.expectEqual(1, entity_one);

    const another_storage = try world.findOrCreateStorage(entity_one);
    try std.testing.expect(another_storage.archetype != null);

    try std.testing.expect(world.has(Position, entity_one));
    try std.testing.expect(world.has(Speed, entity_one));

    if (world.get(Speed, entity_one)) |speed| {
        try std.testing.expectEqual(1.0, speed.x);
        try std.testing.expectEqual(1.0, speed.y);
    } else {
        return error.TestExpectedEqual;
    }

    const entity_two = try world.create(.{ Position{ .x = 10, .y = 20 }, Speed{ .x = 1.2, .y = 1.2 } });
    try std.testing.expectEqual(2, entity_two);

    const storage_three = try world.findOrCreateStorage(entity_one);
    const storage_for = try world.findOrCreateStorage(entity_two);
    try std.testing.expectEqual(storage_three.archetype, storage_for.archetype);

    world.destroy(entity_one);

    try std.testing.expect(!world.has(Position, entity_one));
    try std.testing.expect(!world.has(Speed, entity_one));

    if (world.get(Position, entity_two)) |position| {
        try std.testing.expectEqual(10, position.x);
        try std.testing.expectEqual(20, position.y);
    } else {
        return error.TestExpectedEqual;
    }

    const entity_three = try world.create(.{Position{ .x = 100, .y = 200 }});
    const storage_five = try world.findOrCreateStorage(entity_three);
    const storage_six = try world.findOrCreateStorage(entity_two);

    try std.testing.expect(storage_five.archetype != storage_six.archetype);

    try std.testing.expect(!world.has(AnotherComp, entity_three));
    try std.testing.expect(!world.has(Speed, entity_three));

    try world.add(entity_three, .{ AnotherComp{ .t = true }, Speed{ .x = 1.5, .y = 1.7 } });

    try std.testing.expect((try world.findOrCreateStorage(entity_three)).archetype != (try world.findOrCreateStorage(entity_two)).archetype);
    try std.testing.expect(world.has(Position, entity_three));
    try std.testing.expect(world.has(AnotherComp, entity_three));
    try std.testing.expect(world.has(Speed, entity_three));

    if (world.get(Position, entity_three)) |position| {
        try std.testing.expectEqual(100, position.x);
        try std.testing.expectEqual(200, position.y);
    }

    if (world.get(Speed, entity_three)) |speed| {
        try std.testing.expectEqual(1.5, speed.x);
        try std.testing.expectEqual(1.7, speed.y);
    }

    if (world.get(AnotherComp, entity_three)) |another_comp| {
        try std.testing.expectEqual(true, another_comp.t);
    }

    try world.remove(.{AnotherComp}, entity_three);

    //check if backs to the same archetype with Position/Speed
    try std.testing.expect((try world.findOrCreateStorage(entity_three)).archetype == (try world.findOrCreateStorage(entity_two)).archetype);
}

test "test basic query" {
    var registry = skore.Registry.init(std.testing.allocator);
    defer registry.deinit();

    registry.add(Position);
    registry.add(Speed);
    registry.add(AnotherComp);

    var world = World.init(&registry, std.testing.allocator);
    defer world.deinit();

    for (0..40) |i| {
        _ = try world.create(.{ Position{ .x = @floatFromInt(i), .y = @floatFromInt(i * 2) }, Speed{ .x = 2, .y = 2 } });
    }

    {
        var query = try world.query(.{ Position, Speed });
        var iter = query.iter();

        var sum: u32 = 0;

        while (iter.next()) |row| {
            const pos = row.get(Position);
            const x_int: u32 = @intFromFloat(pos.x);
            const y_int: u32 = @intFromFloat(pos.y);

            try std.testing.expect(row.getEntity() != 0);
            try std.testing.expectEqual(x_int, sum);
            try std.testing.expectEqual(y_int, sum * 2);
            sum += 1;
        }
        try std.testing.expectEqual(40, sum);
    }

    {
        {
            var query = try world.query(.{AnotherComp});

            for (0..5) |_| {
                _ = try world.create(.{ AnotherComp{
                    .t = true,
                }, Speed{
                    .x = 2,
                    .y = 2,
                } });
            }

            var iter = query.iter();

            var sum: u32 = 0;

            while (iter.next()) |row| {
                try std.testing.expect(row.getEntity() != 0);
                sum += 1;

                const another_comp = row.get(AnotherComp);
                try std.testing.expect(another_comp.t);
            }
            try std.testing.expectEqual(5, sum);
        }
    }

    {
        var sum: u32 = 0;

        var query = try world.query(.{Speed});
        var iter = query.iter();

        while (iter.next()) |_| {
            sum += 1;
        }

        try std.testing.expectEqual(45, sum);
    }
}

const TestCompOne = struct { i: u32 = 0 };
const TestCompTwo = struct { j: u32 = 0 };

test "ecs complete" {
    var registry = skore.Registry.init(std.testing.allocator);
    defer registry.deinit();

    registry.add(TestCompOne);
    registry.add(TestCompTwo);

    var world = World.init(&registry, std.testing.allocator);
    defer world.deinit();

    for (0..10) |i| {
        _ = try world.create(.{
            TestCompOne{ .i = @intCast(i)},
            TestCompTwo{ .j = @as(u32, @intCast(i)) * 2}
        });
    }

    const query = try world.query(.{TestCompOne, TestCompTwo});
    var iter = query.iter();
    while (iter.next()) |item| {
        const comp_one = item.get(TestCompOne);
        const comp_two = item.get(TestCompTwo);
        try std.testing.expectEqual(comp_one.i * 2, comp_two.j);
    }
}
