pub const DeviceApi = enum {
    none,
    vulkan,
    open_gl,
    d3d12,
    metal,
    webgpu,
};

pub const Adapter = struct { handler: *anyopaque };
pub const Swapchain = struct { handler: *anyopaque };

pub const RenderDevice = struct {
    ctx: *anyopaque,
    get_adapters: *const fn (ctx: *anyopaque) []Adapter,
    create_device: *const fn (ctx: *anyopaque, adapter: Adapter) void,
};
