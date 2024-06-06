const std = @import("std");
const skore = @import("../skore.zig");
const res = @import("resource.zig");
const RID = @import("RID.zig");
const UUID = skore.UUID;

const Repository = @This();

const ResourceStorage = struct {};

const Page = struct {
    elements: [RID.page_size]ResourceStorage = undefined,
};

allocator: std.mem.Allocator,
counter: usize = 0,
pages: [RID.page_size]*Page = undefined,

pub fn init(allocator: std.mem.Allocator) Repository {
    return .{
        .allocator = allocator,
    };
}

fn getOrCreateId(self: *Repository, _: UUID) RID {
    const index = @atomicLoad(usize, &self.counter, std.builtin.AtomicOrder.acquire);
    @atomicStore(usize, &self.counter, index + 1, std.builtin.AtomicOrder.release);
    return .{ .offset = RID.offset(index), .page = RID.page(index) };
}

pub fn deinit(_: *Repository) void {}

pub fn create(_: *Repository, comptime T: type) T {
    return .{};
}

pub fn findById(_: *Repository, _: RID, comptime T: type) T {
    return .{};
}

pub fn save(_: *Repository, _: anytype) void {}

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
    var repository = Repository.init(std.testing.allocator);
    defer repository.deinit();

    _ = repository.getOrCreateId(.{});

    // var entity_resource = repository.create(EntityAsset);
    // entity_resource.value = 30;
    // repository.save(entity_resource);
    //
    // var test_resource = repository.create(TestResource);
    // test_resource.value_one.set(20);
    //
    // test_resource.entities.append(entity_resource.rid);
    // repository.save(test_resource);
    //
    // const test_resource_read = repository.findById(test_resource.rid, TestResource);
    // _ = test_resource_read;
    //try std.testing.expectEqual(30, test_resource_read.rid);
}
