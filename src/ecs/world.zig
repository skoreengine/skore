const std = @import("std");
const ecs = @import("main.zig");
const registry = @import("../core/registry.zig");


pub fn QueryIter(comptime _ : anytype) type {
    return struct {
        const This = @This();

        pub fn get(_: This, comptime T : type) * const T {

        }

        pub fn getMut(_: This, comptime T : type) *T {

        }
    };
}

pub fn Query(comptime T : anytype) type {
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

    archetypes : ecs.ArchetypeHashMap,
    entity_storage : std.ArrayList(EntityStorage),
    entity_counter : ecs.Entity,

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .archetypes = ecs.ArchetypeHashMap.init(allocator),
            .entity_storage = std.ArrayList(EntityStorage).init(allocator),
            .entity_counter = 0
        };
    }

    pub fn deinit(self: *World) void {
        //TODO need to free archetypes.
        self.archetypes.deinit();
        self.entity_storage.deinit();
    }

    fn findOrCreateStorage(self: *World, entity: ecs.Entity) !*EntityStorage {
        if (self.entity_storage.items.len <= entity) {
            try self.entity_storage.resize(@max((entity * 3) / 2, 1));
        }
        return &self.entity_storage.items[entity];
    }
    
    fn new(self: *World) ecs.Entity {
        const count = @atomicLoad(ecs.Entity, &self.entity_counter, std.builtin.AtomicOrder.acquire);
        @atomicStore(ecs.Entity, &self.entity_counter, count + 1, std.builtin.AtomicOrder.release);
        return count;
    }

    fn findOrCreateArchetype(comptime types: anytype) !void {
        comptime {

            const struct_type = @typeInfo(@TypeOf(types));
            if (struct_type != .Struct) {
                @compileError("expected tuple found " ++ @typeName(@TypeOf(types)));
            }

            for (struct_type.Struct.fields) |field| {
                const field_type = @typeInfo(field.type);
                if (field_type != .Type and field_type != .Struct) {
                    @compileError("expected type or struct argument, found " ++ @typeName(field.type));
                }

                if (field_type == .Type) {

                    //@typeName(field.type)

                }
            }

        }
    }

    pub fn spawn(self: *World, comptime types: anytype) !ecs.Entity {
        const entity = self.new();

        _ = try self.findOrCreateStorage(entity);

        comptime try findOrCreateArchetype(types);


        return entity;
    }

    pub fn add(_: *World, _ : ecs.Entity, comptime _ : anytype ) void {

    }


    pub fn get(_: *World,T : type,  _ : ecs.Entity) ?* const T {
        return null;
    }

    pub fn query(_ : * World, comptime T : anytype) Query(T) {
        return Query(T) {

        };
    }

};


const Position = struct {
    x : f32,
    y : f32
};

const Speed = struct {
    x : f32,
    y : f32
};

test "test basic world" {

    var world = World.init(std.testing.allocator);

    try std.testing.expectEqual(0, world.new());
    try std.testing.expectEqual(1, world.new());
    try std.testing.expectEqual(2, world.new());

    var a = ecs.Archetype{
        .id = 1,
    };

    var storage = try world.findOrCreateStorage(0);
    storage.archetype = &a;
    try std.testing.expect(storage.archetype != null);
    try std.testing.expectEqual(1, storage.archetype.?.id);

    const entity = try world.spawn(.{Position, Speed});


    try std.testing.expectEqual(3, entity);

     _ = [_]registry.TypeId{1, 2, 3};
    // world.add(entity, .{arr});

    // try world.spawn(.{1});

    world.add(entity, .{
        Position{
            .x = 10,
            .y = 20,
        },
        Speed{
            .x = 1.2,
            .y = 1.2,
        }
    });


//    var query = world.query(.{Position, Speed});

    // while(query.next()) |iter|  {
    //
    //     const speed = iter.get(Speed);
    //     var pos = iter.getMut(Position);
    //
    //     pos.x = pos.x + speed.x;
    // }

    defer world.deinit();
}
