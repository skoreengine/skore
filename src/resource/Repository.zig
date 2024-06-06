const std = @import("std");
const skore = @import("../skore.zig");
const res = @import("resource.zig");
const RID = @import("RID.zig");
const UUID = skore.UUID;
const Mutex = std.Thread.Mutex;
const Repository = @This();

pub const page_count = 4096;

const ResourceStorage = struct {
    rid: RID,
    type_handler: *skore.TypeHandler,
    instance : ?*anyopaque,
};

const Page = struct {
    elements: [RID.page_size]ResourceStorage = undefined,
};

const PageStorage = [page_count]?*Page;

registry: *skore.Registry = undefined,
allocator: std.mem.Allocator,
counter: usize = 0,
pages: PageStorage = undefined,
page_mutex: Mutex = .{},

pub fn init(registry: *skore.Registry, allocator: std.mem.Allocator) Repository {
    var repo = Repository{
        .registry = registry,
        .allocator = allocator,
    };

    for (0..repo.pages.len) |p| {
        repo.pages[p] = null;
    }

    return repo;
}

fn getOrCreatedStorage(self: *Repository, rid: RID) !*ResourceStorage {
    if (self.pages[rid.page] == null) {
        self.page_mutex.lock();
        defer self.page_mutex.unlock();
        if (self.pages[rid.page] == null) {
            self.pages[rid.page] = try self.allocator.create(Page);
        }
    }

    if (self.pages[rid.page]) |page| {
        return &page.elements[rid.offset];
    }

    return error.PageNotFound;
}

fn getOrCreateId(self: *Repository, _: UUID) RID {
    const index = @atomicLoad(usize, &self.counter, std.builtin.AtomicOrder.acquire);
    @atomicStore(usize, &self.counter, index + 1, std.builtin.AtomicOrder.release);
    return .{ .offset = RID.offset(index), .page = RID.page(index) };
}

pub fn deinit(self: *Repository) void {
    for (self.pages) |page| {
        if (page != null) {
            self.allocator.destroy(page.?);
        }
    }
}

// pub fn createFromTypeHandler(self: *Repository, type_handler: *skore.TypeHandler, uuid : skore.UUID) *anyopaque {
//
// }

pub fn create(self: *Repository, comptime T: type) !*T {
    if (!@hasField(T, "rid")) {
        @compileError("field 'rid' is required for resources");
    }

    const instance = try self.allocator.create(T);

    inline for (@typeInfo(T).Struct.fields) |field| {
        if (field.type == res.SubobjectList) {
            @field(instance, field.name) = res.SubobjectList.init(self.allocator);
        }
    }
    return instance;
}

pub fn findById(_: *Repository, _: RID, comptime T: type) T {
    return .{};
}

pub fn save(_: *Repository, _ : anytype) void {
    // if (!@hasField(@TypeOf(value), "rid")) {
    //     @compileError("field 'rid' is required for resources");
    // }

    // const type_handler_opt = self.registry.findType(T);
    // if (type_handler_opt) |type_handler| {
    //     const new_id = self.getOrCreateId(.{});
    //     var storage = try self.getOrCreatedStorage(new_id);
    //     storage.rid = new_id;
    //     storage.type_handler = type_handler;
    //     storage.instance = null;
    // }
    // return error.TypeNotFound;
}

const EntityAsset = struct {
    rid: RID = undefined,
    value: u32 = 0,
};

const TestResource = struct {
    rid: RID = undefined,
    value_one: res.Field(u32) = undefined,
    entities: res.SubobjectList = undefined,
};

test "repository basics" {
    var registry = skore.Registry.init(std.testing.allocator);
    defer registry.deinit();

    var repository = Repository.init(&registry, std.testing.allocator);
    defer repository.deinit();

    const rid = repository.getOrCreateId(.{});
    const storage = try repository.getOrCreatedStorage(rid);

    std.debug.print("test? {d}", .{storage.rid.offset});

//     var entity_resource = repository.create(EntityAsset);



    // entity_resource.value = 30;
    // repository.save(entity_resource);
    //
    // var test_resource = repository.create(TestResource);
    // test_resource.value_one.set(20);
    //
    // test_resource.entities.append(entity_resource.rid);

    const test_resource = try repository.create(TestResource);


    repository.save(test_resource);
    //
    // const test_resource_read = repository.findById(test_resource.rid, TestResource);
    // _ = test_resource_read;
    //try std.testing.expectEqual(30, test_resource_read.rid);
}
