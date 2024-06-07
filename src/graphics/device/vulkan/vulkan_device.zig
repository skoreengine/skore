const std = @import("std");
const skore = @import("../../../skore.zig");
const rd = @import("../render_device.zig");

const vk  = @import("vulkan");

const VulkanContext = struct {
    allocator: std.mem.Allocator,
    adapters: std.ArrayList(rd.Adapter),

};


var ctx: VulkanContext = undefined;

fn getAdapters() []rd.Adapter {
    return ctx.adapters.items;
}

fn createDevice(_: rd.Adapter) void {}

fn deinit() void {
    ctx.adapters.deinit();
}

fn initContext() !void {
    try ctx.adapters.append(.{ .handler = undefined });
}

fn init(allocator: std.mem.Allocator) rd.RenderDevice {

    vk.volkInitialize();


    ctx = .{
        .allocator = allocator,
        .adapters = std.ArrayList(rd.Adapter).init(allocator),
    };

    initContext() catch @panic("error");

    return .{
        .getAdapters = getAdapters,
        .createDevice = createDevice,
        .deinit = deinit,
    };
}

const vulkan_device_impl = rd.RenderDeviceImp{
    .rdi_id = rd.vulkan_rdi_id,
    .init = init,
};

pub fn registerVulkanImpl(registry: *skore.Registry) !void {
    try registry.addImpl(rd.RenderDeviceImp, &vulkan_device_impl);
}
