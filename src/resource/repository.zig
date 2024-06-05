const std = @import("std");
const skore = @import("../skore.zig");
const res = @import("resource.zig");

const Repository = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Repository {
        return .{ .allocator = allocator };
    }

    pub fn deinit(_: *Repository) void {}

    pub fn create(_: *Repository, comptime T: type) T {
        return .{};
    }

    pub fn findByRID(_: *Repository, _ : res.RID, comptime T: type) T {
        return .{};
    }


    pub fn save(_: *Repository, _: anytype) void {

    }
};

const EntityAsset = struct {
    rid : res.RID = undefined,
    value : u32 = 0,
};

const TestResource = struct {
    rid : res.RID = undefined,
    value_one: res.Field(u32) = undefined,
    entities: res.SubobjectList = undefined,
};

test "repository basics" {
    var repository = Repository.init(std.testing.allocator);
    defer repository.deinit();

    var entity_resource = repository.create(EntityAsset);
    entity_resource.value = 30;
    repository.save(entity_resource);

    var test_resource = repository.create(TestResource);
    test_resource.value_one.set(20);
    test_resource.entities.append(entity_resource.rid);
    repository.save(test_resource);

    const test_resource_read = repository.findByRID(test_resource.rid, TestResource);
    _ = test_resource_read;
    //try std.testing.expectEqual(30, test_resource_read.rid);
}
