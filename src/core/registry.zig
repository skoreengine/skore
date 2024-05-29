const std = @import("std");

pub const TypeId = u128;

var allocator: std.mem.Allocator = undefined;
var types_by_name: std.StringHashMap(std.ArrayList(TypeHandler)) = undefined;

pub const TypeHandler = packed struct {
    ctx: *anyopaque = undefined,
    getName: *const fn () [:0]const u8 = undefined,
    getTypeId: *const fn () TypeId = undefined,
    create: *const fn (ctx: *anyopaque, alloc: std.mem.Allocator) *anyopaque = undefined,
    init: *const fn (ctx: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void = undefined,
    deinit: *const fn (ctx: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void = undefined,
    destroy: *const fn (ctx: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void = undefined,
};

fn comptimeGetId(comptime t : type)  TypeId {
    comptime{
        var hash : TypeId = 0;
        for (@typeName(t)) |n| {
            hash = @addWithOverflow(@addWithOverflow(hash << 5, hash)[0], n)[0];
        }
        return hash;
    }
}

fn canInitialize(comptime T : type) bool {
    comptime{
        var ret = false;
        for (@typeInfo(T).Struct.fields) |field| {
            if (field.default_value) |_|  {
                ret = true;
            }
        }
        return ret;
    }
}

pub fn getTypeId(comptime t : type)   TypeId {
    return comptime comptimeGetId(t);
}

pub fn NativeTypeHandler(comptime T: type) type {
    return struct {
        const This = @This();

        fn getName() [:0]const u8 {
            return @typeName(T);
        }

        fn getTypeIdImpl() TypeId {
            return getTypeId(T);
        }

        fn initHandler(handler: *TypeHandler) void {
            handler.getName = getName;
            handler.getTypeId = getTypeIdImpl;
            handler.create = create;
            handler.init = initFn;
            handler.deinit = deinitFn;
            handler.destroy = destroy;
        }

        fn create(_: *anyopaque, alloc: std.mem.Allocator) *anyopaque {
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

        fn destroy(_: *anyopaque, alloc: std.mem.Allocator, ptr: *anyopaque) void {
            const value: *T = @alignCast(@ptrCast(ptr));
            alloc.destroy(value);
        }
    };
}

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    types_by_name = std.StringHashMap(std.ArrayList(TypeHandler)).init(alloc);
}

pub fn deinit() void {
    var it = types_by_name.iterator();
    while (it.next()) |kv| {
        kv.value_ptr.deinit();
    }
    types_by_name.deinit();
}

fn registerType(T: type) !void {
    const name = @typeName(T);
    const res = try types_by_name.getOrPut(name);

    if (!res.found_existing) {
        res.value_ptr.* = std.ArrayList(TypeHandler).init(allocator);
    }

    var type_handler = TypeHandler{};
    NativeTypeHandler(T).initHandler(&type_handler);

    try res.value_ptr.append(type_handler);

    std.debug.print("type {s} added \n", .{name});
}

pub fn register(T: type) !void {
    switch (@typeInfo(T)) {
        inline .Struct => try registerType(T),
        else => return error.NotSupportedYet,
    }
}

pub fn findTypeByName(name: [:0]const u8) !TypeHandler {
    const value = types_by_name.get(name);
    if (value) |v| {
        return v.getLast();
    } else {
        return error.NotFound;
    }
}

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

    try init(std.testing.allocator);

    defer deinit();
    try std.testing.expectEqual(types_by_name.count(), 0);

    try register(TestType);
    try register(TypeWithFuncs);

    const typeHandler = try findTypeByName("registry.TestType");
    try std.testing.expectEqualStrings("registry.TestType", typeHandler.getName());
    try std.testing.expect(typeHandler.getTypeId() != 0);

     const t = typeHandler.create(typeHandler.ctx, std.testing.allocator);
     typeHandler.init(typeHandler.ctx, std.testing.allocator, t);

     const testType: *TestType = @alignCast(@ptrCast(t));
     try std.testing.expectEqual(0, testType.x);

     typeHandler.destroy(typeHandler.ctx, std.testing.allocator, t);
}
