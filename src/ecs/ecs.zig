pub const Entity = u64;

pub const archetype = @import("archetype.zig");
pub const world = @import("world.zig");

pub const World = world.World;
pub const Archetype = archetype.Archetype;
pub const ArchetypeType = archetype.ArchetypeType;
pub const ArchetypeChunk = archetype.ArchetypeChunk;
pub const ArchetypeHashMap = archetype.ArchetypeHashMap;
pub const ComponentState = archetype.ComponentState;

pub const archetype_max_components : u8 = 32;
pub const chunk_component_size : u32 = 16*1024;

test {
  _ = world;
  _ = archetype;
}