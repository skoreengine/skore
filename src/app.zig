const std = @import("std");
const skore = @import("skore.zig");
const Graphics = @import("graphics/Graphics.zig");

const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const App = struct {
    allocator: std.mem.Allocator,
    registry: *skore.Registry,
    running: bool,
    graphics: Graphics,
    window: ?*sdl.SDL_Window,

    pub fn init(registry: *skore.Registry, allocator: std.mem.Allocator) !App {
        if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
            return error.SDLInit;
        }

        const window = sdl.SDL_CreateWindow("Skore Engine", 800, 600, sdl.SDL_WINDOW_VULKAN | sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_MAXIMIZED);
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
            .window = window,
        };
    }

    pub fn run(self: *App) !void {
        while (self.running) {
            var event: sdl.SDL_Event = undefined;

            while (sdl.SDL_PollEvent(&event) != sdl.SDL_FALSE) {
                if (event.type == sdl.SDL_EVENT_QUIT) {
                    self.running = false;
                }

                if (event.type == sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED and event.window.windowID != sdl.SDL_TRUE and sdl.SDL_GetWindowID(self.window) != 0) {
                    self.running = false;
                }
            }

            _ = sdl.SDL_GL_SwapWindow(self.window);
        }
    }

    pub fn shutdown(self: *App) void {
        self.running = false;
    }

    pub fn deinit(self: *App) void {
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }
};
