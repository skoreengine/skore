const std = @import("std");

pub const TypeId = u128;

pub const TypeHandler = packed struct {
    ctx: *anyopaque = undefined,
    getName: *const fn () [:0]const u8 = undefined,
    getTypeId: *const fn (ctx: *anyopaque) TypeId = undefined,
    getSize: *const fn (ctx: *anyopaque) usize = undefined,
    create: *const fn (ctx: *anyopaque, alloc: std.mem.Allocator) *anyopaque = undefined,
    init: *const fn (ctx: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void = undefined,
    deinit: *const fn (ctx: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void = undefined,
    destroy: *const fn (ctx: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void = undefined,
    copy: *const fn (ctx: *anyopaque, alloc: std.mem.Allocator, desc: *anyopaque, origin: *anyopaque) void = undefined,
};

fn genId(comptime t: type) TypeId {
    var hash: TypeId = 0;
    for (@typeName(t)) |n| {
        hash = @addWithOverflow(@addWithOverflow(hash << 5, hash)[0], n)[0];
    }
    return hash;
}

pub fn getTypeId(comptime t: type) TypeId {
    return comptime genId(t);
}

fn canInitialize(comptime T: type) bool {
    comptime {
        var ret = false;
        for (@typeInfo(T).Struct.fields) |field| {
            if (field.default_value) |_| {
                ret = true;
            }
        }
        return ret;
    }
}

pub fn NativeTypeHandler(comptime T: type) type {
    return struct {
        const This = @This();
        const type_id = getTypeId(T);

        fn initHandler(handler: *TypeHandler) void {
            handler.getName = getNameFn;
            handler.getTypeId = getTypeIdFn;
            handler.getSize = getSizeImpl;
            handler.create = createFn;
            handler.init = initFn;
            handler.deinit = deinitFn;
            handler.destroy = destroyFn;
            handler.copy = copyImpl;
        }

        fn getNameFn() [:0]const u8 {
            return @typeName(T);
        }

        fn getSizeImpl(_: *anyopaque) usize {
            return @sizeOf(T);
        }

        fn getTypeIdFn(_: *anyopaque) TypeId {
            return type_id;
        }

        fn createFn(_: *anyopaque, alloc: std.mem.Allocator) *anyopaque {
            return alloc.create(T) catch unreachable;
        }

        fn initFn(_: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void {
            if (comptime canInitialize(T)) {
                const desc: *T = @alignCast(@ptrCast(ptr));
                const value = T{};
                @memcpy(std.mem.asBytes(desc), std.mem.asBytes(&value));
            }

            if (@hasDecl(T, "init")) {
                const value: *T = @alignCast(@ptrCast(ptr));
                @call(.auto, T.init, .{ alloc, value });
            }
        }

        fn deinitFn(_: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void {
            if (@hasDecl(T, "deinit")) {
                const value: *T = @alignCast(@ptrCast(ptr));
                @call(.auto, T.deinit, .{ alloc, value });
            }
        }

        fn destroyFn(_: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void {
            const value: *T = @alignCast(@ptrCast(ptr));
            alloc.destroy(value);
        }

        fn copyImpl(_: *anyopaque, _: std.mem.Allocator, desc: *anyopaque, origin: *anyopaque) void {
            const origin_typ: *T = @alignCast(@ptrCast(origin));
            const desc_typ: *T = @alignCast(@ptrCast(desc));
            @memcpy(std.mem.asBytes(desc_typ), std.mem.asBytes(origin_typ));
        }
    };
}

const ImplStorage = *const anyopaque;

pub const Registry = struct {
    allocator: std.mem.Allocator = undefined,
    types_by_id: std.AutoHashMap(u128, std.ArrayList(*TypeHandler)) = undefined,
    types_by_name: std.StringHashMap(std.ArrayList(*TypeHandler)) = undefined,
    impls_by_id: std.AutoHashMap(TypeId, std.ArrayList(ImplStorage)) = undefined,

    pub fn init(alloc: std.mem.Allocator) Registry {
        return .{
            .allocator = alloc,
            .types_by_id = std.AutoHashMap(u128, std.ArrayList(*TypeHandler)).init(alloc),
            .types_by_name = std.StringHashMap(std.ArrayList(*TypeHandler)).init(alloc),
            .impls_by_id = std.AutoHashMap(TypeId, std.ArrayList(ImplStorage)).init(alloc),
        };
    }

    pub fn deinit(self: *Registry) void {
        {
            var it = self.types_by_name.iterator();
            while (it.next()) |kv| {
                for (kv.value_ptr.items) |type_handler| {
                    self.allocator.destroy(type_handler);
                }
                kv.value_ptr.deinit();
            }
        }

        {
            var it = self.impls_by_id.iterator();
            while (it.next()) |kv| {
                kv.value_ptr.deinit();
            }
        }

        {
            var it = self.types_by_id.iterator();
            while (it.next()) |kv| {
                kv.value_ptr.deinit();
            }
        }

        self.types_by_name.deinit();
        self.types_by_id.deinit();
        self.impls_by_id.deinit();
    }

    fn registerType(self: *Registry, T: type) void {
        const name = @typeName(T);
        const typeId = getTypeId(T);

        const res_by_name = self.types_by_name.getOrPut(name) catch return;

        if (!res_by_name.found_existing) {
            res_by_name.value_ptr.* = std.ArrayList(*TypeHandler).init(self.allocator);
        }

        const res_by_id = self.types_by_id.getOrPut(typeId) catch return;

        if (!res_by_id.found_existing) {
            res_by_id.value_ptr.* = std.ArrayList(*TypeHandler).init(self.allocator);
        }

        const type_handler = self.allocator.create(TypeHandler) catch return;

        NativeTypeHandler(T).initHandler(type_handler);

        res_by_name.value_ptr.append(type_handler) catch return;
        res_by_id.value_ptr.append(type_handler) catch return;

        //TODO - replace with a proper log.
        //std.debug.print("type {s} added \n", .{name});
    }

    pub fn add(self: *Registry, T: type) void {
        switch (@typeInfo(T)) {
            inline .Struct => registerType(self, T),
            else => return,
        }
    }

    pub fn findTypeByName(self: *Registry, name: [:0]const u8) ?*TypeHandler {
        if (self.types_by_name.get(name)) |v| {
            return v.getLast();
        }
        return null;
    }

    pub fn findTypeById(self: *Registry, type_id: TypeId) ?*TypeHandler {
        if (self.types_by_id.get(type_id)) |v| {
            return v.getLast();
        }
        return null;
    }

    pub fn findType(self: *Registry, comptime T: type) ?*TypeHandler {
        return self.findTypeById(getTypeId(T));
    }

    pub fn addOpaqueImpl(self: *Registry, type_id: TypeId, instance: *const anyopaque) !void {
        const impl_by_id = try self.impls_by_id.getOrPut(type_id);
        if (!impl_by_id.found_existing) {
            impl_by_id.value_ptr.* = std.ArrayList(ImplStorage).init(self.allocator);
        }
        try impl_by_id.value_ptr.append(instance);
    }

    pub fn addImpl(self: *Registry, comptime T: type, ptr: *const T) !void {
        if (self.findType(T) == null) {
            self.add(T);
        }
        try self.addOpaqueImpl(getTypeId(T), ptr);
    }

    pub fn findImplsById(self: *Registry, type_id: TypeId) []*const anyopaque {
        if (self.impls_by_id.get(type_id)) |v| {
            return v.items;
        }
        return &.{};
    }

    pub fn findImpls(self: *Registry, comptime T: type) []*const T {
        return @alignCast(@ptrCast(self.findImplsById(getTypeId(T))));
    }
};

//testing
const TestType = struct {
    x: i32 = 0,
};

const TypeWithFuncs = struct {
    x: u32,

    pub fn sumValueRet(self: *TypeWithFuncs, vl: u32) u32 {
        return self.x + vl;
    }
};

test "test registry basics" {

    // const decls: []const std.builtin.Type.Declaration = switch (@typeInfo(AnotherType)) {
    //     inline .Struct, .Enum, .Union, .Opaque => |container_info| container_info.decls,
    //     inline else => |_, tag| @compileError("expected container, found '" ++ @tagName(tag) ++ "'"),
    // };
    //
    // for (@typeInfo(AnotherType).Struct.decls) |decl| {
    //
    //     switch (@typeInfo(@TypeOf(@field(AnotherType, decl.name)))) {
    //         .Fn => |info| {
    //             std.debug.print("{s}, params {d}", .{decl.name, info.params.len});
    //         },
    //         else => {},
    //     }
    // }

    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();

    try std.testing.expectEqual(registry.types_by_name.count(), 0);

    registry.add(TestType);
    registry.add(TypeWithFuncs);

    const name = @typeName(TestType);

    if (registry.findTypeByName(name)) |typeHandler| {
        try std.testing.expectEqualStrings(name, typeHandler.getName());
        try std.testing.expect(typeHandler.getTypeId(typeHandler.ctx) != 0);

        const t = typeHandler.create(typeHandler.ctx, std.testing.allocator);
        typeHandler.init(typeHandler.ctx, std.testing.allocator, t);

        const testType: *TestType = @alignCast(@ptrCast(t));
        try std.testing.expectEqual(0, testType.x);

        typeHandler.destroy(typeHandler.ctx, std.testing.allocator, t);
    } else {
        try std.testing.expect(false);
    }
}

const ImplTest = struct {
    vl : i32,
    call: *const fn (i32) i32,
};

fn call_impl_test(sum : i32) i32 {
    return sum + 42;
}

const impl_test_one = ImplTest{
    .vl = 1,
    .call = call_impl_test,
};

const impl_test_two = ImplTest{
    .vl = 2,
    .call = call_impl_test,
};

test "registry impl" {
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();

    try registry.addImpl(ImplTest, &impl_test_one);
    try registry.addImpl(ImplTest, &impl_test_two);

    var sum :i32 = 0;

    for(registry.findImpls(ImplTest)) |impl_test| {
        sum += impl_test.vl;
        try std.testing.expectEqual(42 + impl_test.vl, impl_test.call(impl_test.vl));
    }

    try std.testing.expectEqual(3, sum);

}
