pub const Entity = u64;

pub const archetype = @import("archetype.zig");
pub const world = @import("world.zig");

pub const World = world.World;
pub const Archetype = archetype.Archetype;
pub const ArchetypeHashMap = archetype.ArchetypeHashMap;

pub const archetype_max_components : u8 = 32;

test {
  _ = world;
  _ = archetype;
}