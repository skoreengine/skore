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

    fn getCompNum(comptime types: anytype) usize {
        const struct_type = @typeInfo(@TypeOf(types));
        return struct_type.Struct.fields.len;
    }

    fn getComps(comptime types: anytype, comptime ids: []skore.TypeId, comptime components: []?*anyopaque) void {
        const struct_type = @typeInfo(@TypeOf(types));
        for (struct_type.Struct.fields, 0..) |field, i| {
            const field_type = @typeInfo(field.type);
            if (field_type == .Type) {
                if (field.default_value) |const_defaut_value| {
                    const default_value = @constCast(const_defaut_value);
                    const typ: *type = @ptrCast(default_value);
                    ids[i] = skore.registry.getTypeId(typ.*);
                    components[i] = default_value;
                }
            } else if (field_type == .Struct) {
                ids[i] = skore.registry.getTypeId(field.type);
                components[i] = null;
            }
        }
    }

    fn createArchetype(world: *World, hash: u128, ids: []skore.TypeId) !*ecs.Archetype {
        var archetype = try world.allocator.create(ecs.Archetype);
        archetype.hash = hash;
        archetype.id = world.archetypes.count();
        archetype.chunk_alloc_size = 0;
        archetype.chunk_data_size = 0;
        archetype.entity_array_offset = 0;
        archetype.entity_count_offset = 0;
        archetype.chunk_state_offset = 0;
        archetype.types = try std.ArrayList(ecs.ArchetypeType).initCapacity(world.allocator, ids.len);
        archetype.chunks = std.ArrayList(ecs.ArchetypeChunk).init(world.allocator);

        var stride: usize = 0;

        if (ids.len > 0) {

            for (ids) |id| {
                if (world.registry.findTypeById(id)) |type_handler| {
                    try archetype.types.append(.{
                        .id = id,
                        .type_handler = type_handler,
                        .type_size = type_handler.getSize(type_handler.ctx),
                    });
                    stride += type_handler.getSize(type_handler.ctx);
                }
            }

            archetype.max_entity_chunk_count = @max(ecs.chunk_component_size / stride, 1);
            archetype.chunk_alloc_size = archetype.max_entity_chunk_count * @sizeOf(ecs.Entity);
            archetype.entity_count_offset = archetype.chunk_alloc_size;
            archetype.chunk_alloc_size += @sizeOf(u32);
            archetype.chunk_state_offset = archetype.chunk_alloc_size;
            archetype.chunk_alloc_size += ids.len * @sizeOf(ecs.ComponentState);
            archetype.chunk_data_size = archetype.chunk_alloc_size;

            for (0..ids.len) |i| {
                archetype.types.items[i].data_offset = archetype.chunk_alloc_size;
                archetype.chunk_alloc_size += archetype.max_entity_chunk_count * archetype.types.items[i].type_size;
                archetype.types.items[i].state_offset = archetype.chunk_alloc_size;
                archetype.chunk_alloc_size += archetype.max_entity_chunk_count * @sizeOf(ecs.ComponentState);
            }
        } else {
            //empty archetype.
            archetype.max_entity_chunk_count = ecs.chunk_component_size / @sizeOf(ecs.Entity);
            archetype.chunk_alloc_size = archetype.max_entity_chunk_count * @sizeOf(ecs.Entity);
            archetype.entity_count_offset = archetype.chunk_alloc_size;
            archetype.chunk_alloc_size += @sizeOf(u32);
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

    fn addWithIds(world: *World, entity: ecs.Entity, ids: [*]skore.TypeId, _: [*]const ?*anyopaque, size: u32) void {
        var entity_storage = world.findOrCreateStorage(entity);
        if (entity_storage.archetype == null) {
            entity_storage.archetype = world.findOrCreateArchetype(ids, size);
        } else {}
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

    pub fn get(_: *World, comptime T: type, _: ecs.Entity) ?*const T {
        return null;
    }

    pub fn query(_: *World, comptime T: anytype) Query(T) {
        return Query(T){};
    }
};

const Position = struct { x: f32, y: f32 };
const Speed = struct { x: f32, y: f32 };
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

    const entityTwo = world.spawn(.{ Position{ .x = 10, .y = 20 }, Speed{ .x = 1.2, .y = 1.2 } });
    try std.testing.expectEqual(2, entityTwo);
    try std.testing.expectEqual(world.findOrCreateStorage(entityOne).archetype, world.findOrCreateStorage(entityTwo).archetype);

    const entityThree = world.spawn(.{AnotherComp{ .t = false }});
    try std.testing.expect(world.findOrCreateStorage(entityThree).archetype != world.findOrCreateStorage(entityTwo).archetype);

    //world.add(entity, .{ Position{ .x = 10, .y = 20 }, Speed{ .x = 1.2, .y = 1.2 } });
}
