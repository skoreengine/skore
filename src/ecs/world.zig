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
            .entity_counter = 0
        };
    }

    pub fn deinit(self: *World) void {
        var iter = self.archetypes.iterator();

        while(iter.next()) |archetypes| {
            for(archetypes.value_ptr.items) |archetype| {
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
            const new_len = @max((entity * 3) / 2, 1);
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

    fn getCompIds(comptime types: anytype, comptime ids: []skore.TypeId) void {
        const struct_type = @typeInfo(@TypeOf(types));
        for (struct_type.Struct.fields, 0..) |field, i| {
            const field_type = @typeInfo(field.type);
            if (field_type == .Type) {
                if (field.default_value) |defaut_value| {
                    const typ: *type = @ptrCast(@constCast(defaut_value));
                    ids[i] = skore.registry.getTypeId(typ.*);
                }
            } else if (field_type == .Struct) {
                ids[i] = skore.registry.getTypeId(field.type);
            }
        }
    }


    fn createArchetype(world: *World, hash: u128, ids: []skore.TypeId) !*ecs.Archetype {

        var archetype = try world.allocator.create(ecs.Archetype);
        archetype.hash = hash;
        archetype.id = world.archetypes.count();
        archetype.types = try std.ArrayList(ecs.ArchetypeType).initCapacity(world.allocator, ids.len);

        for (ids) |id| {
            try archetype.types.append(.{
                .id = id,
                .data_offset = 0,
                .state_offset = 0,
                .type_handler = world.registry.findTypeById(id)
            });
        }

        const res = try world.archetypes.getOrPut(hash);
        if (!res.found_existing) {
            res.value_ptr.* = std.ArrayList(*ecs.Archetype).init(world.allocator);
        }
        try res.value_ptr.append(archetype);
        return archetype;
    }

    export fn findOrCreateArchetype(world: *World, ids: [*]skore.TypeId, size : u32) *ecs.Archetype {
        const hash = ecs.archetype.makeArchetypeHash(ids, size);

        if (world.archetypes.get(hash)) |archetype| {
            //TODO - check multiple archetypes with same id
            if (archetype.items.len > 1) {
                std.debug.print("multiple archetypes found for id {d}", .{hash});
                unreachable;
            }
            return archetype.getLast();
        }

        var new_ids : [ecs.archetype_max_components]u128 = undefined;
        for(0..size) |i| {
            new_ids[i] = ids[i];
        }
        std.mem.sort(skore.TypeId, new_ids[0..size], {}, std.sort.asc(skore.TypeId));

        return world.createArchetype(hash, new_ids[0..size]) catch unreachable;
    }

    pub fn add(world: *World, entity: ecs.Entity, comptime types: anytype) !void {
        comptime var new_ids: [getCompNum(types)]skore.TypeId = undefined;
        comptime getCompIds(types, &new_ids);

        var new_ids_1 = new_ids;

        var entity_storage = world.findOrCreateStorage(entity);
        if (entity_storage.archetype == null) {
            entity_storage.archetype = world.findOrCreateArchetype(&new_ids_1, new_ids_1.len);
        }
    }

    pub fn spawn(self: *World, comptime types: anytype) !ecs.Entity {
        const entity = self.new();
        try self.add(entity, types);
        return entity;
    }

    pub fn get(_: *World, T: type, _: ecs.Entity) ?*const T {
        return null;
    }

    pub fn query(_: *World, comptime T: anytype) Query(T) {
        return Query(T){};
    }
};

const Position = struct { x: f32, y: f32 };
const Speed = struct { x: f32, y: f32 };

test "test basic world" {
    var registry = skore.Registry.init(std.heap.page_allocator);
    defer registry.deinit();

    registry.add(Position);
    registry.add(Speed);

    var world = World.init(&registry, std.testing.allocator);
    defer world.deinit();

    try std.testing.expectEqual(0, world.new());
    try std.testing.expectEqual(1, world.new());
    try std.testing.expectEqual(2, world.new());

    var a = ecs.Archetype{ .hash = 0, .id = 1, .types = undefined };

    var storage = world.findOrCreateStorage(0);
    storage.archetype = &a;
    try std.testing.expect(storage.archetype != null);
    try std.testing.expectEqual(1, storage.archetype.?.id);

    const entity = try world.spawn(.{ Position, Speed });

    _ = try world.spawn(.{Position{
        .x = 10,
        .y = 20
    }, Speed{
        .x = 1.2,
        .y = 1.2
    }});

    try std.testing.expectEqual(3, entity);

    try world.add(entity, .{ Position{
        .x = 10,
        .y = 20
    }, Speed{
        .x = 1.2,
        .y = 1.2
    } });
}
