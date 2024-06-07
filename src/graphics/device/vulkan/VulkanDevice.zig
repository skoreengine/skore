const std = @import("std");
const skore = @import("../../../skore.zig");
const rd = @import("../render_device.zig");

const glfw = @import("zglfw");

const vk = @import("vulkan");
const VulkanDevice = @This();

const VK_SUCCESS = vk.VK_SUCCESS;

allocator: std.mem.Allocator,
adapters: std.ArrayList(rd.Adapter),
instance: vk.VkInstance,

fn cast(ctx: *anyopaque) *VulkanDevice {
    return @alignCast(@ptrCast(ctx));
}

fn getAdapters(ctx: *anyopaque) []rd.Adapter {
    const vulkan_device = cast(ctx);
    return vulkan_device.adapters.items;
}

fn createDevice(_: *anyopaque, _: rd.Adapter) void {}

fn deinit(ctx: *anyopaque) void {
    const vulkan_device = cast(ctx);
    vulkan_device.adapters.deinit();
}

fn initVulkan(render_device: *rd.RenderDevice, allocator: std.mem.Allocator) !void {

    if (vk.volkInitialize() != vk.VK_SUCCESS) {
        return error.vulkanError;
    }


    const vulkan_device = try allocator.create(VulkanDevice);
    vulkan_device.allocator = allocator;
    vulkan_device.adapters = std.ArrayList(rd.Adapter).init(allocator);

    const application_info = vk.VkApplicationInfo{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Skore",
        .applicationVersion = 0,
        .pEngineName = "Skore",
        .engineVersion = 0,
        .apiVersion = vk.VK_API_VERSION_1_3,
    };

    var create_info = vk.VkInstanceCreateInfo{};
    create_info.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = &application_info;

    if (vk.vkCreateInstance.?(&create_info, null, &vulkan_device.instance) != vk.VK_SUCCESS) {
        return error.vulkanError;
    }

    try vulkan_device.adapters.append(.{ .handler = undefined });

    render_device.ctx = vulkan_device;
    render_device.getAdapters = getAdapters;
    render_device.createDevice = createDevice;
    render_device.deinit = deinit;
}

fn init(render_device: *rd.RenderDevice, allocator: std.mem.Allocator) bool {
    initVulkan(render_device, allocator) catch return false;
    return true;
}

const vulkan_device_impl = rd.RenderDeviceImp{
    .rdi_id = rd.vulkan_rdi_id,
    .init = init,
};

pub fn registerVulkanImpl(registry: *skore.Registry) !void {
    try registry.addImpl(rd.RenderDeviceImp, &vulkan_device_impl);
}
