const std = @import("std");
const skore = @import("../skore.zig");
const rd = @import("./device/render_device.zig");
const vk = @import("./device/vulkan/VulkanDevice.zig");


const Graphics = @This();

render_device: rd.RenderDevice = rd.RenderDevice{},

pub fn init(registry: *skore.Registry, allocator: std.mem.Allocator, id: u8) !Graphics {

    try vk.registerVulkanImpl(registry);

    var graphics = Graphics{};

    for (registry.findImpls(rd.RenderDeviceImp)) |device_impl| {
        if (device_impl.rdi_id == id) {
            if (device_impl.init(&graphics.render_device, allocator)) {
                return graphics;
            }
        }
    }
    return error.RenderDeviceNotFound;
}

pub fn getAdapters(self: *Graphics) []rd.Adapter {
    return self.render_device.getAdapters(self.render_device.ctx);
}

pub fn createDevice(self: *Graphics, adapter: rd.Adapter) void {
    self.render_device.createDevice(self.render_device.ctx, adapter);
}

pub fn deinit(self: *Graphics) void {
    self.render_device.deinit(self.render_device.ctx);
}
