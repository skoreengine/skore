const std = @import("std");

const Registry = @import("registry.zig").Registry;


pub const App = struct {
    allocator : std.mem.Allocator,
    registry : Registry,
    running : bool,

    pub fn init(allocator : std.mem.Allocator) App {
        return .{
            .allocator = allocator,
            .registry = Registry.init(allocator),
            .running = true,
        };
    }

    pub fn run(self: *App) !void {

        while (self.running) {

        }

    }

    pub fn shutdown(self: *App) void {
        self.running = false;
    }

    pub fn deinit(self :*App) void {
        self.registry.deinit();
    }
};
