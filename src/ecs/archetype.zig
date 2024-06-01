const std = @import("std");
const skore = @import("../skore.zig");

pub const ArchetypeLookup = struct {
    hash : u64,
    ids : [] const skore.TypeId,

    pub fn create(ids : []const skore.TypeId) ArchetypeLookup {
        return .{
            .hash = std.hash.Murmur2_64.hash(&std.mem.toBytes(ids)),
            .ids = ids
        };
    }
};

pub const ArchetypeLookupContext = struct {

    pub fn hash(_: ArchetypeLookupContext, lookup: ArchetypeLookup) u64 {
        return lookup.hash;
    }

    pub fn eql(_: ArchetypeLookupContext, left : ArchetypeLookup, right: ArchetypeLookup) bool {
        if (left.ids.len != right.ids.len) return false;
        for (left.ids, right.ids) |l, r| {
            if (l != r) return false;
        }
        return true;
    }
};

pub const Archetype = struct {
    id: u32,
};

pub const ArchetypeHashMap = std.HashMap(ArchetypeLookup, *Archetype, ArchetypeLookupContext, std.hash_map.default_max_load_percentage);



test "test lookup"{

    const TypeTestOne = struct {
    };

    const TypeTestTwo = struct {
    };

    const ids1 = [_]skore.TypeId{skore.registry.getTypeId(TypeTestOne), skore.registry.getTypeId(TypeTestTwo)};
    const lookup1 = ArchetypeLookup.create(&ids1);

    try std.testing.expect(lookup1.hash != 0);
    try std.testing.expectEqual(2, lookup1.ids.len);

    var contest = ArchetypeLookupContext{};
    try std.testing.expectEqual(contest.hash(lookup1), contest.hash(lookup1));
    try std.testing.expect(contest.eql(lookup1, lookup1));


    const ids2 = [_]skore.TypeId{skore.registry.getTypeId(TypeTestOne), skore.registry.getTypeId(TypeTestTwo), skore.registry.getTypeId(Archetype)};
    const lookup2 = ArchetypeLookup.create(&ids2);

    try std.testing.expect(contest.hash(lookup1) != contest.hash(lookup2));
    try std.testing.expect(!contest.eql(lookup1, lookup2));
}