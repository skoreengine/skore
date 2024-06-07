const std = @import("std");
const rd = @import("./device/render_device.zig");

const Graphics = @This();

render_device: rd.RenderDevice,

pub fn init(_: std.mem.Allocator, _: rd.DeviceApi) Graphics {
    return .{ .render_device = undefined };
}

pub fn getAdapters(self: *Graphics) []rd.Adapter {
    return self.render_device.get_adapters(self.render_device.ctx);
}

pub fn createDevice(self: *Graphics, adapter: rd.Adapter) void {
    self.render_device.create_device(self.render_device.ctx, adapter);
}
