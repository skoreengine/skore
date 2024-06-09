const std = @import("std");
const skore = @import("../../../skore.zig");
const rd = @import("../render_device.zig");

const vk = @import("vulkan");
const VulkanDevice = @This();

const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

const apis: []const vk.ApiInfo = &.{
    vk.features.version_1_0,
    vk.features.version_1_1,
    vk.extensions.khr_surface,
    vk.extensions.khr_swapchain,
};

const BaseDispatch = vk.BaseWrapper(apis);
const InstanceDispatch = vk.InstanceWrapper(apis);
const DeviceDispatch = vk.DeviceWrapper(apis);
const Instance = vk.InstanceProxy(apis);
const Device = vk.DeviceProxy(apis);


allocator: std.mem.Allocator,
adapters: std.ArrayList(rd.Adapter),
vkb: BaseDispatch,
instance : Instance,


fn cast(ctx: *anyopaque) *VulkanDevice {
    return @alignCast(@ptrCast(ctx));
}

fn getAdapters(ctx: *anyopaque) []rd.Adapter {
    const vulkan_device = cast(ctx);
    return vulkan_device.adapters.items;
}

fn createDevice(_: *anyopaque, _: rd.Adapter) void {}

fn initVulkan(render_device: *rd.RenderDevice, allocator: std.mem.Allocator) !void {

    const vulkan_device = try allocator.create(VulkanDevice);
    vulkan_device.allocator = allocator;
    vulkan_device.adapters = std.ArrayList(rd.Adapter).init(allocator);

    const instance_proc_addr : *const fn(vk.Instance, [*:0]const u8) vk.PfnVoidFunction = @alignCast(@ptrCast(sdl.SDL_Vulkan_GetVkGetInstanceProcAddr()));
    vulkan_device.vkb = try BaseDispatch.load(instance_proc_addr);

    var required_extensions_count : u32 = 0;
    const required_extensions = sdl.SDL_Vulkan_GetInstanceExtensions(&required_extensions_count);

    const app_info = vk.ApplicationInfo{
        .p_application_name = "skore",
        .application_version = vk.makeApiVersion(0, 0, 0, 0),
        .p_engine_name = "skore",
        .engine_version = vk.makeApiVersion(0, 0, 0, 0),
        .api_version = vk.API_VERSION_1_3,
    };

    const instance = try vulkan_device.vkb.createInstance(&.{
        .p_application_info = &app_info,
        .enabled_extension_count = required_extensions_count,
        .pp_enabled_extension_names = @ptrCast(required_extensions),
    }, null);

    const vki = try allocator.create(InstanceDispatch);
    errdefer allocator.destroy(vki);
    vki.* = try InstanceDispatch.load(instance, vulkan_device.vkb.dispatch.vkGetInstanceProcAddr);
    vulkan_device.instance = Instance.init(instance, vki);
    errdefer vulkan_device.instance.destroyInstance(null);


    {
        var device_count: u32 = undefined;
        _ = try vulkan_device.instance.enumeratePhysicalDevices(&device_count, null);

        const pdevs = try allocator.alloc(vk.PhysicalDevice, device_count);
        defer allocator.free(pdevs);

        _ = try vulkan_device.instance.enumeratePhysicalDevices(&device_count, pdevs.ptr);

        for (pdevs) |pdev| {
            const props = vulkan_device.instance.getPhysicalDeviceProperties(pdev);

            std.log.info("device name {s}", .{props.device_name});


            // if (try checkSuitable(instance, pdev, allocator, surface)) |candidate| {
            //     return candidate;
            // }
        }
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

fn deinit(ctx: *anyopaque) void {
    const vulkan_device = cast(ctx);

    vulkan_device.instance.destroyInstance(null);
    vulkan_device.allocator.destroy(vulkan_device.instance.wrapper);
    vulkan_device.adapters.deinit();
}

const vulkan_device_impl = rd.RenderDeviceImp{
    .rdi_id = rd.vulkan_rdi_id,
    .init = init,
};

pub fn registerVulkanImpl(registry: *skore.Registry) !void {
    try registry.addImpl(rd.RenderDeviceImp, &vulkan_device_impl);
}
