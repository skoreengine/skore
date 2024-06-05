pub const registry = @import("registry.zig");
pub const ecs = @import("ecs/ecs.zig");
pub const resource = @import("resource/resource.zig");

pub const TypeId = registry.TypeId;
pub const App = @import("App.zig").App;
pub const TypeHandler = registry.TypeHandler;
pub const NativeTypeHandler = registry.NativeTypeHandler;
pub const Registry = registry.Registry;
pub const World = ecs.World;

pub const getTypeId = registry.getTypeId;

test {
  _ = registry;
  _ = ecs;
  _ = resource;
}
