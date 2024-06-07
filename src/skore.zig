pub const registry = @import("core/registry.zig");
pub const ecs = @import("ecs/ecs.zig");
pub const world = @import("ecs/world.zig");
pub const resource = @import("resource/resource.zig");
pub const rd = @import("graphics/device/render_device.zig");

pub const TypeId = registry.TypeId;
pub const UUID = @import("core/UUID.zig");
pub const App = @import("App.zig").App;
pub const TypeHandler = registry.TypeHandler;
pub const NativeTypeHandler = registry.NativeTypeHandler;
pub const Registry = registry.Registry;
pub const World = ecs.World;
pub const Repository = resource.Repository;
pub const RID = resource.RID;

pub const getTypeId = registry.getTypeId;

test {
  _ = registry;
  _ = ecs;
  _ = resource;
  _ = UUID;
}
