const std = @import("std");

pub const none_rdi_id = 0;
pub const vulkan_rdi_id = 1;
pub const open_gl_rdi_id = 2;
pub const d3d12_rdi_id = 3;
pub const metal_rdi_id = 4;
pub const webgpu_rdi_id = 5;

pub const Adapter = struct { handler: *anyopaque };
pub const Swapchain = struct { handler: *anyopaque };

pub const RenderDevice = struct {
    ctx : *anyopaque = undefined,
    getAdapters: *const fn (ctx : *anyopaque) []Adapter = undefined,
    createDevice: *const fn (ctx : *anyopaque, adapter: Adapter) void = undefined,
    deinit : *const fn(ctx : *anyopaque) void = undefined,
};

pub const RenderDeviceImp = struct {
    rdi_id: u8,
    init: *const fn (render_device : *RenderDevice, std.mem.Allocator) bool
};
