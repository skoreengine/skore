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
    instance: ?*anyopaque,
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

pub fn create(_: *Repository, comptime T: type) T {
    return .{};
}

pub fn prototype(_: *Repository, _: RID, comptime T: type) T {
    return .{};
}

pub fn push(_: Repository, _: anytype) void {
}

// pub fn read(self: *Repository, rid: RID, comptime T: type) ?*const T {
//     if (self.pages[rid.page]) |page| {
//         if (page.elements[rid.offset].instance) |instance_opaque| {
//             const instance: *T = @alignCast(@ptrCast(instance_opaque));
//             return instance;
//         }
//     }
//     return null;
// }


// const SubObjectSet = struct  {
// };
//
// fn Field(comptime T: type) type {
//     return struct {
//         const This = @This();
//
//
//         pub fn set(_ : *This, _ : T) void {
//
//         }
//     };
// }
//
// const StreamObject = struct {
//     pub fn write(_: *StreamObject, _: [:0]const u8) void {}
//
//     pub fn read(_: *StreamObject) ?[:0]const u8 {
//         return null;
//     }
// };
//
//
// const TestResource = struct {
//     rid: RID = undefined,
//     val: Field(i32) = undefined,
//     entities: SubObjectSet = undefined,
//     data: StreamObject = undefined,
//
//     pub fn deinit(self: *TestResource) void {
//         self.entities.deinit();
//     }
// };
//
// test "repository basics" {
//     var registry = skore.Registry.init(std.testing.allocator);
//     defer registry.deinit();
//
//     var repository = Repository.init(&registry, std.testing.allocator);
//     defer repository.deinit();
//
//     var test_resource = repository.create(TestResource);
//     test_resource.val.set(10);
//     repository.push(test_resource);
//
//     _ = repository.prototype(test_resource.rid, TestResource);
// }
