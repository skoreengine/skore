const std = @import("std");
const skore = @import("../skore.zig");
const rd = @import("./device/render_device.zig");
const vk = @import("./device/vulkan/vulkan_device.zig");


const Graphics = @This();

render_device: rd.RenderDevice,

pub fn init(registry: *skore.Registry, allocator: std.mem.Allocator, id: u8) !Graphics {

    try vk.registerVulkanImpl(registry);

    for (registry.findImpls(rd.RenderDeviceImp)) |device_impl| {
        if (device_impl.rdi_id == id) {
            return .{
                .render_device = device_impl.init(allocator),
            };
        }
    }
    return error.RenderDeviceNotFound;
}

pub fn getAdapters(self: *Graphics) []rd.Adapter {
    return self.render_device.getAdapters();
}

pub fn createDevice(self: *Graphics, adapter: rd.Adapter) void {
    self.render_device.createDevice(adapter);
}

pub fn deinit(self: *Graphics) void {
    self.render_device.deinit();
}
