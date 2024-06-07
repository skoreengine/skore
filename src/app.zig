const std = @import("std");
const skore = @import("skore.zig");
const Graphics = @import("graphics/Graphics.zig");


pub const App = struct {
    allocator : std.mem.Allocator,
    registry : *skore.Registry,
    running : bool,
    graphics : Graphics,

    pub fn init(registry :* skore.Registry, allocator : std.mem.Allocator) !App {

        var graphics = try Graphics.init(registry, allocator, skore.rd.vulkan_rdi_id);

        if (graphics.getAdapters().len == 0) {
            return error.NoGPUAdaptersFound;
        }

        graphics.createDevice(graphics.getAdapters()[0]);

        return .{
            .allocator = allocator,
            .registry = registry,
            .running = true,
            .graphics = graphics,
        };
    }

    pub fn run(self: *App) !void {
        while (self.running) {
            self.running = false;
        }
    }

    pub fn shutdown(self: *App) void {
        self.running = false;
    }

    pub fn deinit(_ :*App) void {
    }
};
