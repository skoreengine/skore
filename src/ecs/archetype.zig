const std = @import("std");

pub const ArchetypeLookup = struct {};

pub const ArchetypeLookupContext = struct {
    pub fn hash(_: ArchetypeLookupContext, _: ArchetypeLookup) u64 {
        return 0;
    }

    pub fn eql(_: ArchetypeLookupContext, _: ArchetypeLookup, _: ArchetypeLookup) bool {
        return false;
    }
};

pub const Archetype = struct {
    id: u32,
};

pub const ArchetypeHashMap = std.HashMap(ArchetypeLookup, *Archetype, ArchetypeLookupContext, std.hash_map.default_max_load_percentage);
