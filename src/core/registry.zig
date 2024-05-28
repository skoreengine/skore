const std = @import("std");

const TypeHandler = packed struct {
    getName: *const fn () [:0]const u8,
    newInstance: *const fn (allocator: std.mem.Allocator) *anyopaque,
    destroyInstance : *const fn () void
};

pub fn NativeTypeHandler(comptime T: type) type {
    return struct {
        const This = @This();

        fn getName() [:0]const u8 {
            return @typeName(T);
        }

        fn newInstance(allocator: std.mem.Allocator) *anyopaque {
            const ret = allocator.create(T) catch unreachable;
            if (@hasDecl(T, "create")) {
                @call(.auto, T.create, .{ret});
            }
            return ret;
        }

        //fn destroyInstance(allocator: std.mem.Allocator, ptr : *anyopaque) void {
        fn destroyInstance() void {
            _ = 0;
            // const value: *T = @alignCast(@ptrCast(ptr));
            // allocator.destroy(value);
        }
    };
}

const Registry = struct {
    allocator: std.mem.Allocator,
    typesByName: std.StringHashMap(std.ArrayList(TypeHandler)),

    pub fn init(allocator: std.mem.Allocator) Registry {
        return Registry{
            .allocator = allocator,
            .typesByName = std.StringHashMap(std.ArrayList(TypeHandler)).init(allocator),
        };
    }

    pub fn deinit(self: *Registry) void {
        var it = self.typesByName.iterator();
        while (it.next()) |kv| {
            kv.value_ptr.deinit();
        }
        self.typesByName.deinit();
    }

    pub fn addType(self: *Registry, t: type) !void {
        const handler = NativeTypeHandler(t);

        const name = handler.getName();
        const res = try self.typesByName.getOrPut(name);

        if (!res.found_existing) {
            res.value_ptr.* = std.ArrayList(TypeHandler).init(self.allocator);
        }

        const typeHandler = TypeHandler{
            .getName =  handler.getName,
            .newInstance = handler.newInstance,
            .destroyInstance = handler.destroyInstance
        };

        try res.value_ptr.append(typeHandler);

        std.debug.print("type {s} added \n", .{name});
    }

    pub fn findTypeByName(self: *Registry, name: [:0]const u8) !*const TypeHandler {
        const value = self.typesByName.get(name);
        if (value) |v| {
            return &v.getLast();
        } else {
            return error.NotFound;
        }
    }
};

const TestType = struct {
    x: i32 = 0,

    pub fn create(self : * TestType) void {
        self.x = 0;
    }
};

test "test registry basics" {
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();

    try std.testing.expectEqual(registry.typesByName.count(), 0);
    try registry.addType(TestType);

    const typeHandler = try registry.findTypeByName("registry.TestType");
    try std.testing.expectEqual(typeHandler.getName(), "registry.TestType");

    const t = typeHandler.newInstance(std.testing.allocator);
    typeHandler.destroyInstance();

    const testType: *TestType = @alignCast(@ptrCast(t));
    try std.testing.expectEqual(0, testType.x);

}
